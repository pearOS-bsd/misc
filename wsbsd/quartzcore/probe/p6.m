#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
static CARenderer *R; static CALayer *L;
static void setup(void){
  id<MTLDevice> dev=MTLCreateSystemDefaultDevice();
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:100 height:100 mipmapped:NO]; td.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
  R=[CARenderer rendererWithMTLTexture:[dev newTextureWithDescriptor:td] options:nil];
  L=[CALayer layer]; L.frame=CGRectMake(10,20,100,50); R.layer=L; R.bounds=CGRectMake(0,0,400,300); [CATransaction flush];
}
int main(void){ @autoreleasepool { setup();
  printf("layer defaults: duration=%g speed=%g begin=%g offset=%g repeat=%g fill=%s\n",L.duration,L.speed,L.beginTime,L.timeOffset,L.repeatCount,[L.fillMode UTF8String]);
  CABasicAnimation *a=[CABasicAnimation animationWithKeyPath:@"opacity"]; a.fromValue=@0; a.toValue=@1; a.duration=1; a.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]; a.removedOnCompletion=NO; a.fillMode=kCAFillModeBoth;
  double t0=CACurrentMediaTime();
  [L addAnimation:a forKey:@"a"]; 
  CAAnimation *g=[L animationForKey:@"a"]; printf("stored copy: begin=%g (media time now %.3f) \n",g.beginTime,t0);
  for(int i=0;i<6;i++){ [CATransaction flush]; printf("t+%.3f opacity=%.4f layerTime=%.3f\n",CACurrentMediaTime()-t0,[[L presentationLayer] opacity],[L convertTime:CACurrentMediaTime() fromLayer:nil]-t0); usleep(250000); }
  [L removeAllAnimations];
  /* explicit absolute begin 0.5 s in the future */
  a.beginTime=CACurrentMediaTime()+0.5; t0=CACurrentMediaTime(); [L addAnimation:a forKey:@"b"]; printf("begin set %.3f (+%.3f)\n",a.beginTime,a.beginTime-t0);
  for(int i=0;i<6;i++){ [CATransaction flush]; printf("t+%.3f opacity=%.4f\n",CACurrentMediaTime()-t0,[[L presentationLayer] opacity]); usleep(250000); }
  [L removeAllAnimations];
  /* two reads within the same transaction have the same time? */
  [L addAnimation:a forKey:@"c"]; a.beginTime=0;[L addAnimation:a forKey:@"c"]; [CATransaction begin]; double x1=[[L presentationLayer] opacity]; usleep(200000); double x2=[[L presentationLayer] opacity]; [CATransaction commit]; printf("same txn reads: %.6f %.6f\n",x1,x2);
  double y1=[[L presentationLayer] opacity]; usleep(200000); double y2=[[L presentationLayer] opacity]; printf("implicit txn reads: %.6f %.6f\n",y1,y2);
  [CATransaction flush]; double y3=[[L presentationLayer] opacity]; printf("after flush: %.6f\n",y3);
}return 0;}
