#!/bin/sh
# builds xf_dump against this implementation and diffs it with the real QuartzCore output (zero signs ignored)
cd "$(dirname "$0")/.."
cc -fobjc-arc -Iinclude -framework Foundation -framework CoreGraphics -o probe/xf_ours probe/xf_dump.m src/CATransform3D.c src/NSValueCA.m 2>&1 | grep -E "error" | head
./probe/xf_ours > probe/asm/xf_ours.txt
python3 -I - probe/asm/xf_real.txt probe/asm/xf_ours.txt <<'P'
import sys,struct
def load(p): return [l.split() for l in open(p)]
a,b=load(sys.argv[1]),load(sys.argv[2]); bad=0; bitbad=0
def val(h): return struct.unpack('>d',bytes.fromhex(h))[0]
for i,(x,y) in enumerate(zip(a,b)):
    if x[0]!=y[0]: print('shape',i); bad+=1; continue
    if len(x)==17 and x[0] not in ('aff',):
        for k in range(1,17):
            if x[k]!=y[k]:
                vx,vy=val(x[k]),val(y[k])
                if vx==vy or abs(vx-vy)<=1e-12*max(abs(vx),abs(vy)): continue            # +0 / -0, or within 1e-12 relative
                bitbad+=1
                if bitbad<=6: print('line',i,x[0],'elem',k-1,repr(vx),repr(vy), 'ulp~', abs(vx-vy)/max(abs(vx),1e-300))
    elif x!=y:
        if x[0]=='aff' and all(abs(float(u)-float(v))<=1e-12*max(1,abs(float(u))) for u,v in zip(x[1:],y[1:])): continue
        print('diff',i,x[:3],y[:3]); bad+=1
print('lines',len(a),'value diffs',bitbad,'other',bad)
P
