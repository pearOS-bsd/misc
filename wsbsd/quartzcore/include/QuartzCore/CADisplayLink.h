/* <QuartzCore/CADisplayLink.h>: calls the target once per display refresh (a timer on the run loop paced by the display). */
#ifndef WSBSD_CADISPLAYLINK_H
#define WSBSD_CADISPLAYLINK_H
#import <QuartzCore/CABase.h>
#import <QuartzCore/CAFrameRateRange.h>
#import <Foundation/Foundation.h>
@interface CADisplayLink : NSObject
{
@private
	void *_impl;
}
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel;
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode;
- (void)removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode;
- (void)invalidate;
@property(readonly, nonatomic) CFTimeInterval timestamp;
@property(readonly, nonatomic) CFTimeInterval duration;
@property(readonly, nonatomic) CFTimeInterval targetTimestamp;
@property(getter=isPaused, nonatomic) BOOL paused;
@property(nonatomic) NSInteger frameInterval;
@property(nonatomic) NSInteger preferredFramesPerSecond;
@property(nonatomic) CAFrameRateRange preferredFrameRateRange;
@end
#endif
