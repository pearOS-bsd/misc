#!/usr/bin/env python3
"""libs-gui, GSAutoLayoutEngine: the solver does not survive removing constraints (a layout that removed its constraints and added them again, as TextMate's OakDocumentView does in
updateConstraints, kept the views at their minimum sizes and the intrinsic edits of the others were lost). After a removal the solver is now built again from the constraints that are left.
usage: patch-engine-rebuild.py GSAutoLayoutEngine.m"""
import sys
path = sys.argv[1]
s = open(path).read()
if "_gsRebuildSolver" in s:
    sys.exit(0)

def sub(old, new):
    global s
    assert old in s, old
    s = s.replace(old, new, 1)

sub("""  [_solver removeConstraints: _batchedSolverConstraints];
  [_batchedSolverConstraints removeAllObjects];
  [self updateAlignmentRectsForTrackedViews];
}
""", """  [_solver removeConstraints: _batchedSolverConstraints];
  [_batchedSolverConstraints removeAllObjects];
  [self _gsRebuildSolver];
}

/* everything the solver knows is derived from the layout constraints, so it is thrown away and filled again */
- (void) _gsRebuildSolver
{
  NSMutableArray *all = [NSMutableArray array];
  NSHashTable *seen = [NSHashTable hashTableWithOptions: NSPointerFunctionsObjectPointerPersonality];
  NSUInteger i;
  GSCassowarySolver *solver;

  for (i = 0; i < [_trackedViews count]; i++)
    {
      NSArray *list = [_constraintsByViewIndex objectForKey: [NSNumber numberWithUnsignedInteger: i]];
      FOR_IN(NSLayoutConstraint *, constraint, list)
        if (![seen containsObject: constraint])
          {
            [seen addObject: constraint];
            [all addObject: constraint];
          }
      END_FOR_IN(list);
    }
  RETAIN(all);
  solver = [[GSCassowarySolver alloc] init];
  ASSIGN(_solver, solver);
  RELEASE(solver);
  [_variablesByKey removeAllObjects];
  [_constraintsByAutoLayoutConstaintHash removeAllObjects];
  [_layoutConstraintsBySolverConstraint removeAllObjects];
  [_solverConstraints removeAllObjects];
  [_supportingConstraintsByConstraint removeAllObjects];
  [_internalConstraintsByViewIndex removeAllObjects];
  [_batchedSolverConstraints removeAllObjects];
  [_constraintsByViewIndex removeAllObjects];
  [_viewIndexByViewHash removeAllObjects];
  [_viewAlignmentRectByViewIndex removeAllObjects];
  [_trackedViews removeAllObjects];
  [self addConstraints: all];
  RELEASE(all);
}
""")
sub("""      [self removeInternalConstraintsForView: [constraint secondItem]];
    }
}
""", """      [self removeInternalConstraintsForView: [constraint secondItem]];
    }
  if (_batchDepth == 0)
    {
      [self _gsRebuildSolver];
    }
}
""")
sub("""    GSCSVariable *editVariable = [self getExistingVariableForView: view
                                                withViewAttribute: attribute];
    CGFloat value""", """    GSCSVariable *editVariable = [self getExistingVariableForView: view
                                                withViewAttribute: attribute];
    CGFloat value""")
sub("""- (void) resolveVariableForView: (NSView *)view
                      attribute: (GSLayoutViewAttribute)attribute
{
""", """- (void) resolveVariableForView: (NSView *)view
                      attribute: (GSLayoutViewAttribute)attribute
{
    /* the edit constraint of this variable may still wait in the batch, and the suggestion needs it in the solver */
    if (_batchDepth > 0 && [_batchedSolverConstraints count] > 0)
      {
        [_solver addConstraints: _batchedSolverConstraints];
        [_batchedSolverConstraints removeAllObjects];
      }
""")
open(path, "w").write(s)
