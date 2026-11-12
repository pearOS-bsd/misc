/*
 * NSCustomImageRep.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCustomImageRep, an NSImageRep that draws via a block (or a legacy
 * delegate+selector).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCustomImageRep_interface.txt. Real ivars: _drawMethod (SEL),
 * _drawObject (delegate), plus the drawing block and a flipped flag.
 *
 * This core reproduces the two construction paths and the -draw dispatch:
 * the modern initWithSize:flipped:drawingHandler: stores the block and invokes
 * it with the dest rect; the legacy initWithDrawSelector:delegate:[flipped:]
 * performs the selector on the delegate. drawingHandler/drawSelector/delegate
 * are readonly, flipped is observable. Measured: the real -init is unavailable;
 * the block path leaves drawSelector=nil/delegate=nil. The actual pixel output
 * and image caching are TODO(stage2); -draw returns the block's BOOL so the
 * dispatch is testable headlessly.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSImageRep.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^NSCustomImageRepDrawingHandler)(CGRect dstRect);

@interface NSCustomImageRep : NSImageRep

- (instancetype)initWithSize:(CGSize)size
                     flipped:(BOOL)drawingHandlerShouldBeCalledInThisCoordinateSystem
              drawingHandler:(NSCustomImageRepDrawingHandler)drawingHandler;

- (instancetype)initWithDrawSelector:(SEL)drawSelector delegate:(id)delegate;

@property (readonly, copy, nullable) NSCustomImageRepDrawingHandler drawingHandler;
@property (readonly, nullable) SEL drawSelector;
@property (readonly, weak, nullable) id delegate;
@property (getter=isFlipped) BOOL flipped;

/* dispatches the handler/selector; returns the handler's BOOL (YES if none). */
- (BOOL)draw;

@end

NS_ASSUME_NONNULL_END
