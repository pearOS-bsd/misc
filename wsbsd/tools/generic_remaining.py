#!/usr/bin/env python3
"""Lists the SkyLight routines that only have a wire-correct acceptor (src/sls_generic.c) and no dedicated handler: a table entry whose id is neither a `case N` nor an SLS_MSG_ name used by another
source file. Many entries of the table are shadowed by dedicated handlers; this is the real remainder. usage: python3 tools/generic_remaining.py"""
import re, glob
gen = open('src/sls_generic.c').read()
ids = [(int(m.group(1)), m.group(2)) for m in re.finditer(r'\{ (\d+), \d+, \d, \d, \d+ \},\s*/\* __X(\w+) \*/', gen)]
hdr = open('include/sls_msgids.h').read()
id2name = {}
for m in re.finditer(r'#define (SLS_MSG_\w+) (\d+)', hdr): id2name.setdefault(int(m.group(2)), m.group(1))
src = ''
for f in glob.glob('src/*.c') + glob.glob('src/*.h'):
    if f.endswith('sls_generic.c') or any(k in f for k in ('zero_ndr', 'harvest', 'golden', 'blobs')): continue
    src += open(f).read()
real = [(i, n) for i, n in ids if not (re.search(r'case %d\b' % i, src) or (i in id2name and re.search(r'\b%s\b' % id2name[i], src)))]
print(len(ids), 'entries in the table;', len(real), 'without a dedicated handler')
for i, n in real: print(i, n)
