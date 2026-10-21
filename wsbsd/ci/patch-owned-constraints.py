#!/usr/bin/env python3
"""libs-gui, NSView: -constraints answers the constraints a view owns (the ones added to it with addConstraint:), as on a Mac. The engine only knows the constraints whose first item is the view, so
`[self removeConstraints:[self constraints]]` (OakDocumentView updateConstraints) left the old ones in place and the layout broke. Run after patch-pending-constraints.py.
usage: patch-owned-constraints.py NSView.m"""
import sys
path = sys.argv[1]
s = open(path).read()
if "GSOwnedConstraintsKey" in s:
    sys.exit(0)

def sub(old, new):
    global s
    assert old in s, old
    s = s.replace(old, new, 1)

sub("static char GSPendingConstraintsKey;\n", """static char GSPendingConstraintsKey;
static char GSOwnedConstraintsKey;

static NSMutableArray *
GSOwnedConstraints(NSView *view)
{
  NSMutableArray *a = objc_getAssociatedObject(view, &GSOwnedConstraintsKey);

  if (a == nil)
    {
      a = [NSMutableArray array];
      objc_setAssociatedObject(view, &GSOwnedConstraintsKey, a,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  return a;
}
""")
sub("- (void) addConstraint: (NSLayoutConstraint *)constraint\n{\n", "- (void) addConstraint: (NSLayoutConstraint *)constraint\n{\n  [GSOwnedConstraints(self) addObject: constraint];\n")
sub("- (void) addConstraints: (NSArray*)constraints\n{\n", "- (void) addConstraints: (NSArray*)constraints\n{\n  [GSOwnedConstraints(self) addObjectsFromArray: constraints];\n")
sub("- (void) removeConstraint: (NSLayoutConstraint *)constraint\n{\n", "- (void) removeConstraint: (NSLayoutConstraint *)constraint\n{\n  [GSOwnedConstraints(self) removeObjectIdenticalTo: constraint];\n")
sub("- (void) removeConstraints: (NSArray *)constraints\n{\n", "- (void) removeConstraints: (NSArray *)constraints\n{\n  [GSOwnedConstraints(self) removeObjectsInArray: constraints];\n")
sub("- (NSArray*) constraints\n{\n", "- (NSArray*) constraints\n{\n  return [NSArray arrayWithArray: GSOwnedConstraints(self)];\n}\n\n- (NSArray*) _gsEngineConstraints\n{\n")
open(path, "w").write(s)
