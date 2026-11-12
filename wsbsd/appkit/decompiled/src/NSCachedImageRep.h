/*
 * NSCachedImageRep.h — 1:1 reimplementation (behavioral core) of AppKit's
 * (deprecated) NSCachedImageRep, an NSImageRep backed by an offscreen window.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCachedImageRep_interface.txt.
 *
 * NSCachedImageRep is an NSImageRep (measured). This core reproduces the two
 * initialisers and the size/rect geometry (rect = {0,0,size} — measured). The
 * offscreen backing window is window-server state (TODO(stage2)): -window
 * returns the window passed to initWithWindow:rect:, else nil.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSImageRep.h"

NS_ASSUME_NONNULL_BEGIN

@class NSWindow;

@interface NSCachedImageRep : NSImageRep

- (instancetype)initWithSize:(CGSize)size depth:(NSInteger)depth separate:(BOOL)flag alpha:(BOOL)alpha;
- (instancetype)initWithWindow:(nullable NSWindow *)win rect:(CGRect)rect;

@property (readonly, nullable, strong) NSWindow *window;
@property (readonly) CGRect rect;

@end

NS_ASSUME_NONNULL_END
