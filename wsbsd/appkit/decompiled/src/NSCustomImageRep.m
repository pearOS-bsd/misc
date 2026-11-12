/*
 * NSCustomImageRep.m — behavioral-1:1 core. See the header.
 */

#import "NSCustomImageRep.h"

@implementation NSCustomImageRep {
    NSCustomImageRepDrawingHandler _drawingHandler;
    SEL _drawSelector;
    __weak id _delegate;
    BOOL _flipped;
}

- (instancetype)initWithSize:(CGSize)size
                     flipped:(BOOL)flipped
              drawingHandler:(NSCustomImageRepDrawingHandler)drawingHandler
{
    self = [super init];
    if (self) {
        self.size = size;
        _flipped = flipped;
        _drawingHandler = [drawingHandler copy];
    }
    return self;
}

- (instancetype)initWithDrawSelector:(SEL)drawSelector delegate:(id)delegate
{
    self = [super init];
    if (self) {
        _drawSelector = drawSelector;
        _delegate = delegate;
    }
    return self;
}

- (NSCustomImageRepDrawingHandler)drawingHandler { return _drawingHandler; }
- (SEL)drawSelector { return _drawSelector; }
- (id)delegate { return _delegate; }
- (BOOL)isFlipped { return _flipped; }
- (void)setFlipped:(BOOL)f { _flipped = f; }

- (BOOL)draw
{
    if (_drawingHandler) {
        CGRect dst = CGRectMake(0, 0, self.size.width, self.size.height);
        return _drawingHandler(dst);
    }
    if (_drawSelector && _delegate && [_delegate respondsToSelector:_drawSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_delegate performSelector:_drawSelector withObject:self];
#pragma clang diagnostic pop
    }
    return YES;   /* no handler: the real rep just no-ops its content */
}

@end
