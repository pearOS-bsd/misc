/*
 * NSController.m — behavioral-1:1 core (editor-registration state machine).
 * See NSController.h for the stage2 boundary (KVO binding adaptor etc.).
 */

#import "NSController.h"
#import <objc/message.h>

@implementation NSController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _editors = [[NSMutableArray alloc] init];
        _isEditing = NO;
        _alwaysPresentsApplicationModalAlerts = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; /* stage2: decode bindings */ }
- (void)encodeWithCoder:(NSCoder *)coder { /* TODO(stage2) */ }

- (BOOL)isEditing { return _isEditing; }

- (BOOL)alwaysPresentsApplicationModalAlerts { return _alwaysPresentsApplicationModalAlerts; }
- (void)setAlwaysPresentsApplicationModalAlerts:(BOOL)v { _alwaysPresentsApplicationModalAlerts = v; }

/* --- NSEditorRegistration: track outstanding editors --- */

- (void)objectDidBeginEditing:(id<NSEditor>)editor
{
    if (!editor) return;
    /* identity-based set (editors are not necessarily equal-comparable). */
    for (id e in _editors) if (e == editor) return;
    [_editors addObject:editor];
    _isEditing = YES;
}

- (void)objectDidEndEditing:(id<NSEditor>)editor
{
    if (!editor) return;
    NSUInteger idx = NSNotFound;
    for (NSUInteger i = 0; i < _editors.count; i++)
        if (_editors[i] == editor) { idx = i; break; }
    if (idx != NSNotFound) [_editors removeObjectAtIndex:idx];
    if (_editors.count == 0) _isEditing = NO;
}

/* --- NSEditor: drive the registered editors --- */

- (BOOL)commitEditing
{
    /* Commit each outstanding editor; a refusal stops the commit (AppKit
     * semantics: returns NO and leaves editing in progress). */
    NSArray *snapshot = [_editors copy];
    for (id<NSEditor> editor in snapshot) {
        if (![editor commitEditing]) return NO;
    }
    [_editors removeAllObjects];
    _isEditing = NO;
    return YES;
}

- (BOOL)commitEditingAndReturnError:(NSError * _Nullable * _Nullable)error
{
    BOOL ok = [self commitEditing];
    if (!ok && error) *error = nil; /* stage2: carry the editor's error */
    return ok;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo
{
    BOOL committed = [self commitEditing];
    /* editor:didCommit:contextInfo: callback (AppKit's async-shaped API). */
    if (delegate && didCommitSelector && [delegate respondsToSelector:didCommitSelector]) {
        void (*cb)(id, SEL, id, BOOL, void *) = (void (*)(id, SEL, id, BOOL, void *))objc_msgSend;
        cb(delegate, didCommitSelector, self, committed, contextInfo);
    }
}

- (void)discardEditing
{
    NSArray *snapshot = [_editors copy];
    for (id<NSEditor> editor in snapshot) [editor discardEditing];
    [_editors removeAllObjects];
    _isEditing = NO;
}

@end
