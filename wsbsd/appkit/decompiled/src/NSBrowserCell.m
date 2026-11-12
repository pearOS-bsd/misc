/*
 * NSBrowserCell.m — behavioral-1:1 core. See the header.
 */

#import "NSBrowserCell.h"

@implementation NSBrowserCell {
    BOOL _leaf;
    BOOL _loaded;
    NSString *_stringValue;
    NSImage *_image;
    NSImage *_alternateImage;
}

- (instancetype)initTextCell:(NSString *)string
{
    self = [super init];
    if (self) {
        _stringValue = [string copy];
        _loaded = YES;   /* measured */
        /* leaf=NO (measured) */
    }
    return self;
}

- (instancetype)initImageCell:(NSImage *)image
{
    self = [super init];
    if (self) {
        _image = image;
        _loaded = YES;
    }
    return self;
}

+ (NSImage *)branchImage { return nil; }            /* system disclosure image = stage2 */
+ (NSImage *)highlightedBranchImage { return nil; } /* system disclosure image = stage2 */

- (BOOL)isLeaf { return _leaf; }
- (void)setLeaf:(BOOL)v { _leaf = v; }
- (BOOL)isLoaded { return _loaded; }
- (void)setLoaded:(BOOL)v { _loaded = v; }
- (NSString *)stringValue { return _stringValue; }
- (void)setStringValue:(NSString *)s { _stringValue = [s copy]; }
- (NSImage *)image { return _image; }
- (void)setImage:(NSImage *)i { _image = i; }
- (NSImage *)alternateImage { return _alternateImage; }
- (void)setAlternateImage:(NSImage *)i { _alternateImage = i; }

- (void)reset { self.highlighted = NO; self.state = 0; }
- (void)set { self.highlighted = YES; self.state = 1; }

@end
