/*
 * NSCachedImageRep.m — behavioral-1:1 core. See the header.
 */

#import "NSCachedImageRep.h"

@implementation NSCachedImageRep {
    NSWindow *_window;
    CGRect _rect;
}

- (instancetype)initWithSize:(CGSize)size depth:(NSInteger)depth separate:(BOOL)flag alpha:(BOOL)alpha
{
    self = [super init];
    if (self) {
        self.size = size;
        _rect = CGRectMake(0, 0, size.width, size.height);   /* measured */
        /* the real class allocates an offscreen backing window here (stage2). */
    }
    return self;
}

- (instancetype)initWithWindow:(NSWindow *)win rect:(CGRect)rect
{
    self = [super init];
    if (self) {
        _window = win;
        _rect = rect;
        self.size = rect.size;
    }
    return self;
}

- (NSWindow *)window { return _window; }
- (CGRect)rect { return _rect; }

@end
