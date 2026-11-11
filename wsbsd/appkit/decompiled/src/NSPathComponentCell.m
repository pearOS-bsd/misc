/*
 * NSPathComponentCell.m — behavioral-1:1 core. See NSPathComponentCell.h.
 */

#import "NSPathComponentCell.h"

@implementation NSPathComponentCell {
    NSImage *_image;
    NSURL *_url;
}

- (NSImage *)image { return _image; }
- (void)setImage:(NSImage *)image { _image = image; }
- (NSURL *)URL { return _url; }
- (void)setURL:(NSURL *)url { _url = [url copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSPathComponentCell *c = [[[self class] alloc] init];
    c.stringValue = self.stringValue ?: @"";   /* inherited title */
    c->_image = _image;
    c->_url = [_url copy];
    return c;
}

/* TODO(stage2): drawInteriorWithFrame:/imageRectForBounds:/titleRectForBounds:/
 * cellSizeForBounds: and the navigation-bar arrow + resized-width layout. */

@end
