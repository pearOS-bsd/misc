#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
static CARenderer *R;
static CALayer *L;
static void setup(void){
  id<MTLDevice> dev=MTLCreateSystemDefaultDevice(); 
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:100 height:100 mipmapped:NO]; td.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
  R=[CARenderer rendererWithMTLTexture:[dev newTextureWithDescriptor:td] options:nil];
  L=[CALayer layer]; L.frame=CGRectMake(0,0,100,100); R.layer=L; R.bounds=CGRectMake(0,0,100,100);
  [CATransaction flush];
}
int main(void){ @autoreleasepool { setup();
  for(double t=0;t<=1.0001;t+=0.125){
    CABasicAnimation *a=[CABasicAnimation animationWithKeyPath:@"opacity"]; a.fromValue=@0; a.toValue=@1; a.duration=1;
    a.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    a.fillMode=kCAFillModeBoth; a.speed=0; a.timeOffset=t; a.removedOnCompletion=NO;
    [L removeAllAnimations]; [L addAnimation:a forKey:@"a"]; [CATransaction flush];
    printf("t=%g op=%.9g\n",t,[[L presentationLayer] opacity]);
  }
}return 0;}
