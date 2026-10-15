# Scans the decompiled routines (scratchpad corpus) for ones whose success path writes only the return code; the output was filtered by hand with the recorded
# exceptions (30019, 30494 write the NDR) into src/sls_zero_ndr.h.
import json,glob,re,sys
items={}
for f in sorted(glob.glob('/private/tmp/claude-501/-Users-alxb421-Desktop-app/99e54da3-d84c-4f4f-abcf-77e1f01a4997/scratchpad/corpus/*.txt')):
    try: d=json.load(open(f))
    except: continue
    for it in d['normalized_result']['items']:
        if it.get('status')=='ok' and it.get('pseudocode'): items[it['procedure']['name']]=it['pseudocode']
tab={}
for l in open('/Users/alxb421/Desktop/app/misc/wsbsd/docs/skylight-msgid-table.txt'):
    m=re.match(r'(\d+)\s+(__X\w+)\s+(\d+)\s+(0x[0-9a-f]+)',l)
    if m: tab[int(m.group(1))]=(m.group(2),int(m.group(4),16))
res={}
for id,(n,rs) in tab.items():
    c=items.get(n)
    if not c: continue
    lines=[x.strip() for x in c.split('\n')]
    ndr=[i for i,x in enumerate(lines) if re.search(r'\+ 0x18\) = \*_DAT_1e020bd00',x) or re.search(r'param_2\[6\] = \*_DAT',x)]
    if not ndr: res[id]=('nondr',rs); continue
    succ=0
    for i in ndr:
        prev=' '.join(lines[max(0,i-2):i])
        if re.search(r'(0xfffffe\w\w|0x3e[0-9a-f]|1000|0x3e8|-0x1\w+)\s*;',prev) or re.search(r'= u?Var\d+;',prev) : continue
        succ+=1
    res[id]=('succ_writes' if succ else 'err_only',rs)
import collections
print(collections.Counter(v[0] for v in res.values()))
print({k:v for k,v in res.items() if k in (30279,30019,30040,30127,30249,30023,30162,30545,30167,30312)})
json.dump({str(k):v for k,v in res.items()},open('/tmp/cov/ndrscan.json','w'))
