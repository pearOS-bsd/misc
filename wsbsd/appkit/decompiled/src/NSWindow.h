/*
 * NSWindow.h — 1:1 reimplementation of AppKit's NSWindow (data + responder core).
 *
 * Shape from ../reference/NSWindow.h; logic from ../evidence/window. NSWindow is
 * heavily coupled to the window server (SkyLight/wsd); this pass covers the parts
 * that are pure object state and the first-responder machinery:
 *   title, styleMask, contentView, delegate (weak), isVisible, order in/out,
 *   firstResponder / makeFirstResponder:.
 * Staged (need the server / NSApp): real ordering & display, isKeyWindow /
 * isMainWindow, the border-view hierarchy, auxiliary-storage title path.
 */
#import "NSResponder.h"
#import "NSView.h"
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSWindowStyleMask) {
    NSWindowStyleMaskBorderless     = 0,
    NSWindowStyleMaskTitled         = 1 << 0,
    NSWindowStyleMaskClosable       = 1 << 1,
    NSWindowStyleMaskMiniaturizable = 1 << 2,
    NSWindowStyleMaskResizable      = 1 << 3,
};

typedef NS_ENUM(NSUInteger, NSBackingStoreType) {
    NSBackingStoreRetained    = 0,
    NSBackingStoreNonretained = 1,
    NSBackingStoreBuffered    = 2,
};

@interface NSWindow : NSResponder

- (instancetype)initWithContentRect:(CGRect)contentRect
                          styleMask:(NSWindowStyleMask)style
                            backing:(NSBackingStoreType)backingStoreType
                              defer:(BOOL)flag;

@property (copy) NSString *title;
@property NSWindowStyleMask styleMask;
@property (nullable, strong) NSView *contentView;
@property (nullable, weak) id delegate;
@property (readonly, getter=isVisible) BOOL visible;
@property (nullable, readonly, weak) NSResponder *firstResponder;

- (BOOL)makeFirstResponder:(nullable NSResponder *)responder;
- (void)makeKeyAndOrderFront:(nullable id)sender;
- (void)orderOut:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
