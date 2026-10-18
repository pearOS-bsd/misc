#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
static CALayer *L;
static void setup(void){
  id<MTLDevice> dev=MTLCreateSystemDefaultDevice();
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:100 height:100 mipmapped:NO]; td.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
  static CARenderer *R; R=[CARenderer rendererWithMTLTexture:[dev newTextureWithDescriptor:td] options:nil];
  L=[CALayer layer]; L.frame=CGRectMake(10,20,100,50); R.layer=L; R.bounds=CGRectMake(0,0,400,300); [CATransaction flush];
}
static void pm(const char*n,CATransform3D m){ CGFloat*f=(CGFloat*)&m; printf("%s [",n); for(int i=0;i<16;i++) printf("%s%.5g",i?" ":"",f[i]); printf("]\n"); }
static void probe(const char *name, NSString *kp, id from, id to, double t, BOOL additive){
  CABasicAnimation *a=[CABasicAnimation animationWithKeyPath:kp]; a.fromValue=from; a.toValue=to; a.duration=1; a.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]; a.speed=0; a.timeOffset=t; a.fillMode=kCAFillModeBoth; a.removedOnCompletion=NO; a.additive=additive;
  [L removeAllAnimations]; [L addAnimation:a forKey:@"a"]; [CATransaction flush]; pm(name,[[L presentationLayer] transform]);
}
int main(void){ @autoreleasepool { setup();
  CATransform3D base=CATransform3DScale(CATransform3DMakeRotation(0.5,0,0,1),2,3,1); base=CATransform3DTranslate(base,10,20,0); L.transform=base; [CATransaction flush]; [L removeAllAnimations];
  pm("base",base);
  probe(@"rot.z 0->1 @.5",@"transform.rotation.z",@0,@1,.5,NO);
  probe(@"rot.z additive 0->1 @.5",@"transform.rotation.z",@0,@1,.5,YES);
  probe(@"rot (alias) 0->1 @.5",@"transform.rotation",@0,@1,.5,NO);
  probe(@"scale 1->2 @.5",@"transform.scale",@1,@2,.5,NO);
  probe(@"scale.x 1->2 @.5",@"transform.scale.x",@1,@2,.5,NO);
  probe(@"translation.x 0->50 @.5",@"transform.translation.x",@0,@50,.5,NO);
  probe(@"translation 0->(50,60) @.5",@"transform.translation",[NSValue valueWithSize:NSMakeSize(0,0)],[NSValue valueWithSize:NSMakeSize(50,60)],.5,NO);
  probe(@"rotation.x 0->1 @.5",@"transform.rotation.x",@0,@1,.5,NO);
  L.transform=CATransform3DIdentity; [CATransaction flush]; [L removeAllAnimations];
  probe(@"id: rot.z 0->1 @.5",@"transform.rotation.z",@0,@1,.5,NO);
  probe(@"id: scale 1->2 @.5",@"transform.scale",@1,@2,.5,NO);
  CATransform3D r=CATransform3DMakeRotation(1.0,0,0,1); L.transform=r; [CATransaction flush]; [L removeAllAnimations];
  probe(@"rot=1: scale 1->2 @.5",@"transform.scale",@1,@2,.5,NO);
  probe(@"rot=1: scale 1->2 @.5 additive",@"transform.scale",@1,@2,.5,YES);
  probe(@"rot=1: translation.x 0->50 @.5 additive",@"transform.translation.x",@0,@50,.5,YES);
  printf("kvc layer: transform.rotation.z of rot=1: %s\n",[[[L valueForKeyPath:@"transform.rotation.z"] description] UTF8String]);
  printf("kvc layer: transform.scale of base: "); L.transform=base; printf("%s %s %s\n",[[[L valueForKeyPath:@"transform.scale"] description] UTF8String],[[[L valueForKeyPath:@"transform.scale.x"] description] UTF8String],[[[L valueForKeyPath:@"transform.scale.y"] description] UTF8String]);
  printf("rotation.z of base: %s translation.x: %s translation: %s\n",[[[L valueForKeyPath:@"transform.rotation.z"] description] UTF8String],[[[L valueForKeyPath:@"transform.translation.x"] description] UTF8String],[[[L valueForKeyPath:@"transform.translation"] description] UTF8String]);
  [L setValue:@2 forKeyPath:@"transform.rotation.z"]; pm("set rot.z=2 on base",L.transform);
  [L setValue:@3 forKeyPath:@"transform.scale"]; pm("then scale=3",L.transform);
  [L setValue:@5 forKeyPath:@"transform.translation.x"]; pm("then tx=5",L.transform);
}return 0;}
