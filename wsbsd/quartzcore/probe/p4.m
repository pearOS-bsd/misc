#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
static CARenderer *R; static CALayer *L;
static void setup(void){
  id<MTLDevice> dev=MTLCreateSystemDefaultDevice();
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:100 height:100 mipmapped:NO]; td.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
  R=[CARenderer rendererWithMTLTexture:[dev newTextureWithDescriptor:td] options:nil];
  L=[CALayer layer]; L.frame=CGRectMake(10,20,100,50); R.layer=L; R.bounds=CGRectMake(0,0,400,300); [CATransaction flush]; [L removeAllAnimations];
}
static void show(const char *what){
  NSArray *keys=[L animationKeys]; printf("%s: keys=%s\n",what,[[keys description] UTF8String]);
  for(NSString *k in keys){ CAAnimation *a=[L animationForKey:k]; float c[2]={0,0}; float p[4]={0}; CAMediaTimingFunction*f=a.timingFunction; if(f){for(int i=0;i<4;i++){float v[2];[f getControlPointAtIndex:i values:v];p[i]=i==1?v[0]:p[i];}}
    float v1[2],v2[2]; [f getControlPointAtIndex:1 values:v1]; [f getControlPointAtIndex:2 values:v2];
    printf("  %s: class=%s dur=%g begin=%g speed=%g fill=%s removed=%d additive=%d tf=(%g,%g,%g,%g) from=%s to=%s by=%s\n",[k UTF8String],class_getName([a class]),a.duration,a.beginTime,a.speed,[a.fillMode UTF8String],a.removedOnCompletion,[a isKindOfClass:[CAPropertyAnimation class]]?((CAPropertyAnimation*)a).additive:0,f?v1[0]:-1,f?v1[1]:-1,f?v2[0]:-1,f?v2[1]:-1,
      [a isKindOfClass:[CABasicAnimation class]]?[[((CABasicAnimation*)a).fromValue description] UTF8String]:"-",[a isKindOfClass:[CABasicAnimation class]]?[[((CABasicAnimation*)a).toValue description] UTF8String]:"-",[a isKindOfClass:[CABasicAnimation class]]?[[((CABasicAnimation*)a).byValue description] UTF8String]:"-"); }
  [L removeAllAnimations];
}
int main(void){ @autoreleasepool { setup();
  L.opacity=0.5; show("opacity 0.5 (no txn)");
  [CATransaction begin]; [CATransaction setAnimationDuration:2]; L.opacity=0.2; [CATransaction commit]; show("opacity in txn dur 2");
  [CATransaction begin]; [CATransaction setAnimationDuration:1]; [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]]; L.position=CGPointMake(200,100); [CATransaction commit]; show("position txn tf easeIn");
  [CATransaction begin]; [CATransaction setDisableActions:YES]; L.opacity=0.9; [CATransaction commit]; show("disableActions");
  L.bounds=CGRectMake(0,0,200,100); show("bounds");
  L.backgroundColor=CGColorCreateGenericRGB(1,0,0,1); show("backgroundColor");
  L.cornerRadius=8; show("cornerRadius");
  L.transform=CATransform3DMakeRotation(1,0,0,1); show("transform");
  L.hidden=YES; show("hidden");
  L.anchorPoint=CGPointMake(0,0); show("anchorPoint");
  L.shadowOpacity=0.5; show("shadowOpacity"); L.shadowRadius=7; show("shadowRadius"); L.shadowOffset=CGSizeMake(1,2); show("shadowOffset");
  L.borderWidth=3; show("borderWidth"); L.zPosition=5; show("zPosition"); L.masksToBounds=YES; show("masksToBounds");
  L.contentsRect=CGRectMake(0,0,.5,.5); show("contentsRect"); L.contents=(id)[NSNull null]; 
  CALayer *sub=[CALayer layer]; [L addSublayer:sub]; show("addSublayer"); [sub removeFromSuperlayer]; show("removeSublayer");
  L.name=@"x"; show("name"); L.sublayerTransform=CATransform3DMakeScale(2,2,1); show("sublayerTransform");
  L.shadowColor=CGColorCreateGenericRGB(0,0,0,1); show("shadowColor"); L.borderColor=CGColorCreateGenericRGB(0,0,1,1); show("borderColor");
  L.maskedCorners=0; show("maskedCorners"); L.allowsGroupOpacity=NO; show("allowsGroupOpacity");
  L.speed=2; show("speed"); L.beginTime=1; show("beginTime");
  [CATransaction begin]; [CATransaction setAnimationDuration:0]; L.opacity=0.1; [CATransaction commit]; show("dur 0");
}return 0;}
