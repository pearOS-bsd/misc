data=open('data.txt').read().split('\n'); ELL=None
rows=[]
for l in data:
    p=l.split('\t')
    if p[0].startswith('ELL'): ELL=float(p[0].split()[1])
    elif p[0]=='S': cur=p[1]; PW=[float(x) for x in p[3].split(',') if x]; SW=[float(x) for x in p[4].split(',') if x]
    elif p[0]=='R':
        w=float(p[1]); idx=[int(x) for x in p[2].split(',') if x]; gap=None
        for i in range(1,len(idx)):
            if idx[i]!=idx[i-1]+1: gap=i;break
        if gap is None: continue
        rows.append((cur,PW,SW,w,gap-1,len(idx)-gap))
def A(PW,SW,w):
    n=len(PW)-1; avail=w-ELL; half=avail/2
    h=max(k for k in range(n+1) if PW[k]<=half); t=max(k for k in range(n+1) if SW[k]<=half); return h,t
def C(PW,SW,w):
    n=len(PW)-1; avail=w-ELL; half=avail/2
    h=max(k for k in range(n+1) if PW[k]<=half); t=max(k for k in range(n+1) if SW[k]<=avail-PW[h]); return h,t
def D(PW,SW,w):  # alternate removal: grow head and tail one char at a time, whichever is narrower first, while the sum fits
    n=len(PW)-1; h=t=0
    while h+t<n:
        cand=[]
        if h+t<n and PW[h+1]+SW[t]+ELL<=w: cand.append(('h',PW[h+1]))
        if h+t<n and PW[h]+SW[t+1]+ELL<=w: cand.append(('t',SW[t+1]))
        if not cand: break
        side=min(cand,key=lambda c:c[1])[0]
        if side=='h': h+=1
        else: t+=1
    return h,t
for name,fn in (('A',A),('C',C),('D',D)):
    ok=sum(1 for (s,PW,SW,w,h,t) in rows if fn(PW,SW,w)==(h,t)); print(name,ok,'/',len(rows))
m=[(s[:22],round(w,1),(h,t),A(PW,SW,w)) for (s,PW,SW,w,h,t) in rows if A(PW,SW,w)!=(h,t)]
print(m[:15])
print('--- with whitespace trim')
strs={}
for l in data:
    p=l.split('\t')
    if p[0]=='S': strs[p[1]]=1
def A2(s,PW,SW,w):
    h,t=A(PW,SW,w); n=len(s)
    while h>0 and s[h-1]==' ': h-=1
    while t>0 and s[n-t]==' ': t-=1
    return h,t
ok=sum(1 for (s,PW,SW,w,h,t) in rows if A2(s,PW,SW,w)==(h,t)); print('A2',ok,'/',len(rows))
m=[(s[:22],round(w,1),(h,t),A2(s,PW,SW,w)) for (s,PW,SW,w,h,t) in rows if A2(s,PW,SW,w)!=(h,t)]
print(m)
print('--- eps search')
def A3(s,PW,SW,w,eps_h,eps_t):
    n=len(PW)-1; avail=w-ELL; half=avail/2
    h=max(k for k in range(n+1) if PW[k]<=half+eps_h); t=max(k for k in range(n+1) if SW[k]<=half+eps_t)
    while h>0 and s[h-1]==' ': h-=1
    while t>0 and s[n-t]==' ': t-=1
    return h,t
best=[]
for eh in [0,0.25,0.5,0.75,1,1.5,2]:
  for et in [0,0.25,0.5,0.75,1,1.5,2]:
    ok=sum(1 for (s,PW,SW,w,h,t) in rows if A3(s,PW,SW,w,eh,et)==(h,t)); best.append((ok,eh,et))
print(sorted(best,reverse=True)[:5])
