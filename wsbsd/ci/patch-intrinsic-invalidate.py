#!/usr/bin/env python3
"""libs-gui: -invalidateIntrinsicContentSize. GNUstep's engine reads a view's intrinsicContentSize once, when the view first takes part in a constraint, and nothing tells it of later changes (the method does not exist; our back-end
defined it empty). A view whose size is known only after its data is loaded (TextMate's gutter) then keeps a stale size forever. The engine gets intrinsicContentSizeDidChangeForView:, which feeds the new values to the edit
variables, and NSView -invalidateIntrinsicContentSize calls it and asks for a layout.
usage: patch-intrinsic-invalidate.py GSAutoLayoutEngine.m NSView.m"""
import sys
eng, view = sys.argv[1], sys.argv[2]
s = open(eng).read()
if "intrinsicContentSizeDidChangeForView" not in s:
    old = "- (void) resolveVariableForView: (NSView *)view\n                      attribute: (GSLayoutViewAttribute)attribute\n{"
    new = """- (void) intrinsicContentSizeDidChangeForView: (NSView *)view
{
  NSSize size = [view intrinsicContentSize];

  if (getenv("WSBSD_ALDEBUG"))
    {
      fprintf(stderr, "AL intrinsic changed %s %g x %g (width var %s, height var %s)\n",
        object_getClassName(view), size.width, size.height,
        [self getExistingVariableForView: view withViewAttribute: GSLayoutViewAttributeIntrinsicWidth] ? "yes" : "no",
        [self getExistingVariableForView: view withViewAttribute: GSLayoutViewAttributeIntrinsicHeight] ? "yes" : "no");
    }
  NS_DURING
    {
      if (size.width != NSViewNoIntrinsicMetric
          && [self getExistingVariableForView: view
                            withViewAttribute: GSLayoutViewAttributeIntrinsicWidth] != nil)
        {
          [self resolveVariableForView: view
                             attribute: GSLayoutViewAttributeIntrinsicWidth];
        }
      if (size.height != NSViewNoIntrinsicMetric
          && [self getExistingVariableForView: view
                            withViewAttribute: GSLayoutViewAttributeIntrinsicHeight] != nil)
        {
          [self resolveVariableForView: view
                             attribute: GSLayoutViewAttributeIntrinsicHeight];
        }
    }
  NS_HANDLER
    {
      /* the view does not take part in the layout (yet) */
    }
  NS_ENDHANDLER
}

"""
    assert old in s
    s = s.replace(old, new + old, 1)
    # declare in the interface (the private category that lists resolveVariableForView:)
    decl = "- (void) resolveVariableForView: (NSView *)view\n                      attribute: (GSLayoutViewAttribute)attribute;\n"
    assert decl in s
    s = s.replace(decl, decl + "\n- (void) intrinsicContentSizeDidChangeForView: (NSView *)view;\n", 1)
    open(eng, "w").write(s)

old = "- (void) addIntrinsicContentSizeConstraintsToView: (NSView *)view\n{\n    NSSize intrinsicContentSize = [view intrinsicContentSize];\n"
new = old + "    if (getenv(\"WSBSD_ALDEBUG\"))\n      fprintf(stderr, \"AL register intrinsic %s %g x %g hug %g/%g comp %g/%g\\n\", object_getClassName(view), intrinsicContentSize.width, intrinsicContentSize.height,\n        [view contentHuggingPriorityForOrientation: NSLayoutConstraintOrientationHorizontal], [view contentHuggingPriorityForOrientation: NSLayoutConstraintOrientationVertical],\n        [view contentCompressionResistancePriorityForOrientation: NSLayoutConstraintOrientationHorizontal], [view contentCompressionResistancePriorityForOrientation: NSLayoutConstraintOrientationVertical]);\n"
s = open(eng).read()
if "AL register intrinsic" not in s and old in s:
    open(eng, "w").write(s.replace(old, new, 1))
v = open(view).read()
if "invalidateIntrinsicContentSize" not in v:
    anchor = "- (void) _gsFlushPendingConstraints\n"
    assert anchor in v
    v = v.replace(anchor, """- (void) invalidateIntrinsicContentSize
{
  GSAutoLayoutEngine *engine = [self _layoutEngine];

  if (engine != nil)
    {
      [engine intrinsicContentSizeDidChangeForView: self];
      [self setNeedsLayout: YES];
    }
}

""" + anchor, 1)
    open(view, "w").write(v)
