#!/usr/bin/env python3
"""libs-gui, NSView: constraints added to a view that is not in a window yet were dropped (the layout engine belongs to the window). Applications build their interface before the window exists and
add the constraints right away (TextMate does in every init method). The constraints are now kept with the view and handed to the engine when the view reaches a window.
usage: patch-pending-constraints.py NSView.m"""
import sys
path = sys.argv[1]
s = open(path).read()
if "_gsFlushPendingConstraints" in s:
    sys.exit(0)

if "#import <objc/runtime.h>" not in s and "#include <objc/runtime.h>" not in s:
    s = s.replace("#import \"AppKit/NSView.h\"", "#import \"AppKit/NSView.h\"\n#import <objc/runtime.h>", 1)

old_add = """- (void) addConstraint: (NSLayoutConstraint *)constraint
{
  if (![self _getOrCreateLayoutEngine])
    {
      return;
    }
"""
new_add = """static char GSPendingConstraintsKey;

static NSMutableArray *
GSPendingConstraints(NSView *view, BOOL create)
{
  NSMutableArray *a = objc_getAssociatedObject(view, &GSPendingConstraintsKey);

  if (a == nil && create)
    {
      a = [NSMutableArray array];
      objc_setAssociatedObject(view, &GSPendingConstraintsKey, a,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  return a;
}

- (void) _gsFlushPendingConstraints
{
  NSMutableArray *pending = objc_getAssociatedObject(self, &GSPendingConstraintsKey);
  GSAutoLayoutEngine *engine;

  if (pending == nil || [self window] == nil)
    {
      return;
    }
  RETAIN(pending);
  objc_setAssociatedObject(self, &GSPendingConstraintsKey, nil,
    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  engine = [self _getOrCreateLayoutEngine];
  if (engine != nil)
    {
      [engine addConstraints: pending];
    }
  RELEASE(pending);
}

- (void) addConstraint: (NSLayoutConstraint *)constraint
{
  if (![self _getOrCreateLayoutEngine])
    {
      [GSPendingConstraints(self, YES) addObject: constraint];
      return;
    }
"""
assert old_add in s
s = s.replace(old_add, new_add, 1)

old = """- (void) addConstraints: (NSArray*)constraints
{
  if (![self _getOrCreateLayoutEngine])
    {
      return;
    }
"""
new = """- (void) addConstraints: (NSArray*)constraints
{
  if (![self _getOrCreateLayoutEngine])
    {
      [GSPendingConstraints(self, YES) addObjectsFromArray: constraints];
      return;
    }
"""
assert old in s
s = s.replace(old, new, 1)

old = """- (void) removeConstraint: (NSLayoutConstraint *)constraint
{
  if (![self _layoutEngine])
    {
      return;
    }
"""
new = """- (void) removeConstraint: (NSLayoutConstraint *)constraint
{
  if (![self _layoutEngine])
    {
      [GSPendingConstraints(self, NO) removeObject: constraint];
      return;
    }
"""
assert old in s
s = s.replace(old, new, 1)

old = """- (void) removeConstraints: (NSArray *)constraints
{
  if (![self _layoutEngine])
    {
      return;
    }
"""
new = """- (void) removeConstraints: (NSArray *)constraints
{
  if (![self _layoutEngine])
    {
      [GSPendingConstraints(self, NO) removeObjectsInArray: constraints];
      return;
    }
"""
assert old in s
s = s.replace(old, new, 1)

old = """  GSAutoLayoutEngine *engine = [self _layoutEngine];
  if (!engine)
    {
      return [NSArray array];
    }

  return [engine constraintsForView: self];"""
new = """  GSAutoLayoutEngine *engine = [self _layoutEngine];
  if (!engine)
    {
      NSArray *pending = GSPendingConstraints(self, NO);

      return pending ? [NSArray arrayWithArray: pending] : [NSArray array];
    }

  return [engine constraintsForView: self];"""
assert old in s
s = s.replace(old, new, 1)

old = "  [self viewDidMoveToWindow];\n"
assert old in s
s = s.replace(old, "  [self viewDidMoveToWindow];\n  [self _gsFlushPendingConstraints];\n", 1)

# the method is declared in a category that precedes its use
s = s.replace("- (void) _viewDidMoveToWindow;", "- (void) _viewDidMoveToWindow;\n- (void) _gsFlushPendingConstraints;", 1)
open(path, "w").write(s)
