/*
 * NSTextContainer.m — 1:1 (core). See NSTextContainer.h for interface evidence.
 *
 * -initWithSize: records the size and the classic default lineFragmentPadding of
 * 5.0; tracking flags and lineBreakMode map to _tcFlags (widthTracksTextView b0,
 * heightTracksTextView b1, lineBreakMode b3-6). The layout manager link and the
 * line-fragment geometry are stage2.
 */
#import "NSTextContainer.h"

@implementation NSTextContainer {
    CGSize _size;
    CGFloat _lineFragmentPadding;
    NSUInteger _maximumLines;
    NSLineBreakMode _lineBreakMode;
    BOOL _widthTracksTextView;      /* _tcFlags b0 */
    BOOL _heightTracksTextView;     /* _tcFlags b1 */
    NSArray *_exclusionPaths;
}

- (instancetype)initWithSize:(CGSize)size
{
    self = [super init];
    if (self) {
        _size = size;
        _lineFragmentPadding = 5.0;   /* classic AppKit default */
        _maximumLines = 0;
        _lineBreakMode = NSLineBreakByWordWrapping;
        _exclusionPaths = @[];
    }
    return self;
}

- (instancetype)init { return [self initWithSize:CGSizeZero]; }

- (CGSize)size { return _size; }
- (void)setSize:(CGSize)v { _size = v; }
- (CGFloat)lineFragmentPadding { return _lineFragmentPadding; }
- (void)setLineFragmentPadding:(CGFloat)v { _lineFragmentPadding = v; }
- (NSUInteger)maximumNumberOfLines { return _maximumLines; }
- (void)setMaximumNumberOfLines:(NSUInteger)v { _maximumLines = v; }
- (NSLineBreakMode)lineBreakMode { return _lineBreakMode; }
- (void)setLineBreakMode:(NSLineBreakMode)v { _lineBreakMode = v; }
- (BOOL)widthTracksTextView { return _widthTracksTextView; }
- (void)setWidthTracksTextView:(BOOL)v { _widthTracksTextView = v; }
- (BOOL)heightTracksTextView { return _heightTracksTextView; }
- (void)setHeightTracksTextView:(BOOL)v { _heightTracksTextView = v; }
- (NSArray *)exclusionPaths { return _exclusionPaths; }
- (void)setExclusionPaths:(NSArray *)v { _exclusionPaths = [v copy] ?: @[]; }

@end
