/* <QuartzCore/CAScrollLayer.h> */
#ifndef WSBSD_CASCROLLLAYER_H
#define WSBSD_CASCROLLLAYER_H
#import <QuartzCore/CALayer.h>
typedef NSString *CAScrollLayerScrollMode NS_TYPED_ENUM;
@interface CAScrollLayer : CALayer
- (void)scrollToPoint:(CGPoint)p;
- (void)scrollToRect:(CGRect)r;
@property(copy) CAScrollLayerScrollMode scrollMode;
@end
@interface CALayer (CALayerScrolling)
- (void)scrollPoint:(CGPoint)p;
- (void)scrollRectToVisible:(CGRect)r;
@property(readonly) CGRect visibleRect;
@end
CA_EXTERN CAScrollLayerScrollMode const kCAScrollNone;
CA_EXTERN CAScrollLayerScrollMode const kCAScrollVertically;
CA_EXTERN CAScrollLayerScrollMode const kCAScrollHorizontally;
CA_EXTERN CAScrollLayerScrollMode const kCAScrollBoth;
#endif
