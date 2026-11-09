/*
 * NSTextTab.m — 1:1 (core). See NSTextTab.h for the interface evidence.
 *
 * alignment lives in _flags b0-3; location and options are plain fields. The
 * legacy -initWithType:location: maps NSTextTabType onto the modern model:
 *   NSLeftTabStopType    -> NSTextAlignmentLeft,   no options
 *   NSRightTabStopType   -> NSTextAlignmentRight,  no options
 *   NSCenterTabStopType  -> NSTextAlignmentCenter, no options
 *   NSDecimalTabStopType -> NSTextAlignmentRight,  { NSTabColumnTerminators… }
 * (AppKit records a decimal tab as a right-aligned tab whose column terminators
 * mark the decimal separator; the terminator character set is stage2.)
 */
#import "NSTextTab.h"

NSString * const NSTabColumnTerminatorsAttributeName = @"NSTabColumnTerminatorsAttributeName";

@implementation NSTextTab {
    NSTextAlignment _alignment;    /* _flags b0-3 */
    CGFloat _location;
    NSDictionary *_options;
}

- (instancetype)initWithTextAlignment:(NSTextAlignment)alignment
                             location:(CGFloat)loc
                              options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _alignment = alignment;
        _location = loc;
        _options = [options copy] ?: @{};
    }
    return self;
}

- (instancetype)initWithType:(NSTextTabType)type location:(CGFloat)loc
{
    NSTextAlignment align;
    NSDictionary *opts = @{};
    switch (type) {
        case NSRightTabStopType:   align = NSTextAlignmentRight;  break;
        case NSCenterTabStopType:  align = NSTextAlignmentCenter; break;
        case NSDecimalTabStopType:
            align = NSTextAlignmentRight;
            /* decimal tab: terminate the column at the locale decimal separator */
            opts = @{ NSTabColumnTerminatorsAttributeName: @"." }; /* set is stage2 */
            break;
        case NSLeftTabStopType:
        default:                   align = NSTextAlignmentLeft;   break;
    }
    return [self initWithTextAlignment:align location:loc options:opts];
}

- (instancetype)init { return [self initWithType:NSLeftTabStopType location:0.0]; }

- (NSTextAlignment)alignment { return _alignment; }
- (CGFloat)location { return _location; }
- (NSDictionary *)options { return _options; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[NSTextTab alloc] initWithTextAlignment:_alignment location:_location options:_options];
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSTextTab class]]) return NO;
    NSTextTab *o = object;
    return _alignment == o->_alignment && _location == o->_location &&
           ((_options == o->_options) || [_options isEqualToDictionary:o->_options]);
}

- (NSUInteger)hash { return (NSUInteger)_location ^ ((NSUInteger)_alignment << 28); }

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ {alignment:%ld location:%g options:%@}",
            [super description], (long)_alignment, _location, _options];
}

@end
