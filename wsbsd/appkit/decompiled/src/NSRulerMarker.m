/*
 * NSRulerMarker.m — 1:1 (core). See NSRulerMarker.h for the interface evidence.
 *
 * Holds the owning ruler (weak), the location along the ruler, the image and
 * its origin, the movable/removable flags (_rFlags b0/b1, both default YES) and
 * a represented object. The drag-tracking machinery (trackMarker…) is stage2.
 */
#import "NSRulerMarker.h"

@implementation NSRulerMarker {
    __weak id _ruler;
    CGFloat _location;
    id _image;
    CGPoint _imageOrigin;
    BOOL _movable;     /* _rFlags b0 */
    BOOL _removable;   /* _rFlags b1 */
    id _representedObject;
}

- (instancetype)initWithRulerView:(id)ruler
                   markerLocation:(CGFloat)location
                            image:(id)image
                      imageOrigin:(CGPoint)imageOrigin
{
    self = [super init];
    if (self) {
        _ruler = ruler;
        _location = location;
        _image = image;
        _imageOrigin = imageOrigin;
        _movable = YES;      /* AppKit markers are movable and removable by default */
        _removable = YES;
    }
    return self;
}

- (id)ruler { return _ruler; }
- (CGFloat)markerLocation { return _location; }
- (void)setMarkerLocation:(CGFloat)v { _location = v; }
- (id)image { return _image; }
- (void)setImage:(id)v { _image = v; }
- (CGPoint)imageOrigin { return _imageOrigin; }
- (void)setImageOrigin:(CGPoint)v { _imageOrigin = v; }
- (BOOL)isMovable { return _movable; }
- (void)setMovable:(BOOL)v { _movable = v; }
- (BOOL)isRemovable { return _removable; }
- (void)setRemovable:(BOOL)v { _removable = v; }
- (id)representedObject { return _representedObject; }
- (void)setRepresentedObject:(id)v { _representedObject = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSRulerMarker *c = [[NSRulerMarker alloc] initWithRulerView:_ruler markerLocation:_location
                                                          image:_image imageOrigin:_imageOrigin];
    c->_movable = _movable; c->_removable = _removable; c->_representedObject = _representedObject;
    return c;
}

@end
