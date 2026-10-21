#!/usr/bin/env python3
"""libs-gui: make xib loading create the Auto Layout constraints of a xib.

GSXib5KeyedUnarchiver parses <constraint> elements but never builds them (the code is commented out), so every window whose xib relies on constraints keeps the frames of its design
size. The patch records each constraint element with the id of the view that owns it, builds the NSLayoutConstraints when that view has been decoded (items by id; a missing
first / second item is the owner view itself, as Interface Builder writes it) and honours translatesAutoresizingMaskIntoConstraints="NO".
usage: patch-gsxib-constraints.py Source/GSXib5KeyedUnarchiver.m"""
import sys

path = sys.argv[1]
s = open(path).read()
if "_gsBuildConstraint" in s:
    sys.exit(0)

old = """          /*
          else if ([XmlConstraintRecordTags containsObject: elementName])
            {
              [self objectForXib: element]; // decode the constraint...
            }
          */"""
new = """          else if ([XmlConstraintRecordTags containsObject: elementName])
            {
              /* kept until the owning view (the element the "constraints" array belongs to) is decoded */
              NSString *ownerID = [[stack lastObject] attributeForKey: @"id"];
              if (ownerID != nil)
                {
                  NSMutableArray *list;
                  if (GSXibConstraintOwners == nil)
                    {
                      GSXibConstraintOwners = [NSMutableDictionary new];
                    }
                  list = [GSXibConstraintOwners objectForKey: ownerID];
                  if (list == nil)
                    {
                      list = [NSMutableArray array];
                      [GSXibConstraintOwners setObject: list forKey: ownerID];
                    }
                  [list addObject: element];
                }
            }"""
assert old in s
s = s.replace(old, new, 1)

s = s.replace("static NSArray      *XmlConstraintRecordTags  = nil;",
              "static NSArray      *XmlConstraintRecordTags  = nil;\nstatic NSMutableDictionary *GSXibConstraintOwners = nil;", 1)

build = """- (id) _gsConstraintItem: (NSString *)ref owner: (id)owner
{
  id o;

  if (ref == nil)
    {
      return owner;
    }
  o = [decoded objectForKey: ref];
  if (o == nil)
    {
      GSXibElement *re = [objects objectForKey: ref];
      if (re != nil)
        {
          o = [self objectForXib: re];
        }
    }
  return o;
}

- (void) _gsBuildConstraint: (GSXibElement *)e owner: (id)owner
{
  NSInteger a1 = [[self decodeFirstAttribute: e] integerValue];
  NSInteger a2 = [[self decodeSecondAttribute: e] integerValue];
  NSInteger rel = [[self decodeRelation: e] integerValue];
  id i1 = [self _gsConstraintItem: [e attributeForKey: @"firstItem"] owner: owner];
  id i2 = nil;
  double m = 1.0;
  double k = [[e attributeForKey: @"constant"] doubleValue];
  NSString *ms = [e attributeForKey: @"multiplier"];
  NSString *ps = [e attributeForKey: @"priority"];
  NSLayoutConstraint *c;

  if (a2 != NSLayoutAttributeNotAnAttribute)
    {
      i2 = [self _gsConstraintItem: [e attributeForKey: @"secondItem"] owner: owner];
    }
  if (i1 == nil || (a2 != NSLayoutAttributeNotAnAttribute && i2 == nil))
    {
      return;
    }
  if (ms != nil)
    {
      NSRange r = [ms rangeOfString: @":"];
      if (r.length > 0)
        {
          double n = [[ms substringToIndex: r.location] doubleValue];
          double d = [[ms substringFromIndex: NSMaxRange(r)] doubleValue];
          m = (d != 0.0) ? n / d : 1.0;
        }
      else
        {
          m = [ms doubleValue];
        }
    }
  c = [NSLayoutConstraint constraintWithItem: i1
                                   attribute: a1
                                   relatedBy: rel
                                      toItem: i2
                                   attribute: a2
                                  multiplier: m
                                    constant: k];
  if (ps != nil)
    {
      [c setPriority: [ps floatValue]];
    }
  [c setActive: YES];
}

"""
anchor = "- (id) decodeObjectForXib: (GSXibElement*)element\n             forClassName: (NSString*)classname\n                   withID: (NSString*)objID\n{"
assert anchor in s
s = s.replace(anchor, build + anchor, 1)

hook_old = "  [self addOrderedObject: element];\n  [self addToolTip: element forObject: object];\n"
hook_new = hook_old + """
  if ([object isKindOfClass: [NSView class]])
    {
      NSString *translates = [element attributeForKey: @"translatesAutoresizingMaskIntoConstraints"];
      NSArray *list = (objID != nil) ? [GSXibConstraintOwners objectForKey: objID] : nil;

      if ([translates isEqualToString: @"NO"])
        {
          [object setTranslatesAutoresizingMaskIntoConstraints: NO];
        }
      if (list != nil)
        {
          NSUInteger i;

          [GSXibConstraintOwners removeObjectForKey: objID];
          for (i = 0; i < [list count]; i++)
            {
              [self _gsBuildConstraint: [list objectAtIndex: i] owner: object];
            }
        }
    }
"""
assert hook_old in s
s = s.replace(hook_old, hook_new, 1)
open(path, "w").write(s)
