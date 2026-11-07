/*
 * NSPathCell.m — 1:1 (core). Evidence ../evidence/path:
 * pathStyle 0x1859f9d84 ([self+0xa08]), setPathStyle: 0x1859f9f50 (early-out if
 * equal), URL 0x1859f80a4 (through cell contents — kept plainly here, stage2).
 */
#import "NSPathCell.h"

@implementation NSPathCell {
    NSPathStyle _pathStyle;   /* 0xa08 */
    NSURL *_url;              /* shipping: NSCell contents (stage2) */
}

- (NSPathStyle)pathStyle { return _pathStyle; }
- (void)setPathStyle:(NSPathStyle)pathStyle
{
    if (_pathStyle == pathStyle) return;   /* early-out as the binary does */
    _pathStyle = pathStyle;
}

- (NSURL *)URL { return _url; }
- (void)setURL:(NSURL *)URL { _url = [URL copy]; }

@end
