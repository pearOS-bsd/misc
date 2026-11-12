/*
 * NSTextSelection.m — behavioral-1:1 core. See the header.
 */

#import "NSTextSelection.h"

@implementation NSTextSelection {
    NSArray<NSTextRange *> *_textRanges;
    NSTextSelectionGranularity _granularity;
    NSTextSelectionAffinity _affinity;
    BOOL _transient;
    BOOL _logical;
    double _anchorPositionOffset;
    id<NSTextLocation> _selectionAnchorLocation;
    id<NSTextLocation> _secondarySelectionLocation;
    NSDictionary *_typingAttributes;
}

- (instancetype)initWithRanges:(NSArray<NSTextRange *> *)textRanges
                      affinity:(NSTextSelectionAffinity)affinity
                   granularity:(NSTextSelectionGranularity)granularity
{
    self = [super init];
    if (self) {
        _textRanges = [textRanges copy] ?: @[];
        _affinity = affinity;
        _granularity = granularity;
        /* transient=NO, logical=NO, anchorPositionOffset=0, typingAttributes=nil (measured) */
    }
    return self;
}

- (instancetype)initWithRange:(NSTextRange *)range
                     affinity:(NSTextSelectionAffinity)affinity
                  granularity:(NSTextSelectionGranularity)granularity
{
    return [self initWithRanges:(range ? @[range] : @[]) affinity:affinity granularity:granularity];
}

- (instancetype)initWithLocation:(id<NSTextLocation>)location affinity:(NSTextSelectionAffinity)affinity
{
    NSTextRange *empty = [[NSTextRange alloc] initWithLocation:location];
    /* a caret selection is Character granularity (measured). */
    return [self initWithRange:empty affinity:affinity granularity:NSTextSelectionGranularityCharacter];
}

- (NSArray<NSTextRange *> *)textRanges { return _textRanges; }
- (NSTextSelectionGranularity)granularity { return _granularity; }
- (NSTextSelectionAffinity)affinity { return _affinity; }
- (BOOL)isTransient { return _transient; }
- (void)setTransient:(BOOL)v { _transient = v; }
- (BOOL)isLogical { return _logical; }
- (void)setLogical:(BOOL)v { _logical = v; }
- (double)anchorPositionOffset { return _anchorPositionOffset; }
- (void)setAnchorPositionOffset:(double)v { _anchorPositionOffset = v; }
- (id<NSTextLocation>)selectionAnchorLocation { return _selectionAnchorLocation; }
- (void)setSelectionAnchorLocation:(id<NSTextLocation>)l { _selectionAnchorLocation = l; }
- (id<NSTextLocation>)secondarySelectionLocation { return _secondarySelectionLocation; }
- (void)setSecondarySelectionLocation:(id<NSTextLocation>)l { _secondarySelectionLocation = l; }
- (NSDictionary *)typingAttributes { return _typingAttributes; }
- (void)setTypingAttributes:(NSDictionary *)d { _typingAttributes = [d copy]; }

- (NSTextSelection *)textSelectionWithTextRanges:(NSArray<NSTextRange *> *)textRanges
{
    NSTextSelection *s = [[NSTextSelection alloc] initWithRanges:textRanges affinity:_affinity granularity:_granularity];
    s->_transient = _transient;
    s->_logical = _logical;
    s->_anchorPositionOffset = _anchorPositionOffset;
    s->_typingAttributes = [_typingAttributes copy];
    return s;
}

- (NSTextRange *)textRangeContainingLocation:(id<NSTextLocation>)location
{
    for (NSTextRange *r in _textRanges) {
        if ([r containsLocation:location]) return r;
    }
    return nil;
}

- (BOOL)containsLocation:(id<NSTextLocation>)location
{
    return [self textRangeContainingLocation:location] != nil;
}

- (BOOL)isEqualToTextSelection:(NSTextSelection *)s
{
    if (!s) return NO;
    if (_granularity != s.granularity || _affinity != s.affinity) return NO;
    if (_textRanges.count != s.textRanges.count) return NO;
    for (NSUInteger i = 0; i < _textRanges.count; i++) {
        if (![_textRanges[i] isEqualToTextRange:s.textRanges[i]]) return NO;
    }
    return YES;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSTextSelection class]]) return NO;
    return [self isEqualToTextSelection:object];
}

- (NSUInteger)hash { return _textRanges.count ^ (NSUInteger)_granularity ^ ((NSUInteger)_affinity << 8); }

@end
