/*
 * NSColorSampler.m — behavioral-1:1 core. See NSColorSampler.h.
 */

#import "NSColorSampler.h"

@implementation NSColorSampler {
    NSMutableArray *_completionHandlers;   /* of void(^)(NSColor*) */
}

- (instancetype)init
{
    self = [super init];
    if (self) _completionHandlers = [NSMutableArray array];
    return self;
}

- (void)showSamplerWithSelectionHandler:(void (^)(NSColor *))selectionHandler
{
    if (selectionHandler) [_completionHandlers addObject:[selectionHandler copy]];
    /* TODO(stage2): open the screen magnifier via the ColorSampler XPC service;
     * -selectedColor: will be called back with the picked colour. */
}

/* ColorSamplerClientProtocol callback: deliver the picked colour (nil if the
 * sampler was cancelled) to every queued handler, then clear the queue. */
- (void)selectedColor:(NSColor *)color
{
    NSArray *handlers = [_completionHandlers copy];
    [_completionHandlers removeAllObjects];
    for (void (^h)(NSColor *) in handlers) h(color);
}

@end
