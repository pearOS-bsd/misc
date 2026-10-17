/* <QuartzCore/QuartzCore.h>: Core Animation names applications reference; layers are not rendered by this stack (view-backed drawing only), animations are accepted and finish at once. */
#ifndef WSBSD_QUARTZCORE_H
#define WSBSD_QUARTZCORE_H
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
@interface CAAnimation : NSObject <NSCopying>
@property (nonatomic) CFTimeInterval duration;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, strong) id timingFunction;
@property (nonatomic, weak) id delegate;
@property (nonatomic, getter=isRemovedOnCompletion) BOOL removedOnCompletion;
+ (instancetype)animation;
@end
@interface CAPropertyAnimation : CAAnimation
+ (instancetype)animationWithKeyPath:(NSString *)path;
@end
@interface CABasicAnimation : CAPropertyAnimation
@property (nonatomic, strong) id fromValue, toValue, byValue;
@end
@interface CAMediaTimingFunction : NSObject
+ (instancetype)functionWithName:(NSString *)name;
@end
extern NSString *const kCAMediaTimingFunctionLinear, *const kCAMediaTimingFunctionEaseIn, *const kCAMediaTimingFunctionEaseOut, *const kCAMediaTimingFunctionEaseInEaseOut, *const kCAMediaTimingFunctionDefault;
@interface CATransaction : NSObject
+ (void)begin; + (void)commit; + (void)setDisableActions:(BOOL)flag; + (void)setAnimationDuration:(CFTimeInterval)d; + (void)setCompletionBlock:(void (^)(void))block;
@end
#endif
