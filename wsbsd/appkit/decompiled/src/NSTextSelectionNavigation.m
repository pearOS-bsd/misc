/*
 * NSTextSelectionNavigation.m — behavioral-1:1 core. See the header.
 */

#import "NSTextSelectionNavigation.h"

@implementation NSTextSelectionNavigation {
    __weak id<NSTextSelectionDataSource> _dataSource;
    BOOL _allowsNonContiguousRanges;
    BOOL _rotatesCoordinateSystemForLayoutOrientation;
}

- (instancetype)init { return [self initWithDataSource:nil]; }

- (instancetype)initWithDataSource:(id<NSTextSelectionDataSource>)dataSource
{
    self = [super init];
    if (self) {
        _dataSource = dataSource;
        _allowsNonContiguousRanges = YES;   /* measured */
        /* rotatesCoordinateSystemForLayoutOrientation = NO (measured) */
    }
    return self;
}

- (id<NSTextSelectionDataSource>)textSelectionDataSource { return _dataSource; }
- (void)setTextSelectionDataSource:(id<NSTextSelectionDataSource>)d { _dataSource = d; }
- (BOOL)allowsNonContiguousRanges { return _allowsNonContiguousRanges; }
- (void)setAllowsNonContiguousRanges:(BOOL)v { _allowsNonContiguousRanges = v; }
- (BOOL)rotatesCoordinateSystemForLayoutOrientation { return _rotatesCoordinateSystemForLayoutOrientation; }
- (void)setRotatesCoordinateSystemForLayoutOrientation:(BOOL)v { _rotatesCoordinateSystemForLayoutOrientation = v; }

- (NSTextSelection *)destinationSelectionForTextSelection:(NSTextSelection *)textSelection
                                                direction:(NSTextSelectionNavigationDirection)direction
                                              destination:(NSTextSelectionNavigationDestination)destination
                                                extending:(BOOL)extending
                                                 confined:(BOOL)confined
{
    /* TODO(stage2): walk the data source's layout to find the new selection. */
    return nil;
}

@end
