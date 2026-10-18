#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
int main(void){ @autoreleasepool {
  CALayer *l=[CALayer layer]; l.frame=CGRectMake(0,0,100,100);
  CABasicAnimation *a=[CABasicAnimation animationWithKeyPath:@"opacity"]; a.fromValue=@0; a.toValue=@1; a.duration=1; a.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  a.fillMode=kCAFillModeBoth;
  [l addAnimation:a forKey:@"a"];
  [CATransaction flush];
  CALayer *p=[l presentationLayer]; printf("pres=%p model opacity=%g\n",p,l.opacity);
  l.speed=0;
  for(double t=0;t<=1.0001;t+=0.125){ l.timeOffset=t; [CATransaction flush]; printf("t=%g pres opacity=%.9g\n",t,[[l presentationLayer] opacity]); }
}return 0;}
