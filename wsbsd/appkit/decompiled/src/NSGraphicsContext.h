/*
 * NSGraphicsContext.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSGraphicsContext : NSObject
 *   @property (TB) shouldAntialias;  (TQ) imageInterpolation;
 *   @property (T{CGPoint}) patternPhase;  (TQ) compositingOperation;
 *   @property (T^{CGContext},R) CGContext;  (TB,R,GisFlipped) flipped;
 *   +currentContext +setCurrentContext: +saveGraphicsState +restoreGraphicsState
 *   +graphicsContextWithCGContext:flipped:
 *
 * Wraps a CGContextRef plus the flipped flag and the drawing-state knobs. The
 * current context is thread-local; save/restoreGraphicsState push/pop the CG
 * graphics state. Pattern phase / compositing / CIContext application to the
 * backing CGContext is stage2; the context/state plumbing here is exact.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSGraphicsContext : NSObject

+ (nullable NSGraphicsContext *)graphicsContextWithCGContext:(CGContextRef)graphicsPort flipped:(BOOL)initialFlippedState;

@property (class, nullable, strong) NSGraphicsContext *currentContext;
+ (void)saveGraphicsState;
+ (void)restoreGraphicsState;
+ (BOOL)currentContextDrawingToScreen;

- (void)saveGraphicsState;
- (void)restoreGraphicsState;

@property (readonly) CGContextRef CGContext;
@property (readonly, getter=isFlipped) BOOL flipped;
@property BOOL shouldAntialias;
@property NSInteger imageInterpolation;
@property CGPoint patternPhase;
@property NSUInteger compositingOperation;

@end

NS_ASSUME_NONNULL_END
