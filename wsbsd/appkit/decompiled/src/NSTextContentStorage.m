/*
 * NSTextContentStorage.m — behavioral-1:1 core. See the header.
 */

#import "NSTextContentStorage.h"
#import "NSTextParagraph.h"

@implementation NSTextContentStorageLocation
@synthesize offset = _offset;
+ (instancetype)locationWithOffset:(NSInteger)offset
{
    NSTextContentStorageLocation *l = [[self alloc] init];
    l->_offset = offset;
    return l;
}
- (NSComparisonResult)compare:(id<NSTextLocation>)location
{
    NSInteger b = [(NSTextContentStorageLocation *)location offset];
    return _offset < b ? NSOrderedAscending : (_offset > b ? NSOrderedDescending : NSOrderedSame);
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSTextContentStorageLocation class]] && [(NSTextContentStorageLocation *)o offset] == _offset; }
- (NSUInteger)hash { return (NSUInteger)_offset; }
@end

@implementation NSTextContentStorage {
    NSAttributedString *_attributedString;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _attributedString = [[NSAttributedString alloc] initWithString:@""];   /* empty, not nil (measured) */
    }
    return self;
}

- (NSAttributedString *)attributedString { return _attributedString; }
- (void)setAttributedString:(NSAttributedString *)s
{
    _attributedString = [s copy] ?: [[NSAttributedString alloc] initWithString:@""];
}

- (NSTextRange *)documentRange
{
    NSInteger len = (NSInteger)_attributedString.length;
    return [[NSTextRange alloc] initWithLocation:[NSTextContentStorageLocation locationWithOffset:0]
                                     endLocation:[NSTextContentStorageLocation locationWithOffset:len]];
}

- (id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)location withOffset:(NSInteger)offset
{
    NSInteger base = [(NSTextContentStorageLocation *)location offset];
    NSInteger result = base + offset;
    if (result < 0 || result > (NSInteger)_attributedString.length) return nil;
    return [NSTextContentStorageLocation locationWithOffset:result];
}

- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to
{
    return [(NSTextContentStorageLocation *)to offset] - [(NSTextContentStorageLocation *)from offset];
}

- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range
{
    NSString *str = _attributedString.string;
    NSInteger length = (NSInteger)str.length;
    NSInteger lo = range ? [(NSTextContentStorageLocation *)range.location offset] : 0;
    NSInteger hi = range ? [(NSTextContentStorageLocation *)range.endLocation offset] : length;
    if (lo < 0) lo = 0;
    if (hi > length) hi = length;
    if (hi < lo) return @[];

    NSMutableArray<NSTextElement *> *elements = [NSMutableArray array];
    NSInteger i = lo;
    while (i < hi) {
        NSRange para = [str paragraphRangeForRange:NSMakeRange((NSUInteger)i, 0)];
        NSInteger paraEnd = (NSInteger)NSMaxRange(para);
        NSInteger clampedEnd = MIN(paraEnd, hi);
        NSRange sub = NSMakeRange((NSUInteger)i, (NSUInteger)(clampedEnd - i));
        NSAttributedString *piece = [_attributedString attributedSubstringFromRange:sub];
        NSTextParagraph *p = [[NSTextParagraph alloc] initWithAttributedString:piece];
        p.elementRange = [[NSTextRange alloc] initWithLocation:[NSTextContentStorageLocation locationWithOffset:i]
                                                   endLocation:[NSTextContentStorageLocation locationWithOffset:clampedEnd]];
        [elements addObject:p];
        i = paraEnd;
    }
    return elements;
}

- (NSAttributedString *)attributedStringForTextElement:(NSTextElement *)textElement
{
    if ([textElement isKindOfClass:[NSTextParagraph class]]) {
        return [(NSTextParagraph *)textElement attributedString];
    }
    return nil;
}

- (NSTextElement *)textParagraphForLocation:(id<NSTextLocation>)location
{
    NSInteger off = [(NSTextContentStorageLocation *)location offset];
    if (off < 0 || off > (NSInteger)_attributedString.length) return nil;
    NSRange para = [_attributedString.string paragraphRangeForRange:NSMakeRange((NSUInteger)MIN(off,(NSInteger)_attributedString.length ? (NSInteger)_attributedString.length-1 : 0), 0)];
    if (_attributedString.length == 0) para = NSMakeRange(0,0);
    NSTextParagraph *p = [[NSTextParagraph alloc] initWithAttributedString:[_attributedString attributedSubstringFromRange:para]];
    p.elementRange = [[NSTextRange alloc] initWithLocation:[NSTextContentStorageLocation locationWithOffset:(NSInteger)para.location]
                                               endLocation:[NSTextContentStorageLocation locationWithOffset:(NSInteger)NSMaxRange(para)]];
    return p;
}

@end
