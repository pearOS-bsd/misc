#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
int main(void){ @autoreleasepool {
  for (NSString *n in @[kCAMediaTimingFunctionLinear,kCAMediaTimingFunctionEaseIn,kCAMediaTimingFunctionEaseOut,kCAMediaTimingFunctionEaseInEaseOut,kCAMediaTimingFunctionDefault]) {
    CAMediaTimingFunction *f=[CAMediaTimingFunction functionWithName:n]; float p[2]; printf("%s:",[n UTF8String]);
    for(int i=0;i<4;i++){[f getControlPointAtIndex:i values:p]; printf(" (%g,%g)",p[0],p[1]);}
    printf("\n");
    SEL s=NSSelectorFromString(@"_solveForInput:");
    if([f respondsToSelector:s]) for(double x=0;x<=1.0001;x+=0.125) printf("  solve(%g)=%.9g\n",x,((float(*)(id,SEL,float))objc_msgSend)(f,s,(float)x));
  }
  CALayer *l=[CALayer layer];
  printf("layer defaults: opacity=%g anchor=%g,%g bounds=%s pos=%g,%g z=%g cr=%g\n",l.opacity,l.anchorPoint.x,l.anchorPoint.y,[NSStringFromRect(l.bounds) UTF8String],l.position.x,l.position.y,l.zPosition,l.cornerRadius);
  printf("tx duration=%g timingfn=%p disable=%d\n",[CATransaction animationDuration],[CATransaction animationTimingFunction],[CATransaction disableActions]);
  CASpringAnimation *sp=[CASpringAnimation animationWithKeyPath:@"opacity"];
  printf("spring defaults: m=%g k=%g c=%g v0=%g dur=%g settling=%g\n",sp.mass,sp.stiffness,sp.damping,sp.initialVelocity,sp.duration,sp.settlingDuration);
  unsigned n; Class *cl=objc_copyClassList(&n); 
  for(unsigned i=0;i<n;i++){const char*nm=class_getName(cl[i]); if(nm[0]=='C'&&nm[1]=='A'&&strncmp(nm,"CAM",3)&&1) {printf("class %s : %s\n",nm,class_getName(class_getSuperclass(cl[i])));}}
}return 0;}
