#!/usr/bin/env python3
"""libs-gui: GSAutoLayoutEngine solves the vertical attributes upwards (Top = maxY, Bottom = minY); Cocoa's Top / Bottom grow downwards, so "bottom = superview.bottom - 20" is an inset of
20 and a xib's "superview.bottom = view.bottom + 1" puts the view 1 above the bottom. A relation between two vertical position attributes (top, bottom, centerY, the baselines) with
multiplier 1 is mirrored: the constant changes sign and <= / >= swap.
usage: patch-autolayout-vertical.py Source/GSAutoLayoutEngine.m"""
import sys

path = sys.argv[1]
s = open(path).read()
if "GSVerticalMirror" in s:
    sys.exit(0)
old = """  double constant = [constraint constant];

  GSCSLinearExpression *rightExpression = [[GSCSLinearExpression alloc]"""
new = """  double constant = [constraint constant];

  /* GSVerticalMirror: Cocoa's vertical attributes grow downwards */
  {
    NSInteger fa = [constraint firstAttribute];
    NSInteger sa = [constraint secondAttribute];
    BOOL fv = (fa == NSLayoutAttributeTop || fa == NSLayoutAttributeBottom || fa == NSLayoutAttributeCenterY
               || fa == NSLayoutAttributeBaseline || fa == NSLayoutAttributeFirstBaseline);
    BOOL sv = (sa == NSLayoutAttributeTop || sa == NSLayoutAttributeBottom || sa == NSLayoutAttributeCenterY
               || sa == NSLayoutAttributeBaseline || sa == NSLayoutAttributeFirstBaseline);
    if (fv && sv && multiplier == 1.0)
      {
        constant = -constant;
        if (op == GSCSConstraintOperatorLessThanOrEqual)
          {
            op = GSCSConstraintOperationGreaterThanOrEqual;
          }
        else if (op == GSCSConstraintOperationGreaterThanOrEqual)
          {
            op = GSCSConstraintOperatorLessThanOrEqual;
          }
      }
  }

  GSCSLinearExpression *rightExpression = [[GSCSLinearExpression alloc]"""
assert old in s
open(path, "w").write(s.replace(old, new, 1))
