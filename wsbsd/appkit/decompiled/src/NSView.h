/*
 * NSView.h — 1:1 reimplementation of AppKit's NSView (structural core).
 *
 * Class shape from the real AppKit.framework on macOS 27 (arm64e), read with
 * `ipsw dyld macho ... --objc` (../reference/NSView.h). Method logic transcribed
 * from the disassembly under ../evidence (NSView_*.txt); source addresses cited
 * in the .m. Not copied from Apple binaries.
 *
 * This first pass covers the structural core that is fully decoded: geometry
 * ivars and accessors (frame/bounds), the view hierarchy (superview/subviews/
 * window + add/remove), isFlipped, isDescendantOf:, and hitTest: geometry.
 *
 * Deliberately staged (call private helpers whose own decode is a later pass):
 *   - setFrame:/setFrameSize:/setFrameOrigin: layout-feedback loop debugger,
 *     layer geometry push (helpers @0x1880a5560/0x1880a55a0), os_unfair_lock on
 *     _vFlags, NSViewFrame/BoundsDidChangeNotification posting.
 *   - addSubview:/removeFromSuperview cursor-rect, constraint and layer wiring.
 *   - hitTest: exact _hitTestForContext:point:preferPointOverContext: path.
 * These are marked TODO(stage2) in the .m with the helper addresses.
 */
#import "NSResponder.h"
#import <CoreGraphics/CoreGraphics.h>

@class NSWindow, NSArray;

NS_ASSUME_NONNULL_BEGIN

@interface NSView : NSResponder

- (instancetype)initWithFrame:(CGRect)frameRect;

@property CGRect frame;
@property CGRect bounds;
@property (readonly) BOOL isFlipped;

@property (nullable, readonly, weak) NSView *superview;
@property (readonly, copy) NSArray<NSView *> *subviews;
@property (nullable, readonly, weak) NSWindow *window;

- (void)addSubview:(NSView *)view;
- (void)removeFromSuperview;
- (BOOL)isDescendantOf:(NSView *)view;

- (nullable NSView *)hitTest:(CGPoint)point;

- (void)viewWillMoveToWindow:(nullable NSWindow *)newWindow;
- (void)viewDidMoveToWindow;

@end

NS_ASSUME_NONNULL_END
