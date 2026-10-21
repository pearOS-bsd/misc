/* libdispatch's main queue on the GNUstep run loop. gnustep-base is built without the hook that drains the main queue and the queue's wake-up handle of this libdispatch never signals, so blocks given to
 * dispatch_async(dispatch_get_main_queue(), ...) never ran (TextMate's document loading ends in one). A timer of the main run loop, in the modes of the application, drains the queue. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <unistd.h>

extern void _dispatch_main_queue_callback_4CF(void *msg);

@interface WsbsdMainQueueDrain : NSObject
+ (void)drain:(NSTimer *)timer;
+ (void)install;
@end
@implementation WsbsdMainQueueDrain
+ (void)drain:(NSTimer *)timer { _dispatch_main_queue_callback_4CF(NULL); }
+ (void)install
{
	NSRunLoop *loop = [NSRunLoop mainRunLoop];
	for (NSString *mode in @[ NSDefaultRunLoopMode, @"NSModalPanelRunLoopMode", @"NSEventTrackingRunLoopMode", @"NSConnectionReplyMode" ]) {
		NSTimer *t = [NSTimer timerWithTimeInterval: 0.004 target: self selector: @selector(drain:) userInfo: nil repeats: YES];
		[loop addTimer: t forMode: mode];
	}
}
@end

static void *Install(void *arg)
{
	for (;;) { Class c = objc_getClass("NSArray"); if (c && class_respondsToSelector(object_getClass(c), @selector(arrayWithObjects:count:)) && objc_getClass("NSRunLoop")) break; usleep(10000); }   /* started from a constructor: wait for Foundation */
	usleep(20000);
	@autoreleasepool { [WsbsdMainQueueDrain performSelectorOnMainThread: @selector(install) withObject: nil waitUntilDone: NO]; }
	return NULL;
}

__attribute__((constructor(120))) static void WsbsdMainQueueInit(void)
{
	if (getenv("WSBSD_NO_MAINQUEUE")) return;
	pthread_t t; pthread_attr_t a; pthread_attr_init(&a); pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
	pthread_create(&t, &a, Install, NULL);
}

/* gnustep-corebase queues the block and nothing runs it. TextMate hands the replies of its file and cache servers to the main run loop this way. The block runs through the main queue, which the timer above drains. */
void CFRunLoopPerformBlock(CFRunLoopRef rl, CFTypeRef mode, void (^block)(void))
{
	(void)rl; (void)mode;
	if (block) dispatch_async(dispatch_get_main_queue(), block);
}
