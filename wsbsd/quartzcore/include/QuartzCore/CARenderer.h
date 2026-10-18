/* <QuartzCore/CARenderer.h>: renders a layer tree into a bitmap (this implementation draws with the software renderer into a CGBitmapContext-compatible buffer). */
#ifndef WSBSD_CARENDERER_H
#define WSBSD_CARENDERER_H
#import <QuartzCore/CALayer.h>
@interface CARenderer : NSObject
{
@private
	void *_priv;
}
/* the destination is a bitmap: BGRA, premultiplied, width x height pixels at `data` with `bytesPerRow` */
+ (CARenderer *)rendererWithBitmap:(void *)data width:(size_t)w height:(size_t)h bytesPerRow:(size_t)rowBytes options:(NSDictionary *)dict;
@property(strong) CALayer *layer;
@property CGRect bounds;
- (void)beginFrameAtTime:(CFTimeInterval)t timeStamp:(void *)ts;
- (CGRect)updateBounds;
- (void)addUpdateRect:(CGRect)r;
- (void)render;
- (CFTimeInterval)nextFrameTime;
- (void)endFrame;
@end
#endif
