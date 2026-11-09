/*
 * NSScreen.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSScreen : NSObject <_NSDisplayLinkInfoProvider,
 *                                   _NSDisplayLinkCreatingWithOptions> {
 *       _state;                       // single opaque ivar
 *   }
 *   @property (Tq,N,R) _screenNumber;         // NSInteger
 *   @property (Ti,N,R) _displayID;            // CGDirectDisplayID (int)
 *   @property (Ti,N,R) depth;                 // NSWindowDepth (int)
 *   @property (T@"NSColorSpace",N,R) colorSpace;
 *   @property (T{CGRect=…},N,R) frame;
 *   @property (Td,N,R) backingScaleFactor;    // double
 *   @property (T{CGRect=…},N,R) visibleFrame;
 *   @property (T{NSEdgeInsets=dddd},N,R) safeAreaInsets;
 *   @property (T@"NSDictionary",N,R) deviceDescription;
 *   @property (T@"NSString",N,R) localizedName;
 *   @property (Tq,N,R) maximumFramesPerSecond; // NSInteger
 *   class: +screens +mainScreen(stage2) +deepestScreen +_fallbackBackingScaleFactor
 *          +_setFallbackBackingScaleFactor: +_screenForScreenNumber:
 *
 * The real NSScreen stores everything behind the single opaque `_state` ivar,
 * a CoreGraphics display-state handle populated from the window server
 * (CGSCopyDisplayList / CGDisplay*). Enumerating real displays is stage2
 * (window-server dependent). This core models an in-process screen table that
 * the window-server glue fills at stage2, with a synthesised fallback screen so
 * that -backingScaleFactor / -frame and the backing-coordinate conversions —
 * which are pure arithmetic — are exact and testable now.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSColorSpace;

@interface NSScreen : NSObject

@property (class, readonly, copy) NSArray<NSScreen *> *screens;
@property (class, readonly, nullable, strong) NSScreen *mainScreen;
@property (class, readonly, nullable, strong) NSScreen *deepestScreen;

@property (readonly) CGRect frame;
@property (readonly) CGRect visibleFrame;
@property (readonly) CGFloat backingScaleFactor;
@property (readonly) NSInteger depth;
@property (readonly) NSInteger maximumFramesPerSecond;
@property (readonly, copy) NSString *localizedName;
@property (readonly, copy) NSDictionary<NSString *, id> *deviceDescription;
@property (readonly) NSEdgeInsets safeAreaInsets;

/* Pure arithmetic over the backing scale factor (no window server). */
- (CGRect)convertRectToBacking:(CGRect)rect;
- (CGRect)convertRectFromBacking:(CGRect)rect;
- (CGRect)backingAlignedRect:(CGRect)rect options:(NSAlignmentOptions)options;

/* Fallback backing scale factor (evidence: +_fallbackBackingScaleFactor /
 * +_setFallbackBackingScaleFactor:). Used to synthesise a screen when the
 * window-server list is empty. */
@property (class) CGFloat _fallbackBackingScaleFactor;

/* Window-server glue (stage2) installs the real screen table through this. */
+ (void)_setScreens:(nullable NSArray<NSScreen *> *)screens;
+ (nullable NSScreen *)_screenForScreenNumber:(NSInteger)screenNumber;

/* Designated internal initialiser the window-server glue calls per display. */
- (instancetype)_initWithScreenNumber:(NSInteger)screenNumber
                                frame:(CGRect)frame
                         visibleFrame:(CGRect)visibleFrame
                   backingScaleFactor:(CGFloat)scale
                                depth:(NSInteger)depth;

@property (readonly) NSInteger _screenNumber;

@end

NS_ASSUME_NONNULL_END
