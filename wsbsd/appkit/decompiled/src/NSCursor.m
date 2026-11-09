/*
 * NSCursor.m — 1:1 (core). Evidence ../evidence/cursor:
 * image 0x18538ace8 ([self+0x20]), hotSpot 0x1851cdbfc ([self+0x8]),
 * currentCursor 0x1851592f8 (process global), set 0x185046098 (AppKit lock +
 * window-server push). The server push is stage2; the current-cursor stack is
 * modelled in-process.
 */
#import "NSCursor.h"

static NSCursor *sCurrentCursor = nil;
static NSMutableArray<NSCursor *> *sCursorStack = nil;

@implementation NSCursor {
    CGPoint _hotSpot;   /* 0x8 */
    id _image;          /* 0x20 */
}

- (instancetype)initWithImage:(id)image hotSpot:(CGPoint)hotSpot
{
    self = [super init];
    if (self) { _image = image; _hotSpot = hotSpot; }
    return self;
}

- (id)image { return _image; }
- (CGPoint)hotSpot { return _hotSpot; }

+ (NSCursor *)currentCursor { return sCurrentCursor; }

/* set: make this the current cursor (the real one also pushes it to the window
 * server under the AppKit lock — stage2). */
- (void)set { sCurrentCursor = self; }

- (void)push
{
    if (!sCursorStack) sCursorStack = [NSMutableArray array];
    if (sCurrentCursor) [sCursorStack addObject:sCurrentCursor];
    [self set];
}

+ (void)pop
{
    if (sCursorStack.count > 0) {
        sCurrentCursor = [sCursorStack lastObject];
        [sCursorStack removeLastObject];
    }
}

@end
