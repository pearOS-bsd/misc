#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
static void savePNG(const char *path, const uint8_t *bgra, int w, int h, int stride)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate((void *)bgra, w, h, 8, stride, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGImageRef img = CGBitmapContextCreateImage(c);
	CGImageDestinationRef d = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:[NSString stringWithUTF8String:path]], (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
	CGImageDestinationAddImage(d, img, NULL); CGImageDestinationFinalize(d);
}
int main(void){ @autoreleasepool {
  int W=400,H=300;
  id<MTLDevice> dev=MTLCreateSystemDefaultDevice(); id<MTLCommandQueue> q=[dev newCommandQueue];
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:W height:H mipmapped:NO]; td.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead; td.storageMode=MTLStorageModeShared;
  id<MTLTexture> tex=[dev newTextureWithDescriptor:td];
  CARenderer *R=[CARenderer rendererWithMTLTexture:tex options:@{kCARendererMetalCommandQueue:q}];
  CALayer *root=[CALayer layer]; root.frame=CGRectMake(0,0,W,H); root.backgroundColor=CGColorCreateGenericRGB(0.2,0.2,0.2,1);
  CALayer *a=[CALayer layer]; a.frame=CGRectMake(50,50,120,80); a.backgroundColor=CGColorCreateGenericRGB(1,0,0,1); a.cornerRadius=20; a.borderWidth=4; a.borderColor=CGColorCreateGenericRGB(1,1,1,1);
  a.shadowOpacity=0.6; a.shadowRadius=10; a.shadowOffset=CGSizeMake(0,-8);
  [root addSublayer:a];
  R.layer=root; R.bounds=CGRectMake(0,0,W,H); [CATransaction flush];
  [R beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL]; [R addUpdateRect:R.bounds]; [R render]; [R endFrame];
  id<MTLCommandBuffer> cb=[q commandBuffer]; [cb commit]; [cb waitUntilCompleted];
  uint8_t *buf=malloc(W*H*4); [tex getBytes:buf bytesPerRow:W*4 fromRegion:MTLRegionMake2D(0,0,W,H) mipmapLevel:0];
  savePNG("/tmp/r1.png",buf,W,H,W*4);
  printf("pixel(60,300-60)= %d %d %d %d\n",buf[((300-60)*W+60)*4+2],buf[((300-60)*W+60)*4+1],buf[((300-60)*W+60)*4],buf[((300-60)*W+60)*4+3]);
}return 0;}
