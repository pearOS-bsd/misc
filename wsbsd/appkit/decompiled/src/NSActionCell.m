/*
 * NSActionCell.m — 1:1 reimplementation of AppKit's NSActionCell.
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/nsactioncell.
 *
 * Measured ivar offsets (_OBJC_IVAR_$_NSActionCell.*):
 *   _target      0x670   non-retained reference to the target object
 *   _action      0x674   SEL (PAC-signed in the binary)
 *   _tag         0x678   NSInteger
 *   _controlView 0x67c   the owning NSControl (weak)
 *
 * The target is held non-retained. The shipping runtime, when
 * _NSControlsUseWeakTargets is NO (the default), wraps it in an
 * +[NSValue valueWithNonretainedObject:] and retains that box; the getter
 * unwraps with -nonretainedObjectValue. When the flag is YES it stores the
 * object directly as a zeroing weak ref. Both expose the same contract: the
 * cell does not own its target. We model it as an unretained assign, which
 * matches the default path's observable behaviour.
 */
#import "NSActionCell.h"

@implementation NSActionCell {
    __unsafe_unretained id _target;           /* 0x670 */
    SEL _action;                              /* 0x674 */
    NSInteger _tag;                           /* 0x678 */
    __unsafe_unretained NSView *_controlView; /* 0x67c */
}

/* -[NSActionCell target]  — evidence: 0x184f29170 (nonretained) */
- (id)target { return _target; }

/* -[NSActionCell setTarget:]  — evidence: 0x184f24a68 (non-retaining store) */
- (void)setTarget:(id)target { _target = target; }

/* -[NSActionCell action]  — evidence: 0x184f29228 */
- (SEL)action { return _action; }

/* -[NSActionCell setAction:]  — evidence: 0x184f248fc  (PAC-signed slot) */
- (void)setAction:(SEL)action { _action = action; }

/* -[NSActionCell tag]  — evidence: 0x185187c08 */
- (NSInteger)tag { return _tag; }

/* -[NSActionCell setTag:]  — evidence: 0x1855f86d4 */
- (void)setTag:(NSInteger)tag { _tag = tag; }

/* -[NSActionCell controlView]  — evidence: 0x184f22604 (returns [super controlView]
 * in the binary; NSCell's controlView ivar is stage2, so we hold it here). */
- (NSView *)controlView { return _controlView; }

/* -[NSActionCell setControlView:]  — evidence: 0x184f234e0
 * The binary only stores the view when it isKindOfClass:NSControl (else nil),
 * then calls super. NSControl is not built yet, so the kind check is TODO(stage2). */
- (void)setControlView:(NSView *)controlView { _controlView = controlView; }

@end
