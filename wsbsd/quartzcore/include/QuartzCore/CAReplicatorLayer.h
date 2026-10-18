/* <QuartzCore/CAReplicatorLayer.h> */
#ifndef WSBSD_CAREPLICATORLAYER_H
#define WSBSD_CAREPLICATORLAYER_H
#import <QuartzCore/CALayer.h>
@interface CAReplicatorLayer : CALayer
@property NSInteger instanceCount;
@property BOOL preservesDepth;
@property CFTimeInterval instanceDelay;
@property CATransform3D instanceTransform;
@property CGColorRef instanceColor;
@property float instanceRedOffset;
@property float instanceGreenOffset;
@property float instanceBlueOffset;
@property float instanceAlphaOffset;
@end
#endif
