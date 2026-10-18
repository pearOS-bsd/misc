#!/usr/bin/env python3
"""pubfilter.py DUMP HEADERDIR: keeps, in a dump of the properties of the real classes (public and private), those that our public headers declare"""
import re, glob, sys
pub = {}
for f in glob.glob(sys.argv[2] + '/*.h'):
    s = open(f).read()
    for m in re.finditer(r'@interface\s+(\w+)\s*:\s*\w+[^{]*?(?:\{[^}]*\})?(.*?)@end', s, re.S):
        for p in re.finditer(r'@property[^;]*?(\w+)\s*;', m.group(2)): pub.setdefault(m.group(1), set()).add(p.group(1))
sup = {'CAShapeLayer': 'CALayer', 'CATextLayer': 'CALayer', 'CAGradientLayer': 'CALayer', 'CAReplicatorLayer': 'CALayer', 'CAScrollLayer': 'CALayer', 'CATiledLayer': 'CALayer', 'CAEmitterLayer': 'CALayer', 'CAPropertyAnimation': 'CAAnimation', 'CABasicAnimation': 'CAPropertyAnimation', 'CAKeyframeAnimation': 'CAPropertyAnimation', 'CASpringAnimation': 'CABasicAnimation', 'CATransition': 'CAAnimation', 'CAAnimationGroup': 'CAAnimation'}
timing = {'beginTime', 'duration', 'speed', 'timeOffset', 'repeatCount', 'repeatDuration', 'autoreverses', 'fillMode'}
def allp(c):
    r = set(pub.get(c, ()))
    if sup.get(c): r |= allp(sup[c])
    return r
cur = None; seen = set()
for l in open(sys.argv[1]):
    if l.startswith('## '): cur = l[3:].strip(); seen = set(); sys.stdout.write(l); continue
    k = l.split(' = ')[0]
    if k in allp(cur) | timing and k not in seen: seen.add(k); sys.stdout.write(l)
