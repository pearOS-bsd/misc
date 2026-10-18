/* <QuartzCore/CAEmitterLayer.h> */
#ifndef WSBSD_CAEMITTERLAYER_H
#define WSBSD_CAEMITTERLAYER_H
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CAEmitterCell.h>
typedef NSString *CAEmitterLayerEmitterShape NS_TYPED_ENUM;
typedef NSString *CAEmitterLayerEmitterMode NS_TYPED_ENUM;
typedef NSString *CAEmitterLayerRenderMode NS_TYPED_ENUM;
@interface CAEmitterLayer : CALayer
@property(copy) NSArray<CAEmitterCell *> *emitterCells;
@property float birthRate;
@property float lifetime;
@property CGPoint emitterPosition;
@property CGFloat emitterZPosition;
@property CGSize emitterSize;
@property CGFloat emitterDepth;
@property(copy) CAEmitterLayerEmitterShape emitterShape;
@property(copy) CAEmitterLayerEmitterMode emitterMode;
@property(copy) CAEmitterLayerRenderMode renderMode;
@property BOOL preservesDepth;
@property float velocity;
@property float scale;
@property float spin;
@property unsigned int seed;
@end
CA_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerPoint;
CA_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerLine;
CA_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerRectangle;
CA_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerCuboid;
CA_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerCircle;
CA_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerSphere;
CA_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerPoints;
CA_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerOutline;
CA_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerSurface;
CA_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerVolume;
CA_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerUnordered;
CA_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerOldestFirst;
CA_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerOldestLast;
CA_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerBackToFront;
CA_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerAdditive;
#endif
