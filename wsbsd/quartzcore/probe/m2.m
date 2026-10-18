#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
void CAMat2Mix(double *out, const double *a, const double *b, double t);
static void run(const char*n, CGAffineTransform a, CGAffineTransform b, float f){
  NSValue*va=[NSValue valueWithBytes:&a objCType:@encode(CGAffineTransform)],*vb=[NSValue valueWithBytes:&b objCType:@encode(CGAffineTransform)];
  NSValue*r=((id(*)(id,SEL,id,float))objc_msgSend)(va,NSSelectorFromString(@"CA_interpolateValue:byFraction:"),vb,f);
  CGAffineTransform t; [r getValue:&t];
  double A[6]={a.a,a.b,a.c,a.d,a.tx,a.ty},B[6]={b.a,b.b,b.c,b.d,b.tx,b.ty},O[6]; CAMat2Mix(O,A,B,f);
  printf("%-22s real %8.5f %8.5f %8.5f %8.5f | ours %8.5f %8.5f %8.5f %8.5f\n",n,t.a,t.b,t.c,t.d,O[0],O[1],O[2],O[3]);
}
int main(void){
  run("rot .3 -> rot 1.2",CGAffineTransformMakeRotation(.3),CGAffineTransformMakeRotation(1.2),.5);
  run("scale 2 -> scale 4",CGAffineTransformMakeScale(2,2),CGAffineTransformMakeScale(4,4),.5);
  run("scale 2,3 -> 1,1",CGAffineTransformMakeScale(2,3),CGAffineTransformMakeScale(1,1),.25);
  run("id -> rot 1",CGAffineTransformIdentity,CGAffineTransformMakeRotation(1),.5);
  run("rot 1 -> id",CGAffineTransformMakeRotation(1),CGAffineTransformIdentity,.5);
  run("id -> rot 2.5",CGAffineTransformIdentity,CGAffineTransformMakeRotation(2.5),.5);
  run("rot -2 -> rot 2",CGAffineTransformMakeRotation(-2),CGAffineTransformMakeRotation(2),.5);
  run("sx-1 -> id",CGAffineTransformMakeScale(-1,1),CGAffineTransformIdentity,.5);
  CGAffineTransform f1=CGAffineTransformScale(CGAffineTransformMakeRotation(.7),-1,1), f2=CGAffineTransformMakeRotation(2.0);
  run("flipx rot.7 -> rot 2",f1,f2,.5); run("flipx rot.7 -> rot 2 @.2",f1,f2,.2);
  run("flipx -> id",CGAffineTransformMakeScale(-1,1),CGAffineTransformIdentity,.25);
  run("flipy rot -> flipx",CGAffineTransformScale(CGAffineTransformMakeRotation(1.1),1,-1),CGAffineTransformScale(CGAffineTransformMakeRotation(-.4),-1,1),.5);
  run("shear",CGAffineTransformMake(1,0,0.5,1,0,0),CGAffineTransformIdentity,.5);
  return 0;}
