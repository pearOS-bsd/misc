#!/usr/bin/env python3
"""libs-gui, GSAutoLayoutVFLParser: a connection can be a predicate list, `-(3@53)-`, `-(>=3@53)-`, `-(==8)-` (the Visual Format Language of Apple); GNUstep's parser only takes a plain number or a
metric there and raises on the parenthesis. The spacing of a connection becomes either an NSNumber (as before) or a dictionary with constant, relation and priority, which the three
constraints a connection can produce (to the superview at either end, between two views) honour.
usage: patch-vfl-predicates.py GSAutoLayoutVFLParser.m"""
import sys, re
path = sys.argv[1]
s = open(path).read()
if "GSVFLUnpack" in s:
    sys.exit(0)


helper = """static void
GSVFLUnpack(id spacing, CGFloat defaultConstant, CGFloat *constant,
            NSLayoutRelation *relation, NSNumber **priority)
{
  if ([spacing isKindOfClass: [NSDictionary class]])
    {
      id p = [spacing objectForKey: @"p"];

      *constant = [[spacing objectForKey: @"c"] doubleValue];
      *relation = [[spacing objectForKey: @"r"] integerValue];
      *priority = (p == [NSNull null]) ? nil : p;
    }
  else
    {
      *constant = spacing ? [spacing doubleValue] : defaultConstant;
      *relation = NSLayoutRelationEqual;
      *priority = nil;
    }
}

"""
s = s.replace("@implementation GSAutoLayoutVFLParser\n", helper + "@implementation GSAutoLayoutVFLParser\n", 1)

# the spacing travels as an object
s = s.replace("- (NSNumber *) parseSimplePredicate;", "- (id) parseSimplePredicate;")
s = s.replace("- (NSNumber *) parseSimplePredicate\n", "- (id) parseSimplePredicate\n")
s = s.replace("- (NSNumber *) parseLeadingSuperViewConnection", "- (id) parseLeadingSuperViewConnection")
s = s.replace("- (NSNumber *) parseConnection", "- (id) parseConnection")
s = s.replace("NSNumber *spacingConstant = [self parseLeadingSuperViewConnection];", "id spacingConstant = [self parseLeadingSuperViewConnection];")
s = s.replace("NSNumber *simplePredicateValue = [self parseSimplePredicate];", "id simplePredicateValue = [self parseSimplePredicate];")
s = re.sub(r"\(void\) (addViewSpacingConstraint|addLeadingSuperviewConstraint|addTrailingToSuperviewConstraint): ?\(NSNumber \*\)spacing", lambda m: "(void) %s:(id)spacing" % m.group(1), s)
s = s.replace("- (void) addViewSpacingConstraint:(NSNumber *)spacing", "- (void) addViewSpacingConstraint:(id)spacing")
s = s.replace("- (void) addLeadingSuperviewConstraint:(NSNumber *)spacing", "- (void) addLeadingSuperviewConstraint:(id)spacing")
s = s.replace("- (void) addTrailingToSuperviewConstraint:(NSNumber *)spacing", "- (void) addTrailingToSuperviewConstraint:(id)spacing")

# the predicate list in a connection
old = """  float constant;
  BOOL scanConstantResult = [_scanner scanFloat: &constant];
  if (scanConstantResult)"""
new = """  float constant;
  BOOL scanConstantResult;

  if ([_scanner scanString: @"(" intoString: NULL])
    {
      GSObjectOfPredicate predicate;

      [self parseObjectOfPredicate: &predicate];
      if (![_scanner scanString: @")" intoString: NULL])
        {
          [self failParseWithMessage: @"A predicate on a connection must end with ')'"];
        }
      return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble: predicate.constant], @"c",
        [NSNumber numberWithInteger: predicate.relation], @"r",
        (predicate.priority ? (id)predicate.priority : (id)[NSNull null]), @"p",
        nil];
    }
  scanConstantResult = [_scanner scanFloat: &constant];
  if (scanConstantResult)"""
assert old in s
s = s.replace(old, new, 1)

# the three constraints
def patch_block(s, signature, marker_old, marker_new, extra_after):
    pass

