/*
 * NSCollectionLayoutSize.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutSize.h"

@implementation NSCollectionLayoutSize {
    NSCollectionLayoutDimension *_width;
    NSCollectionLayoutDimension *_height;
}

+ (instancetype)sizeWithWidthDimension:(NSCollectionLayoutDimension *)width
                       heightDimension:(NSCollectionLayoutDimension *)height
{
    NSCollectionLayoutSize *s = [[self alloc] init];
    /* dimensions are immutable; the real class keeps the same objects (measured). */
    s->_width = width;
    s->_height = height;
    return s;
}

- (NSCollectionLayoutDimension *)widthDimension { return _width; }
- (NSCollectionLayoutDimension *)heightDimension { return _height; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] sizeWithWidthDimension:_width heightDimension:_height];
}

@end
