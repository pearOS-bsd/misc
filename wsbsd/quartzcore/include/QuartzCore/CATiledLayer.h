/* <QuartzCore/CATiledLayer.h> */
#ifndef WSBSD_CATILEDLAYER_H
#define WSBSD_CATILEDLAYER_H
#import <QuartzCore/CALayer.h>
@interface CATiledLayer : CALayer
+ (CFTimeInterval)fadeDuration;
@property size_t levelsOfDetail;
@property size_t levelsOfDetailBias;
@property CGSize tileSize;
@end
#endif