# view spacing
old = """  CGFloat viewSpacingConstant
      = spacing ? [spacing doubleValue] : GS_DEFAULT_VIEW_SPACING;
  NSLayoutAttribute firstAttribute;"""
new = """  CGFloat viewSpacingConstant;
  NSLayoutRelation spacingRelation;
  NSNumber *spacingPriority;
  NSLayoutAttribute firstAttribute;"""
assert old in s
s = s.replace(old, new, 1)
old = """  NSLayoutConstraint *viewSeparatorConstraint =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: firstAttribute
                                   relatedBy: NSLayoutRelationEqual"""
new = """  GSVFLUnpack(spacing, GS_DEFAULT_VIEW_SPACING, &viewSpacingConstant,
              &spacingRelation, &spacingPriority);
  NSLayoutConstraint *viewSeparatorConstraint =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: firstAttribute
                                   relatedBy: spacingRelation"""
assert old in s
s = s.replace(old, new, 1)
old = "  [_constraints addObject: viewSeparatorConstraint];"
new = "  if (spacingPriority) [viewSeparatorConstraint setPriority: [spacingPriority doubleValue]];\n  [_constraints addObject: viewSeparatorConstraint];"
assert old in s
s = s.replace(old, new, 1)

# leading to superview
old = """  CGFloat viewSpacingConstant
      = spacing ? [spacing doubleValue] : GS_DEFAULT_SUPERVIEW_SPACING;

  NSLayoutConstraint *leadingConstraintToSuperview =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: firstAttribute
                                   relatedBy: NSLayoutRelationEqual"""
new = """  CGFloat viewSpacingConstant;
  NSLayoutRelation spacingRelation;
  NSNumber *spacingPriority;

  GSVFLUnpack(spacing, GS_DEFAULT_SUPERVIEW_SPACING, &viewSpacingConstant,
              &spacingRelation, &spacingPriority);
  NSLayoutConstraint *leadingConstraintToSuperview =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: firstAttribute
                                   relatedBy: spacingRelation"""
assert old in s
s = s.replace(old, new, 1)
old = "  [_constraints addObject: leadingConstraintToSuperview];"
new = "  if (spacingPriority) [leadingConstraintToSuperview setPriority: [spacingPriority doubleValue]];\n  [_constraints addObject: leadingConstraintToSuperview];"
assert old in s
s = s.replace(old, new, 1)

# trailing to superview
old = """  CGFloat viewSpacingConstant
      = spacing ? [spacing doubleValue] : GS_DEFAULT_SUPERVIEW_SPACING;

  NSLayoutFormatOptions directionOptions
      = _options & NSLayoutFormatDirectionMask;
  NSLayoutAttribute attribute;"""
new = """  CGFloat viewSpacingConstant;
  NSLayoutRelation spacingRelation;
  NSNumber *spacingPriority;

  GSVFLUnpack(spacing, GS_DEFAULT_SUPERVIEW_SPACING, &viewSpacingConstant,
              &spacingRelation, &spacingPriority);
  NSLayoutFormatOptions directionOptions
      = _options & NSLayoutFormatDirectionMask;
  NSLayoutAttribute attribute;"""
assert old in s
s = s.replace(old, new, 1)
old = """  NSLayoutConstraint *trailingConstraintToSuperview =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: attribute
                                   relatedBy: NSLayoutRelationEqual"""
new = """  NSLayoutConstraint *trailingConstraintToSuperview =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: attribute
                                   relatedBy: spacingRelation"""
assert old in s
s = s.replace(old, new, 1)
old = "  [_constraints addObject: trailingConstraintToSuperview];"
new = "  if (spacingPriority) [trailingConstraintToSuperview setPriority: [spacingPriority doubleValue]];\n  [_constraints addObject: trailingConstraintToSuperview];"
assert old in s
s = s.replace(old, new, 1)
# the engine solves Cocoa's way (ci/patch-autolayout-vertical.py: Top and Bottom grow downwards): the vertical spacings of a connection are no longer negated
import re as _re
s = _re.sub(r"\(_isVerticalOrientation\s*\?\s*-viewSpacingConstant\s*:\s*viewSpacingConstant\)", "viewSpacingConstant", s)
open(path, "w").write(s)
