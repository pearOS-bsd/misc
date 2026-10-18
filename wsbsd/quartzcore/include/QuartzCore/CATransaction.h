/* <QuartzCore/CATransaction.h>: groups layer changes; implicit animations take their duration, timing function and completion from the innermost transaction. */
#ifndef WSBSD_CATRANSACTION_H
#define WSBSD_CATRANSACTION_H
#import <QuartzCore/CABase.h>
#import <Foundation/Foundation.h>
@class CAMediaTimingFunction;

@interface CATransaction : NSObject
+ (void)begin;
+ (void)commit;
+ (void)flush;
+ (void)lock;
+ (void)unlock;
+ (CFTimeInterval)animationDuration;
+ (void)setAnimationDuration:(CFTimeInterval)dur;
+ (CAMediaTimingFunction *)animationTimingFunction;
+ (void)setAnimationTimingFunction:(CAMediaTimingFunction *)function;
+ (BOOL)disableActions;
+ (void)setDisableActions:(BOOL)flag;
+ (void (^)(void))completionBlock;
+ (void)setCompletionBlock:(void (^)(void))block;
+ (id)valueForKey:(NSString *)key;
+ (void)setValue:(id)anObject forKey:(NSString *)key;
@end

CA_EXTERN NSString *const kCATransactionAnimationDuration;
CA_EXTERN NSString *const kCATransactionDisableActions;
CA_EXTERN NSString *const kCATransactionAnimationTimingFunction;
CA_EXTERN NSString *const kCATransactionCompletionBlock;
#endif
