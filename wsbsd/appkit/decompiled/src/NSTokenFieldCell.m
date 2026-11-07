/*
 * NSTokenFieldCell.m — 1:1 (core). Evidence ../evidence/token:
 * tokenStyle 0x1850f70ac (flags @0x730 & 0xf), setTokenStyle: 0x1850f6484
 * (accepts 0..4 and 10..12, else 0), completionDelay 0x1856c0840 (double @0x73c),
 * tokenizingCharacterSet 0x18518c2e8 (@0x734, nil -> default).
 */
#import "NSTokenFieldCell.h"

@implementation NSTokenFieldCell {
    uint32_t _tfcFlags;                 /* 0x730: tokenStyle bits 0-3 */
    NSTimeInterval _completionDelay;    /* 0x73c */
    NSCharacterSet *_tokenizingSet;     /* 0x734 */
}

- (NSTokenStyle)tokenStyle { return (NSTokenStyle)(_tfcFlags & 0xf); }
- (void)setTokenStyle:(NSTokenStyle)tokenStyle
{
    uint32_t v = (tokenStyle <= 4 || (tokenStyle >= 10 && tokenStyle <= 12)) ? (uint32_t)tokenStyle : 0;
    _tfcFlags = (_tfcFlags & ~0xfu) | (v & 0xf);
}

- (NSTimeInterval)completionDelay { return _completionDelay; }
- (void)setCompletionDelay:(NSTimeInterval)completionDelay { _completionDelay = completionDelay; }

- (NSCharacterSet *)tokenizingCharacterSet
{
    return _tokenizingSet ?: [NSCharacterSet characterSetWithCharactersInString:@","];  /* default */
}
- (void)setTokenizingCharacterSet:(NSCharacterSet *)set { _tokenizingSet = [set copy]; }

@end
