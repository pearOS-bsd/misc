/*
 * NSAnimationContext.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSAnimationContext : NSObject
 *   @property (Td) duration;  (T@?,C) completionHandler;  (TB) allowsImplicitAnimation;
 *   @property (T@"CAMediaTimingFunction",&) timingFunction;
 *   +currentContext +beginGrouping +endGrouping +runAnimationGroup:
 *   +runAnimationGroup:completionHandler:
 *
 * A per-thread stack of animation contexts. beginGrouping pushes a fresh context
 * (inheriting the previous duration), endGrouping pops it and fires its
 * completion handler. runAnimationGroup: wraps a begin/change/end. The actual
 * Core Animation driving of implicit animations is stage2; the grouping,
 * duration and completion-handler plumbing here is exact.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAnimationContext : NSObject

@property (class, readonly, strong) NSAnimationContext *currentContext;
+ (void)beginGrouping;
+ (void)endGrouping;
+ (void)runAnimationGroup:(void (NS_NOESCAPE ^)(NSAnimationContext *context))changes;
+ (void)runAnimationGroup:(void (NS_NOESCAPE ^)(NSAnimationContext *context))changes
        completionHandler:(nullable void (^)(void))completionHandler;

@property NSTimeInterval duration;
@property (nullable, copy) void (^completionHandler)(void);
@property BOOL allowsImplicitAnimation;

@end

NS_ASSUME_NONNULL_END
