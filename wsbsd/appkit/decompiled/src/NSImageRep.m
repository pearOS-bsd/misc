/*
 * NSImageRep.m — 1:1 (core). See NSImageRep.h for the interface evidence.
 *
 * Plain metadata holder. hasAlpha and isOpaque are _repFlags b0/b1 and
 * bitsPerSample is _repFlags b8-15 (modelled with named fields; per the work
 * model we match the observable contract, not Apple's exact bit packing).
 * -size lets an NSImageRep serve directly as an NSImage representation. The
 * NSCoding/draw paths and concrete subclasses are stage2.
 */
#import "NSImageRep.h"

@implementation NSImageRep {
    NSString *_colorSpaceName;
    BOOL _hasAlpha;          /* _repFlags b0 */
    BOOL _isOpaque;          /* _repFlags b1 */
    NSInteger _bitsPerSample;/* _repFlags b8-15 */
    NSInteger _pixelsWide, _pixelsHigh;
    CGSize _size;
}

- (CGSize)size { return _size; }
- (void)setSize:(CGSize)v { _size = v; }
- (NSInteger)pixelsWide { return _pixelsWide; }
- (void)setPixelsWide:(NSInteger)v { _pixelsWide = v; }
- (NSInteger)pixelsHigh { return _pixelsHigh; }
- (void)setPixelsHigh:(NSInteger)v { _pixelsHigh = v; }
- (NSInteger)bitsPerSample { return _bitsPerSample; }
- (void)setBitsPerSample:(NSInteger)v { _bitsPerSample = v & 0xff; } /* b8-15 field */
- (BOOL)hasAlpha { return _hasAlpha; }
- (void)setAlpha:(BOOL)v { _hasAlpha = v; }
- (BOOL)isOpaque { return _isOpaque; }
- (void)setOpaque:(BOOL)v { _isOpaque = v; }
- (NSString *)colorSpaceName { return _colorSpaceName; }
- (void)setColorSpaceName:(NSString *)v { _colorSpaceName = [v copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSImageRep *c = [[[self class] alloc] init];
    c->_colorSpaceName = [_colorSpaceName copy];
    c->_hasAlpha = _hasAlpha; c->_isOpaque = _isOpaque;
    c->_bitsPerSample = _bitsPerSample;
    c->_pixelsWide = _pixelsWide; c->_pixelsHigh = _pixelsHigh;
    c->_size = _size;
    return c;
}

@end
