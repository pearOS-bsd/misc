/*
 * NSMenuItem.m — 1:1 reimplementation of AppKit's NSMenuItem (core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/menuitem.
 *
 * Shipping ivar layout (byte offsets seen in the disassembly):
 *   0x10 _title (NSString)            0x30 _submenu (NSMenu)
 *   0x40 _target (weak)               0x48 _action (SEL, PAC-signed)
 *   0x5c _fFlags (state at bits 21-22, enable/other bits)   0x5d separator byte, bit 1
 * We keep the title/submenu/target/action as ivars and model _fFlags for the
 * state tri-state exactly; the enable flag bits and separator bit are modelled.
 */
#import "NSMenuItem.h"

enum : uint64_t {
    NSMenuItemStateShift = 21,
    NSMenuItemStateMask  = 0x3ull << 21,
};

@implementation NSMenuItem {
    NSString *_title;         /* 0x10 */
    NSMenu *_submenu;         /* 0x30 */
    __weak id _target;        /* 0x40 (objc_storeWeak/loadWeak) */
    SEL _action;              /* 0x48 (PAC-signed slot) */
    NSInteger _tag;
    NSString *_keyEquivalent;
    uint64_t _fFlags;         /* 0x5c */
    BOOL _enabled;
    BOOL _separator;          /* 0x5d bit 1 */
}

/* +[NSMenuItem separatorItem]  — evidence: 0x184ef0a4c
 * alloc/init, mark as separator, autorelease. */
+ (NSMenuItem *)separatorItem
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    item->_separator = YES;
    return item;
}

/* -[NSMenuItem initWithTitle:action:keyEquivalent:]  — evidence: 0x184ef0844 */
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)keyEquivalent
{
    self = [super init];
    if (self) {
        _title = [title copy] ?: @"";
        _action = action;
        _keyEquivalent = [keyEquivalent copy] ?: @"";
        _enabled = YES;
    }
    return self;
}

- (instancetype)init { return [self initWithTitle:@"" action:NULL keyEquivalent:@""]; }

/* -[NSMenuItem title] 0x184ef07b8 / setTitle: 0x184ef0b24 (early-out on isEqual). */
- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title
{
    if ([_title isEqualToString:title])
        return;
    _title = [title copy] ?: @"";
}

/* -[NSMenuItem action] 0x184ed8320 / setAction: 0x184ed8e08 (PAC slot). */
- (SEL)action { return _action; }
- (void)setAction:(SEL)action { _action = action; }

/* -[NSMenuItem target] 0x184eed9ec (weak; falls back to nil) / setTarget: 0x184ed7c10 (storeWeak). */
- (id)target { return _target; }
- (void)setTarget:(id)target { _target = target; }

- (NSInteger)tag { return _tag; }
- (void)setTag:(NSInteger)tag { _tag = tag; }

/* -[NSMenuItem state] 0x184ef5d58: bits 21-22 of _fFlags, 0=off 1=on else mixed.
 *   setState: 0x184ee8804 writes the same field (+ redisplay, stage2). */
- (NSControlStateValue)state
{
    uint64_t bits = (_fFlags & NSMenuItemStateMask) >> NSMenuItemStateShift;
    if (bits == 0) return NSControlStateValueOff;
    if (bits == 1) return NSControlStateValueOn;
    return NSControlStateValueMixed;
}
- (void)setState:(NSControlStateValue)state
{
    uint64_t bits = (state == NSControlStateValueOff) ? 0 : (state == NSControlStateValueOn) ? 1 : 3;
    _fFlags = (_fFlags & ~NSMenuItemStateMask) | (bits << NSMenuItemStateShift);
}

/* -[NSMenuItem isEnabled] 0x184ed9738: when NSApp autoenables menus the answer
 * comes from validation; otherwise from an enable flag. TODO(stage2): the NSApp
 * autoenable path. We expose the stored flag. */
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; }

- (NSString *)keyEquivalent { return _keyEquivalent; }
- (void)setKeyEquivalent:(NSString *)keyEquivalent { _keyEquivalent = [keyEquivalent copy] ?: @""; }

/* -[NSMenuItem submenu] 0x184eda7c4 / setSubmenu: 0x184ed9474
 * The binary requires the submenu isKindOfClass:NSMenu and wires the parent —
 * TODO(stage2) once NSMenu exists; here we store it. */
- (NSMenu *)submenu { return _submenu; }
- (void)setSubmenu:(NSMenu *)submenu { _submenu = submenu; }

/* -[NSMenuItem isSeparatorItem] 0x184ed7c1c: byte 0x5d bit 1. */
- (BOOL)isSeparatorItem { return _separator; }

@end
