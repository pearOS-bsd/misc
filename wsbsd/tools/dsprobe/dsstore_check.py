import struct,sys
def parse(path):
    d=open(path,'rb').read(); assert d[:4]==b'\0\0\0\1' and d[4:8]==b'Bud1'
    off,size,off2=struct.unpack('>III',d[8:20]); root=d[off+4:off+4+size]
    n,_=struct.unpack('>II',root[:8]); offs=list(struct.unpack('>%dI'%n,root[8:8+4*n])); p=8+4*n
    p+= (-n % 256)*4
    tc=struct.unpack('>I',root[p:p+4])[0]; p+=4; toc={}
    for i in range(tc):
        l=root[p]; name=root[p+1:p+1+l].decode(); p+=1+l; toc[name]=struct.unpack('>I',root[p:p+4])[0]; p+=4
    def block(i):
        a=offs[i]; o=a&~0x1f; s=1<<(a&0x1f); return d[o+4:o+4+s]
    db=block(toc['DSDB']); rootid,levels,nrec,nnodes,ps=struct.unpack('>5I',db[:20]); recs=[]
    def rec(b,p):
        l=struct.unpack('>I',b[p:p+4])[0]; p+=4; name=b[p:p+2*l].decode('utf-16-be'); p+=2*l; sid=b[p:p+4].decode(); t=b[p+4:p+8].decode(); p+=8
        if t=='bool': v=b[p]; p+=1
        elif t in('long','shor'): v=struct.unpack('>I',b[p:p+4])[0]; p+=4
        elif t=='type': v=b[p:p+4].decode(); p+=4
        elif t=='comp' or t=='dutc': v=struct.unpack('>Q',b[p:p+8])[0]; p+=8
        elif t=='blob': l2=struct.unpack('>I',b[p:p+4])[0]; v=b[p+4:p+4+l2]; p+=4+l2
        elif t=='ustr': l2=struct.unpack('>I',b[p:p+4])[0]; v=b[p+4:p+4+2*l2].decode('utf-16-be'); p+=4+2*l2
        else: raise Exception('type '+t)
        return (name,sid,t,v),p
    def walk(i):
        b=block(i); P,cnt=struct.unpack('>II',b[:8]); p=8
        if P==0:
            for _ in range(cnt): r,p=rec(b,p); recs.append(r)
        else:
            for _ in range(cnt):
                ch=struct.unpack('>I',b[p:p+4])[0]; p+=4; walk(ch); r,p=rec(b,p); recs.append(r)
            walk(P)
    walk(rootid); return recs,dict(levels=levels,nrec=nrec,nnodes=nnodes,ps=ps,nblocks=n)
if __name__=='__main__':
    recs,info=parse(sys.argv[1]); print(info)
    for r in recs[:int(sys.argv[2]) if len(sys.argv)>2 else 40]: print(r if r[1] not in('Iloc',) else (r[0],r[1],struct.unpack('>II',r[3][:8]),r[3][8:].hex()))
