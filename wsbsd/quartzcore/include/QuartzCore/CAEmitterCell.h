/* <QuartzCore/CAEmitterCell.h> */
#ifndef WSBSD_CAEMITTERCELL_H
#define WSBSD_CAEMITTERCELL_H
#import <QuartzCore/CAMediaTiming.h>
@interface CAEmitterCell : NSObject <NSSecureCoding, CAMediaTiming>
{
@private
	CGColorRef _color;
}
+ (instancetype)emitterCell;
+ (id)defaultValueForKey:(NSString *)key;
- (BOOL)shouldArchiveValueForKey:(NSString *)key;
@property(copy) NSString *name;
@property(getter=isEnabled) BOOL enabled;
@property float birthRate;
@property float lifetime;
@property float lifetimeRange;
@property CGFloat emissionLatitude;
@property CGFloat emissionLongitude;
@property CGFloat emissionRange;
@property CGFloat velocity;
@property CGFloat velocityRange;
@property CGFloat xAcceleration;
@property CGFloat yAcceleration;
@property CGFloat zAcceleration;
@property CGFloat scale;
@property CGFloat scaleRange;
@property CGFloat scaleSpeed;
@property CGFloat spin;
@property CGFloat spinRange;
@property(nonatomic) CGColorRef color;
@property float redRange;
@property float greenRange;
@property float blueRange;
@property float alphaRange;
@property float redSpeed;
@property float greenSpeed;
@property float blueSpeed;
@property float alphaSpeed;
@property(strong) id contents;
@property CGRect contentsRect;
@property CGFloat contentsScale;
@property(copy) NSString *minificationFilter;
@property(copy) NSString *magnificationFilter;
@property float minificationFilterBias;
@property(copy) NSArray<CAEmitterCell *> *emitterCells;
@property(copy) NSDictionary *style;
@end
#endif
