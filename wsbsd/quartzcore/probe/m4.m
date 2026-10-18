#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
void CAMat2Mix(double *out, const double *a, const double *b, double t);
static double err(CGAffineTransform a, CGAffineTransform b, float f, double *ra, double*oa){
  NSValue*va=[NSValue valueWithBytes:&a objCType:@encode(CGAffineTransform)],*vb=[NSValue valueWithBytes:&b objCType:@encode(CGAffineTransform)];
  NSValue*r=((id(*)(id,SEL,id,float))objc_msgSend)(va,NSSelectorFromString(@"CA_interpolateValue:byFraction:"),vb,f);
  CGAffineTransform t; [r getValue:&t];
  double A[6]={a.a,a.b,a.c,a.d,a.tx,a.ty},B[6]={b.a,b.b,b.c,b.d,b.tx,b.ty},O[6]; CAMat2Mix(O,A,B,f);
  double e=fabs(t.a-O[0])+fabs(t.b-O[1])+fabs(t.c-O[2])+fabs(t.d-O[3]); if(ra){ra[0]=t.a;ra[1]=t.b;ra[2]=t.c;ra[3]=t.d;oa[0]=O[0];oa[1]=O[1];oa[2]=O[2];oa[3]=O[3];} return e;}
int main(void){
  double ths[]={0,0.5,1.5,2.0,2.5,3.0,-0.5,-1.5,-2.5,-3.0};
  for(int i=0;i<10;i++) for(int j=0;j<10;j++){ 
    for(int sc=0;sc<3;sc++){
      double s1x=sc==0?1:2, s1y=sc==0?1:(sc==1?2:3);
      CGAffineTransform a=CGAffineTransformScale(CGAffineTransformMakeRotation(ths[i]),s1x,s1y), b=CGAffineTransformScale(CGAffineTransformMakeRotation(ths[j]),1.2,sc==0?1.2:0.7);
      double ra[4],oa[4]; double e=err(a,b,.5,ra,oa);
      if(e>1e-6) printf("A=rot %.1f sc %g,%g  B=rot %.1f s1.5 : real %.4f %.4f %.4f %.4f ours %.4f %.4f %.4f %.4f\n",ths[i],s1x,s1y,ths[j],ra[0],ra[1],ra[2],ra[3],oa[0],oa[1],oa[2],oa[3]);
    }}
  return 0;}
