/*
 * NSSearchFieldCell.m — 1:1 (core). Evidence ../evidence/search:
 * maximumRecents 0x1856adf58 (_sfFlags bits 1-8, 0xff -> -1), setMaximumRecents:
 * 0x1856adeb0 (clamp to 254), sendsWholeSearchString 0x18518cf98 (_sfFlags bit 0).
 */
#import "NSSearchFieldCell.h"

@implementation NSSearchFieldCell {
    uint32_t _sfFlags;                      /* 0xe68 */
    NSArray<NSString *> *_recentSearches;
}

- (NSInteger)maximumRecents
{
    uint32_t v = (_sfFlags >> 1) & 0xff;
    return (v == 0xff) ? -1 : (NSInteger)v;   /* 0xff sentinel == default */
}
- (void)setMaximumRecents:(NSInteger)maximumRecents
{
    uint32_t v;
    if (maximumRecents < 0)        v = 0xff;          /* default */
    else if (maximumRecents > 254) v = 254;           /* binary caps at 0xfe */
    else                           v = (uint32_t)maximumRecents;
    _sfFlags = (_sfFlags & ~(0xffu << 1)) | ((v & 0xff) << 1);
}

- (BOOL)sendsWholeSearchString { return (_sfFlags & 0x1u) != 0; }
- (void)setSendsWholeSearchString:(BOOL)v { if (v) _sfFlags |= 0x1u; else _sfFlags &= ~0x1u; }

- (NSArray<NSString *> *)recentSearches { return _recentSearches ?: @[]; }
- (void)setRecentSearches:(NSArray<NSString *> *)r { _recentSearches = [r copy]; }

@end
