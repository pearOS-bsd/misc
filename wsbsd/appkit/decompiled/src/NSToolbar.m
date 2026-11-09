/*
 * NSToolbar.m — 1:1 (core). Evidence ../evidence/toolbar:
 * displayMode 0x184fb375c (_tbFlags @0x88 bits 22-23), allowsUserCustomization
 * 0x184fb2024 (_tbFlags bit 0), identifier 0x184fb0d80 ([self+0x8]).
 * isVisible (via the window) and items (delegate-built) are stage2.
 */
#import "NSToolbar.h"

@implementation NSToolbar {
    NSString *_identifier;   /* 0x8 */
    uint64_t _tbFlags;       /* 0x88 */
    BOOL _visible;           /* shipping: via window (stage2) */
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) { _identifier = [identifier copy] ?: @""; _visible = YES; }
    return self;
}

- (NSString *)identifier { return _identifier; }

- (NSToolbarDisplayMode)displayMode { return (NSToolbarDisplayMode)((_tbFlags >> 22) & 0x3u); }
- (void)setDisplayMode:(NSToolbarDisplayMode)displayMode
{
    _tbFlags = (_tbFlags & ~(0x3ull << 22)) | (((uint64_t)displayMode & 0x3u) << 22);
}

- (BOOL)isVisible { return _visible; }
- (void)setVisible:(BOOL)visible { _visible = visible; }

- (BOOL)allowsUserCustomization { return (_tbFlags & 0x1u) != 0; }
- (void)setAllowsUserCustomization:(BOOL)v { if (v) _tbFlags |= 0x1u; else _tbFlags &= ~0x1ull; }

@end
