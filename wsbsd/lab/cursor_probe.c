#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
typedef int (*conn_fn)(void);
typedef int (*reg2_fn)(double,double,double,double,double,double,int,int,const char*,uint8_t,uint8_t,unsigned long,void*,int,void*,unsigned,unsigned,unsigned,int,int*);
typedef int (*is_fn)(int,const char*,int*);
typedef int (*get2_fn)(int,const char*,void*,unsigned*,int*,double*,double*,double*,int*,int*,int*,int*,int*);
typedef int (*size_fn)(int,const char*,int*);
int main(void){ setvbuf(stdout,NULL,_IONBF,0);
  void *h=dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",RTLD_NOW);
  conn_fn mainconn=dlsym(h,"SLSMainConnectionID"); reg2_fn reg=0;
  get2_fn get=(get2_fn)((uintptr_t)mainconn-0x187039490UL+0x186e739c8UL); size_fn gsz=(size_fn)((uintptr_t)mainconn-0x187039490UL+0x186e736a4UL);
  reg=(reg2_fn)((uintptr_t)mainconn-0x187039490UL+0x186e726dcUL); printf("syms %p %p %p %p\n",mainconn,reg,get,gsz); if(!mainconn||!reg||!get) return 1;
  int cid=mainconn(); printf("cid %d\n",cid);
  int cols=64, rows=48; uint32_t *px=malloc(cols*rows*4);
  for(int i=0;i<cols*rows;i++) px[i]=0xff000000|(i&0xff)<<8|((i>>8)&0xff); /* ARGB opaque */
  int seed=0x1234;
  /* params: cols rows wpts hpts hotx hoty | seed? cid? name global flags ... */
  int out=-1;
  int rc=reg(cols,rows,32,24,10,14, cid,seed,"wsbsd.probe.cursor",0,0,0,px,cols*4,NULL,0, 4,1,0,&out);
  printf("register rc=%d out=%d\n",rc,out);
  int isreg=-1; unsigned sz=0;
  int rb=0; double pxsz[2]={-1,-1},a[2]={-1,-1},b[2]={-1,-1}; int bpp=0,spp=0,bps=0,u1=-1,u2=-1;
  uint8_t *buf=malloc(cols*rows*4+64); sz=cols*rows*4+64;
  rc=get(cid,"wsbsd.probe.cursor",buf,&sz,&rb,pxsz,a,b,&bpp,&spp,&bps,&u1,&u2);
  printf("get rc=%d size=%u rowbytes=%d pxsz=(%g,%g) p7=(%g,%g) p8=(%g,%g) bpp=%d spp=%d bps=%d u=(%d,%d)\n",rc,sz,rb,pxsz[0],pxsz[1],a[0],a[1],b[0],b[1],bpp,spp,bps,u1,u2);
  printf("first px %02x%02x%02x%02x  (src %08x)\n",buf[0],buf[1],buf[2],buf[3],px[0]);
  printf("px[1] %02x%02x%02x%02x (src %08x)\n",buf[4],buf[5],buf[6],buf[7],px[1]);
  int s2=0; rc=gsz(cid,"wsbsd.probe.cursor",&s2); printf("datasize rc=%d %d\n",rc,s2);
  return 0;}
