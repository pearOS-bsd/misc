/* <QuartzCore/CAAnimation.h>: animation objects; they are applied to the presentation layer at the time the layer is drawn. */
#ifndef WSBSD_CAANIMATION_H
#define WSBSD_CAANIMATION_H
#import <QuartzCore/CALayer.h>
@class CAMediaTimingFunction, CAValueFunction;
@protocol CAAnimationDelegate;

typedef NSString *CAAnimationCalculationMode NS_TYPED_ENUM;
typedef NSString *CAAnimationRotationMode NS_TYPED_ENUM;
typedef NSString *CATransitionType NS_TYPED_ENUM;
typedef NSString *CATransitionSubtype NS_TYPED_ENUM;

@interface CAAnimation : NSObject <NSSecureCoding, NSCopying, CAMediaTiming, CAAction>
{
@private
	void *_attr;
	uint32_t _flags;
}
+ (instancetype)animation;
+ (id)defaultValueForKey:(NSString *)key;
- (BOOL)shouldArchiveValueForKey:(NSString *)key;
@property(strong) CAMediaTimingFunction *timingFunction;
@property(strong) id<CAAnimationDelegate> delegate;
@property(getter=isRemovedOnCompletion) BOOL removedOnCompletion;
@end

@protocol CAAnimationDelegate <NSObject>
@optional
- (void)animationDidStart:(CAAnimation *)anim;
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag;
@end

@interface CAPropertyAnimation : CAAnimation
+ (instancetype)animationWithKeyPath:(NSString *)path;
@property(copy) NSString *keyPath;
@property(getter=isAdditive) BOOL additive;
@property(getter=isCumulative) BOOL cumulative;
@property(strong) CAValueFunction *valueFunction;
@end

@interface CABasicAnimation : CAPropertyAnimation
@property(strong) id fromValue;
@property(strong) id toValue;
@property(strong) id byValue;
@end

@interface CAKeyframeAnimation : CAPropertyAnimation
@property(copy) NSArray *values;
@property CGPathRef path;
@property(copy) NSArray<NSNumber *> *keyTimes;
@property(copy) NSArray<CAMediaTimingFunction *> *timingFunctions;
@property(copy) CAAnimationCalculationMode calculationMode;
@property(copy) NSArray<NSNumber *> *tensionValues;
@property(copy) NSArray<NSNumber *> *continuityValues;
@property(copy) NSArray<NSNumber *> *biasValues;
@property(copy) CAAnimationRotationMode rotationMode;
@end

CA_EXTERN CAAnimationCalculationMode const kCAAnimationLinear;
CA_EXTERN CAAnimationCalculationMode const kCAAnimationDiscrete;
CA_EXTERN CAAnimationCalculationMode const kCAAnimationPaced;
CA_EXTERN CAAnimationCalculationMode const kCAAnimationCubic;
CA_EXTERN CAAnimationCalculationMode const kCAAnimationCubicPaced;
CA_EXTERN CAAnimationRotationMode const kCAAnimationRotateAuto;
CA_EXTERN CAAnimationRotationMode const kCAAnimationRotateAutoReverse;

@interface CASpringAnimation : CABasicAnimation
@property CGFloat mass;
@property CGFloat stiffness;
@property CGFloat damping;
@property CGFloat initialVelocity;
@property BOOL allowsOverdamping;
@property(readonly) CFTimeInterval settlingDuration;
- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce;
@property(readonly) CFTimeInterval perceptualDuration;
@property(readonly) CGFloat bounce;
@end

@interface CATransition : CAAnimation
@property(copy) CATransitionType type;
@property(copy) CATransitionSubtype subtype;
@property float startProgress;
@property float endProgress;
@property(strong) id filter;
@end

CA_EXTERN CATransitionType const kCATransitionFade;
CA_EXTERN CATransitionType const kCATransitionMoveIn;
CA_EXTERN CATransitionType const kCATransitionPush;
CA_EXTERN CATransitionType const kCATransitionReveal;
CA_EXTERN CATransitionSubtype const kCATransitionFromRight;
CA_EXTERN CATransitionSubtype const kCATransitionFromLeft;
CA_EXTERN CATransitionSubtype const kCATransitionFromTop;
CA_EXTERN CATransitionSubtype const kCATransitionFromBottom;

@interface CAAnimationGroup : CAAnimation
@property(copy) NSArray<CAAnimation *> *animations;
@end
#endif
