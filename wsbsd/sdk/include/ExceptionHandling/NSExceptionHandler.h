/* NSExceptionHandler: reports uncaught exceptions to a delegate (and the log) according to the mask. Implemented in sdk/src/SystemFrameworks.m */
#ifndef WSBSD_NSEXCEPTIONHANDLER_H
#define WSBSD_NSEXCEPTIONHANDLER_H
#import <Foundation/Foundation.h>
enum {
	NSLogUncaughtExceptionMask = 1 << 0, NSHandleUncaughtExceptionMask = 1 << 1,
	NSLogUncaughtSystemExceptionMask = 1 << 2, NSHandleUncaughtSystemExceptionMask = 1 << 3,
	NSLogUncaughtRuntimeErrorMask = 1 << 4, NSHandleUncaughtRuntimeErrorMask = 1 << 5,
	NSLogTopLevelExceptionMask = 1 << 6, NSHandleTopLevelExceptionMask = 1 << 7,
	NSLogOtherExceptionMask = 1 << 8, NSHandleOtherExceptionMask = 1 << 9
};
#define NSLogAndHandleEveryExceptionMask (NSLogUncaughtExceptionMask | NSHandleUncaughtExceptionMask | NSLogUncaughtSystemExceptionMask | NSHandleUncaughtSystemExceptionMask | NSLogUncaughtRuntimeErrorMask | NSHandleUncaughtRuntimeErrorMask | NSLogTopLevelExceptionMask | NSHandleTopLevelExceptionMask | NSLogOtherExceptionMask | NSHandleOtherExceptionMask)
extern NSString *const NSUncaughtSystemExceptionException;
extern NSString *const NSUncaughtRuntimeErrorException;
extern NSString *const NSStackTraceKey;
@class NSExceptionHandler;
@interface NSObject (NSExceptionHandlerDelegate)
- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(NSUInteger)aMask;
- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(NSUInteger)aMask;
@end
@interface NSExceptionHandler : NSObject
+ (NSExceptionHandler *)defaultExceptionHandler;
- (void)setExceptionHandlingMask:(NSUInteger)aMask;
- (NSUInteger)exceptionHandlingMask;
- (void)setExceptionHangingMask:(NSUInteger)aMask;
- (NSUInteger)exceptionHangingMask;
- (void)setDelegate:(id)delegate;
- (id)delegate;
@end
#endif
