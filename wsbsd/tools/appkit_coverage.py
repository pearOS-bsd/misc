#!/usr/bin/env python3
"""Measures how much of an Apple framework's Objective-C API (from the SDK headers) a GNUstep install declares.
usage: appkit_coverage.py APPLE_HEADERS_DIR GNUSTEP_HEADERS_DIR [--missing CLASS] [--json out.json]
Counts, per class (@interface Name and categories folded into it), the selectors declared by Apple and the ones GNUstep declares for the same class;
the Apple headers are read, never copied into the repository."""
import re,sys,os,json,collections
def strip(t):
    t=re.sub(r'/\*.*?\*/','',t,flags=re.S); t=re.sub(r'//[^\n]*','',t); return t
SEL=re.compile(r'^\s*([-+])\s*\([^)]*(?:\([^)]*\)[^)]*)*\)\s*([A-Za-z_]\w*)((?:\s*:\s*\((?:[^()]|\([^()]*\))*\)\s*\w+(?:\s+[A-Za-z_]\w*(?=\s*:))?)*)',re.M)
def selectors(body):
    out=set()
    for m in re.finditer(r'^\s*([-+])\s*\((?:[^()]|\([^()]*\))*\)\s*([^;{]*?)\s*(?:NS_\w+(?:\([^)]*\))?|API_\w+\([^)]*\)|__attribute__\(\([^)]*\)\)|;)',body,re.M):
        k,rest=m.group(1),m.group(2).strip()
        if ':' not in rest:
            name=re.match(r'[A-Za-z_]\w*',rest)
            if name: out.add(k+name.group(0))
        else:
            parts=re.findall(r'([A-Za-z_]\w*)?\s*:\s*\((?:[^()]|\([^()]*\))*\)\s*\w+',rest)
            if parts: out.add(k+''.join((p or '')+':' for p in parts))
    for m in re.finditer(r'@property\s*(?:\(([^)]*)\))?[^;]*?[\s*]([A-Za-z_]\w*)\s*(?:NS_\w+|API_\w+\([^)]*\)|;)',body):
        attrs=m.group(1) or ''; n=m.group(2); g=re.search(r'getter\s*=\s*(\w+)',attrs)
        out.add('-'+(g.group(1) if g else n))
        if 'readonly' not in attrs: out.add('-set'+n[0].upper()+n[1:]+':')
    return out
def scan(d):
    cls=collections.defaultdict(set)
    for root,_,fs in os.walk(d):
        for f in fs:
            if not f.endswith('.h'): continue
            t=strip(open(os.path.join(root,f),errors='ignore').read())
            for m in re.finditer(r'@interface\s+(\w+)\s*(?:\(\s*\w*\s*\))?[^{;]*?(?:\{[^}]*\})?(.*?)@end',t,re.S):
                cls[m.group(1)]|=selectors(m.group(2))
    return cls
def main():
    a,g=scan(sys.argv[1]),scan(sys.argv[2])
    tot=have=0; rows=[]
    for c,s in sorted(a.items()):
        if not s: continue
        h=len(s&g.get(c,set())) if c in g else 0
        tot+=len(s); have+=h; rows.append((c,len(s),h,c in g))
    print('Apple classes with methods: %d, GNUstep declares %d of them'%(len(rows),sum(1 for r in rows if r[3])))
    print('selectors: Apple %d, GNUstep has %d = %.1f %%'%(tot,have,100.0*have/max(tot,1)))
    if '--missing' in sys.argv:
        c=sys.argv[sys.argv.index('--missing')+1]; print(c, sorted(a.get(c,set())-g.get(c,set())))
    else:
        for r in sorted(rows,key=lambda r:r[2]-r[1])[:25]: print('%-34s apple %4d  gnustep %4d  %s'%(r[0],r[1],r[2],'' if r[3] else '(class missing)'))
    if '--json' in sys.argv:
        json.dump({r[0]:{'apple':r[1],'gnustep':r[2],'class':r[3]} for r in rows},open(sys.argv[sys.argv.index('--json')+1],'w'),indent=1)
main()
