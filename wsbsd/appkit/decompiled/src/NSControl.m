/*
 * NSControl.m — 1:1 reimplementation of AppKit's NSControl (cell-backed core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/nscontrol.
 *
 * Measured ivar offsets (_OBJC_IVAR_$_NSControl.*):
 *   _aux             0x7b0   side object; holds overridden target/action
 *   _cell            0x7b4   the control's cell
 *   _conFlags        0x7b8   uint32: bit0 enabled, bit2 set in initWithFrame:
 *   _wasEverZeroCell 0x7bc   byte
 *
 * _NSControlDelegatesToCell gates every accessor. Its default answer is "yes
 * when the control has a cell", which is what we model here.
 */
#import "NSControl.h"
#import "NSActionCell.h"
#import "NSApplication.h"

extern void NSBeep(void);

@implementation NSControl {
    id _aux;                 /* 0x7b0 */
    NSCell *_cell;           /* 0x7b4 */
    uint32_t _conFlags;      /* 0x7b8 */
    uint8_t _wasEverZeroCell;/* 0x7bc */
}

/* Base NSControl has no cell class; concrete controls override. */
+ (Class)cellClass { return Nil; }

/* model of _NSControlDelegatesToCell: delegate whenever a cell is present. */
static inline BOOL NSControlDelegatesToCell(NSControl *self) { return self->_cell != nil; }

/* -[NSControl initWithFrame:]  — evidence: 0x184f21824
 * super initWithFrame:, build the cell from +cellClass, set the enabled bits in
 * _conFlags (orr #1 then #4 under __controlBitfieldLock). */
- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _conFlags |= 0x1;   /* enabled */
        _conFlags |= 0x4;
        Class cc = [[self class] cellClass];
        if (cc) {
            NSCell *cell = [[cc alloc] init];
            [self setCell:cell];
        }
    }
    return self;
}

/* -[NSControl cell]  — evidence: 0x184f24b34 (returns _cell; lazy-create path stage2) */
- (NSCell *)cell { return _cell; }

/* -[NSControl setCell:]  — evidence: 0x184f23258
 * Store the cell and point it back at this control. (The binary also tears down
 * the old cell's tracking and redisplays — TODO(stage2).) */
- (void)setCell:(NSCell *)cell
{
    if (cell == _cell)
        return;
    _cell = cell;
    if ([cell respondsToSelector:@selector(setControlView:)])
        [(NSActionCell *)cell setControlView:self];
}

/* -[NSControl isEnabled]  — evidence: 0x184f2c8c4
 * delegate ? [cell isEnabled] : (_conFlags & 1). */
- (BOOL)isEnabled
{
    if (NSControlDelegatesToCell(self))
        return [_cell isEnabled];
    return (_conFlags & 0x1) != 0;
}

/* -[NSControl setEnabled:]  — evidence: 0x184f24bb0 (push through to the cell;
 * the real setter also redisplays and syncs _conFlags — the sync is kept). */
- (void)setEnabled:(BOOL)enabled
{
    if (NSControlDelegatesToCell(self))
        [_cell setEnabled:enabled];
    if (enabled)
        _conFlags |= 0x1;
    else
        _conFlags &= ~0x1u;
}

/* -[NSControl target]  — evidence: 0x184f29110
 * No override in _aux by default -> read from the cell. */
- (id)target { return NSControlDelegatesToCell(self) ? [(NSActionCell *)_cell target] : nil; }

/* -[NSControl setTarget:]  — evidence: 0x184f... -> cell */
- (void)setTarget:(id)target { [(NSActionCell *)_cell setTarget:target]; }

/* -[NSControl action]  — evidence: 0x184f291c8 */
- (SEL)action { return NSControlDelegatesToCell(self) ? [(NSActionCell *)_cell action] : NULL; }

/* -[NSControl setAction:]  — evidence: 0x184f... -> cell */
- (void)setAction:(SEL)action { [(NSActionCell *)_cell setAction:action]; }

/* -[NSControl tag] / setTag:  -> cell (NSActionCell holds the real tag). */
- (NSInteger)tag { return NSControlDelegatesToCell(self) ? [_cell tag] : -1; }
- (void)setTag:(NSInteger)tag { [(NSActionCell *)_cell setTag:tag]; }

/* -[NSControl sendAction:to:]  — evidence: 0x185098360
 * Route through the application: [NSApp sendAction:action to:target from:self].
 * Beep when a target was named but nothing handled it. (The binary's
 * _sendActionInProgress bookkeeping and the exact beep gate are stage2.) */
- (BOOL)sendAction:(SEL)action to:(id)target
{
    if (action == NULL)
        return NO;
    BOOL handled = [NSApp sendAction:action to:target from:self];
    if (target != nil && !handled)
        NSBeep();
    return handled;
}

@end
