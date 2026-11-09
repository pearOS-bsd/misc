/*
 * NSTrackingArea.h — 1:1 reimplementation (core). NSObject <NSCopying, NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTrackingArea : NSObject <NSCopying, NSCoding> {
 *       {CGRect} _rect;  @ _owner;  @"NSDictionary" _userInfo;  Q _options;
 *       {?="_installPending"b1 … "_installed"b1 "_enabled"b1 "_inside"b1 …} _privateFlags;
 *   }
 *   @property (T{CGRect},R) rect;  (TQ,R) options;  (T@,R,W) owner;
 *   @property (T@"NSDictionary",R,C) userInfo;
 *   -initWithRect:options:owner:userInfo:
 *
 * A value object describing a mouse-tracking region. owner is held weakly. The
 * install/enable private-flag lifecycle and the window-server hit testing are
 * stage2; the public value contract and the options validation are exact.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSTrackingAreaOptions) {
    NSTrackingMouseEnteredAndExited      = 0x01,
    NSTrackingMouseMoved                 = 0x02,
    NSTrackingCursorUpdate               = 0x04,
    NSTrackingActiveWhenFirstResponder   = 0x10,
    NSTrackingActiveInKeyWindow          = 0x20,
    NSTrackingActiveInActiveApp          = 0x40,
    NSTrackingActiveAlways               = 0x80,
    NSTrackingAssumeInside               = 0x100,
    NSTrackingInVisibleRect              = 0x200,
    NSTrackingEnabledDuringMouseDrag     = 0x400,
};

@interface NSTrackingArea : NSObject <NSCopying>

- (instancetype)initWithRect:(CGRect)rect
                     options:(NSTrackingAreaOptions)options
                       owner:(nullable id)owner
                    userInfo:(nullable NSDictionary *)userInfo;

@property (readonly) CGRect rect;
@property (readonly) NSTrackingAreaOptions options;
@property (readonly, weak) id owner;
@property (readonly, nullable, copy) NSDictionary *userInfo;

@end

NS_ASSUME_NONNULL_END
