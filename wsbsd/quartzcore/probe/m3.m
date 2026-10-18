#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
void CAMat2Mix(double *out, const double *a, const double *b, double t);
int main(void){
  CGAffineTransform a=CGAffineTransformMake(-0.9656905258178865,-0.10212266134641342,0.24990732685502512,-2.3631692975346392,-46.024687700685803,-23.736716529370245);
  CGAffineTransform b=CGAffineTransformMake(1.454914949397953,-2.4827400939205364,0.77549830087508365,0.45445114208236692,-41.225846403639771,141.25260885113565);
  NSValue*va=[NSValue valueWithBytes:&a objCType:@encode(CGAffineTransform)],*vb=[NSValue valueWithBytes:&b objCType:@encode(CGAffineTransform)];
  float f=0.994536f; NSValue*r=((id(*)(id,SEL,id,float))objc_msgSend)(va,NSSelectorFromString(@"CA_interpolateValue:byFraction:"),vb,f);
  CGAffineTransform t; [r getValue:&t]; printf("real %.9g %.9g %.9g %.9g\n",t.a,t.b,t.c,t.d);
  double A[6]={a.a,a.b,a.c,a.d,a.tx,a.ty},B[6]={b.a,b.b,b.c,b.d,b.tx,b.ty},O[6]; CAMat2Mix(O,A,B,f); printf("ours %.9g %.9g %.9g %.9g\n",O[0],O[1],O[2],O[3]);
  CATransform3D m1=CATransform3DIdentity,m2=CATransform3DIdentity; m1.m11=a.a;m1.m12=a.b;m1.m21=a.c;m1.m22=a.d;m1.m41=a.tx;m1.m42=a.ty; m2.m11=b.a;m2.m12=b.b;m2.m21=b.c;m2.m22=b.d;m2.m41=b.tx;m2.m42=b.ty;
  NSValue*r3=((id(*)(id,SEL,id,float))objc_msgSend)([NSValue valueWithCATransform3D:m1],NSSelectorFromString(@"CA_interpolateValue:byFraction:"),[NSValue valueWithCATransform3D:m2],f); CATransform3D t3=[r3 CATransform3DValue]; printf("real3d %.9g %.9g %.9g %.9g\n",t3.m11,t3.m12,t3.m21,t3.m22);
}
