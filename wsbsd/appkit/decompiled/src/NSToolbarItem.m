/*
 * NSToolbarItem.m — 1:1 (core). Evidence ../evidence/tbitem:
 * itemIdentifier 0x184fbd3b8 ([self+0x28]), label 0x184fbf1f0 ([self+0x30], nil
 * -> empty string), tag 0x184fbf798 / setTag: 0x184fbf4f0 ([self+0x58], sets an
 * explicit-tag flag), isEnabled 0x184fcabf4 (flags @0xc8 bit 16), view 0x184fb9054.
 */
#import "NSToolbarItem.h"

@implementation NSToolbarItem {
    NSString *_itemIdentifier;   /* 0x28 */
    NSString *_label;            /* 0x30 */
    NSString *_paletteLabel;
    NSString *_toolTip;
    NSInteger _tag;              /* 0x58 */
    BOOL _enabled;
    NSView *_view;               /* 0x78 */
}

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier
{
    self = [super init];
    if (self) {
        _itemIdentifier = [itemIdentifier copy] ?: @"";
        _label = @"";
        _paletteLabel = @"";
        _enabled = YES;
    }
    return self;
}

- (NSString *)itemIdentifier { return _itemIdentifier; }

- (NSString *)label { return _label ?: @""; }         /* nil -> "" */
- (void)setLabel:(NSString *)label { _label = [label copy]; }

- (NSString *)paletteLabel { return _paletteLabel ?: @""; }
- (void)setPaletteLabel:(NSString *)paletteLabel { _paletteLabel = [paletteLabel copy]; }

- (NSString *)toolTip { return _toolTip; }
- (void)setToolTip:(NSString *)toolTip { _toolTip = [toolTip copy]; }

- (NSInteger)tag { return _tag; }
- (void)setTag:(NSInteger)tag { _tag = tag; }

- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; }

- (NSView *)view { return _view; }
- (void)setView:(NSView *)view { _view = view; }

@end
