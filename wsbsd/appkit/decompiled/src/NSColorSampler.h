/*
 * NSColorSampler.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSColorSampler, the screen color magnifier.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSColorSampler_interface.txt. Real ivars: _xpcConnection,
 * _completionHandlers.
 *
 * showSamplerWithSelectionHandler: queues a handler and opens the magnifier over
 * an NSXPCConnection; -selectedColor: (the ColorSamplerClientProtocol callback)
 * fires the queued handlers with the picked colour (nil if cancelled). The
 * magnifier UI + XPC are TODO(stage2); the handler queue/dispatch is here.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSColor;

@interface NSColorSampler : NSObject

- (void)showSamplerWithSelectionHandler:(void (^)(NSColor * _Nullable selectedColor))selectionHandler;

@end

NS_ASSUME_NONNULL_END
