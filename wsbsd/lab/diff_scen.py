#!/usr/bin/env python3
"""Compares the output of lab/scen.c (the real WindowServer) with lab/scen_wsd.c (wsd) for the same scenario: reply id, header bits, size and body, line by line.
Window ids and the connection id differ between servers: 4-aligned little-endian words equal to a window id / the connection id are replaced by a name before comparing.
usage: diff_scen.py real.out wsd.out"""
import re,sys
def load(path):
    names={}; cid=None; out=[]
    for l in open(path):
        l=l.rstrip('\n')
        m=re.match(r'cid=(\d+)',l)
        if m: cid=int(m[1]); continue
        m=re.match(r'# new_window (\w+) err=\d+ wid=(\d+)',l)
        if m: names[int(m[2])]=m[1]; continue
        m=re.match(r'raw (\d+) (?:reqsize=(\d+) -> reply_id=(\d+) bits=(\w+) size=(\d+) hex=([0-9a-f]*)|.*(error.*))',l)
        if m: out.append([int(m[1]),m[2],m[3],m[4],m[5],m[6] or '',m[7],None]); continue
        m=re.match(r'ool size=(\d+) hex=([0-9a-f]*)',l)
        if m and out: out[-1][7]=(m[1],m[2])
    return names,cid,out
def norm(hexs,names,cid):
    b=bytearray.fromhex(hexs) if hexs and len(hexs)%2==0 else bytearray()
    if len(b)>=24 and int.from_bytes(b[0:4],'little')==1 and b[15:16]==b'\x01': b[4:12]=b'\0'*8     # a complex reply: the out-of-line address is a pointer, never compared
    words=[]
    for i in range(0,len(b)-3,4):
        v=int.from_bytes(b[i:i+4],'little')
        words.append('<w:%s>'%names[v] if (v in names and i>=8) else '<cid>' if v==cid and v>0xff else '%08x'%v)
    return ' '.join(words)
import struct
def p64(b,i):
    t=b[i]; i+=1
    if t<0x10: return -(t&1),i
    n=t>>4; v=int.from_bytes(b[i:i+n],'big'); i+=n
    if t&1 and n<8: sg=1<<(8*n-1); v=(v^sg)-sg
    return v,i
def num(b,i):
    t=b[i]
    if t==0x88: return struct.unpack('<d',b[i+1:i+9])[0],i+9
    if t==0x48: return round(struct.unpack('<f',b[i+1:i+5])[0],4),i+5
    return p64(b,i)
def window_query(hexs,names,cid):
    """WindowQuery reply: the window records decoded; ids, owner and pid are masked"""
    b=bytes.fromhex(hexs); off=4+8+4+4+8
    ln=int.from_bytes(b[off:off+4],'little'); st=b[off+4:off+4+ln]
    slots=[int.from_bytes(st[j:j+4],'little') for j in (0,4,8)]
    lo=slots[0]; recs=[]
    if lo!=0xffffffff:
        cnt=int.from_bytes(st[lo:lo+4],'little'); offs=[int.from_bytes(st[lo+4+4*j:lo+8+4*j],'little') for j in range(cnt)]
        for o in offs:
            i=o+1; wid,i=p64(st,i); own,i=p64(st,i); par,i=p64(st,i); pid,i=p64(st,i); a,i=p64(st,i); b2,i=p64(st,i); lev,i=p64(st,i); al,i=num(st,i)
            r=[]
            for q in range(16):
                v,i=num(st,i); r.append(v)
            rad,i=num(st,i); z,i=num(st,i); tl,i=p64(st,i); th,i=p64(st,i)
            recs.append((names.get(wid,'wid?'),'owner','par:%s'%names.get(par,par) if par else 0,'pid',a,b2,lev,al,tuple(r),rad,z,hex(tl|th<<32)))
    return slots[1:],recs
rn,rc,ro=load(sys.argv[1]); wn,wc,wo=load(sys.argv[2])
same=diff=0
for k,(a,b) in enumerate(zip(ro,wo)):
    if True:
        if a[0]==30474 and b[0]==30474 and a[2:5]==b[2:5] and 'sys' not in sys.argv:
            try: da=window_query(a[5],rn,rc); db=window_query(b[5],wn,wc)
            except Exception as e: da=db=None
            ok=a[3]==b[3] and da==db and da is not None
            if not ok and da is not None:
                diff+=1; print("DIFF line",k,"id 30474 (decoded)"); print("   real",da); print("   wsd ",db); continue
        else:
            ok=(a[0]==b[0] and a[2:5]==b[2:5] and norm(a[5],rn,rc)==norm(b[5],wn,wc) and a[7]==b[7])
    if ok: same+=1; continue
    diff+=1
    print("DIFF line",k,"id",a[0])
    for tag,x,nn,cc in (("real",a,rn,rc),("wsd ",b,wn,wc)):
        print("  ",tag,"reply",x[2],"bits",x[3],"size",x[4],norm(x[5],nn,cc)[:230], ("ool "+x[7][0]+" "+x[7][1][:80]) if x[7] else "")
if len(ro)!=len(wo): print("different number of replies: real",len(ro),"wsd",len(wo))
print("%d equal, %d differ"%(same,diff))
