/*
 * NSParagraphStyle.m / NSMutableParagraphStyle — 1:1 (core).
 * See NSParagraphStyle.h for the interface evidence.
 *
 * Storage is declared @protected on the base so the mutable subclass writes the
 * same fields the base reads. alignment and lineBreakMode correspond to the
 * _flags bitfield (b0-3 / b4-7); the other properties map to the named ivars /
 * _extraData. +defaultParagraphStyle returns the canonical immutable default
 * (alignment Natural, all metrics 0, empty tab stops) as a cached singleton,
 * matching AppKit's shared default object.
 */
#import "NSParagraphStyle.h"

@interface NSParagraphStyle ()
- (void)_copyFieldsInto:(NSParagraphStyle *)d;
@end

@implementation NSParagraphStyle {
    @protected
    CGFloat _lineSpacing, _paragraphSpacing, _headIndent, _tailIndent;
    CGFloat _firstLineHeadIndent, _minimumLineHeight, _maximumLineHeight;
    CGFloat _lineHeightMultiple, _paragraphSpacingBefore, _defaultTabInterval;
    float _hyphenationFactor;
    NSTextAlignment _alignment;          /* _flags b0-3 */
    NSLineBreakMode _lineBreakMode;      /* _flags b4-7 */
    NSInteger _baseWritingDirection;
    BOOL _allowsDefaultTighteningForTruncation;
    NSArray *_tabStops;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /* AppKit default: natural alignment, word wrapping, natural direction. */
        _alignment = NSTextAlignmentNatural;
        _lineBreakMode = NSLineBreakByWordWrapping;
        _baseWritingDirection = NSParagraphWritingDirectionNatural;
        _tabStops = @[];   /* real default seeds 12 left tab stops — stage2 */
    }
    return self;
}

+ (NSParagraphStyle *)defaultParagraphStyle
{
    static NSParagraphStyle *def = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ def = [[NSParagraphStyle alloc] init]; });
    return def;
}

- (CGFloat)lineSpacing { return _lineSpacing; }
- (CGFloat)paragraphSpacing { return _paragraphSpacing; }
- (NSTextAlignment)alignment { return _alignment; }
- (CGFloat)headIndent { return _headIndent; }
- (CGFloat)tailIndent { return _tailIndent; }
- (CGFloat)firstLineHeadIndent { return _firstLineHeadIndent; }
- (CGFloat)minimumLineHeight { return _minimumLineHeight; }
- (CGFloat)maximumLineHeight { return _maximumLineHeight; }
- (NSLineBreakMode)lineBreakMode { return _lineBreakMode; }
- (NSInteger)baseWritingDirection { return _baseWritingDirection; }
- (CGFloat)lineHeightMultiple { return _lineHeightMultiple; }
- (CGFloat)paragraphSpacingBefore { return _paragraphSpacingBefore; }
- (float)hyphenationFactor { return _hyphenationFactor; }
- (CGFloat)defaultTabInterval { return _defaultTabInterval; }
- (NSArray *)tabStops { return _tabStops; }
- (BOOL)allowsDefaultTighteningForTruncation { return _allowsDefaultTighteningForTruncation; }

/* Copy the fields into a target (used by -copy and -setParagraphStyle:). */
- (void)_copyFieldsInto:(NSParagraphStyle *)d
{
    d->_lineSpacing = _lineSpacing; d->_paragraphSpacing = _paragraphSpacing;
    d->_headIndent = _headIndent; d->_tailIndent = _tailIndent;
    d->_firstLineHeadIndent = _firstLineHeadIndent;
    d->_minimumLineHeight = _minimumLineHeight; d->_maximumLineHeight = _maximumLineHeight;
    d->_lineHeightMultiple = _lineHeightMultiple;
    d->_paragraphSpacingBefore = _paragraphSpacingBefore;
    d->_defaultTabInterval = _defaultTabInterval;
    d->_hyphenationFactor = _hyphenationFactor;
    d->_alignment = _alignment; d->_lineBreakMode = _lineBreakMode;
    d->_baseWritingDirection = _baseWritingDirection;
    d->_allowsDefaultTighteningForTruncation = _allowsDefaultTighteningForTruncation;
    d->_tabStops = [_tabStops copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSParagraphStyle *c = [[NSParagraphStyle alloc] init];
    [self _copyFieldsInto:c];
    return c;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    NSMutableParagraphStyle *c = [[NSMutableParagraphStyle alloc] init];
    [self _copyFieldsInto:c];
    return c;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSParagraphStyle class]]) return NO;
    NSParagraphStyle *o = object;
    return _alignment == o->_alignment && _lineBreakMode == o->_lineBreakMode &&
           _lineSpacing == o->_lineSpacing && _paragraphSpacing == o->_paragraphSpacing &&
           _headIndent == o->_headIndent && _tailIndent == o->_tailIndent &&
           _firstLineHeadIndent == o->_firstLineHeadIndent &&
           _minimumLineHeight == o->_minimumLineHeight &&
           _maximumLineHeight == o->_maximumLineHeight &&
           _lineHeightMultiple == o->_lineHeightMultiple &&
           _paragraphSpacingBefore == o->_paragraphSpacingBefore &&
           _defaultTabInterval == o->_defaultTabInterval &&
           _hyphenationFactor == o->_hyphenationFactor &&
           _baseWritingDirection == o->_baseWritingDirection;
}

- (NSUInteger)hash { return (NSUInteger)_alignment ^ ((NSUInteger)_lineBreakMode << 4); }

@end


@implementation NSMutableParagraphStyle

@dynamic lineSpacing, paragraphSpacing, alignment, headIndent, tailIndent,
         firstLineHeadIndent, minimumLineHeight, maximumLineHeight, lineBreakMode,
         baseWritingDirection, lineHeightMultiple, paragraphSpacingBefore,
         hyphenationFactor, defaultTabInterval, tabStops,
         allowsDefaultTighteningForTruncation;

- (void)setLineSpacing:(CGFloat)v { _lineSpacing = v; }
- (void)setParagraphSpacing:(CGFloat)v { _paragraphSpacing = v; }
- (void)setAlignment:(NSTextAlignment)v { _alignment = v; }
- (void)setHeadIndent:(CGFloat)v { _headIndent = v; }
- (void)setTailIndent:(CGFloat)v { _tailIndent = v; }
- (void)setFirstLineHeadIndent:(CGFloat)v { _firstLineHeadIndent = v; }
- (void)setMinimumLineHeight:(CGFloat)v { _minimumLineHeight = v; }
- (void)setMaximumLineHeight:(CGFloat)v { _maximumLineHeight = v; }
- (void)setLineBreakMode:(NSLineBreakMode)v { _lineBreakMode = v; }
- (void)setBaseWritingDirection:(NSInteger)v { _baseWritingDirection = v; }
- (void)setLineHeightMultiple:(CGFloat)v { _lineHeightMultiple = v; }
- (void)setParagraphSpacingBefore:(CGFloat)v { _paragraphSpacingBefore = v; }
- (void)setHyphenationFactor:(float)v { _hyphenationFactor = v; }
- (void)setDefaultTabInterval:(CGFloat)v { _defaultTabInterval = v; }
- (void)setTabStops:(NSArray *)v { _tabStops = [v copy]; }
- (void)setAllowsDefaultTighteningForTruncation:(BOOL)v { _allowsDefaultTighteningForTruncation = v; }

- (void)setParagraphStyle:(NSParagraphStyle *)obj
{
    [obj _copyFieldsInto:self];
}

@end
