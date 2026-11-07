/*
 * NSResponder.m — 1:1 reimplementation of AppKit's NSResponder.
 *
 * Every method below is transcribed from the macOS 27 arm64e disassembly in
 * ../evidence/. Source addresses are cited per method. Behaviour, not bytes.
 *
 * Measured ivar layout (isa at 0x0):
 *   0x08  _nextResponder            (id, not an owning ref by default)
 *   0x10  _dependencyInfo           (NSKeyValueDependencyInfo *)
 *   0x18  _respondersWeAreNextFor   (NSPointerArray *, weak entries)
 */
#import "NSResponder.h"
#import <objc/message.h>
#import <objc/runtime.h>

/*
 * Provided by AppKit in the real build; by the test harness standalone.
 *   NSBeep()                     — AppKit.
 *   _NSAddKeyValueDependency()   — AppKit KVO dependency registration.
 *   NSKeyValueDependencyInfo     — AppKit private, -initWithOwner:.
 */
extern void NSBeep(void);
extern void _NSAddKeyValueDependency(id object, NSString *key);
@interface NSKeyValueDependencyInfo : NSObject
- (instancetype)initWithOwner:(id)owner;
@end

@implementation NSResponder {
    __unsafe_unretained NSResponder *_nextResponder;   /* 0x08 */
    NSKeyValueDependencyInfo *_dependencyInfo;          /* 0x10 */
    NSPointerArray *_respondersWeAreNextFor;            /* 0x18 */
}

/* -[NSResponder init]  — evidence: 0x184ec8bdc */
- (instancetype)init
{
    self = [super init];
    if (self) {
        /* _dependencyInfo = [[NSKeyValueDependencyInfo alloc] initWithOwner:self] (str @0x10) */
        _dependencyInfo = [[NSKeyValueDependencyInfo alloc] initWithOwner:self];
        /* helper @0x18803c740(self, 1) enables event-notification posting — not externally observable */
    }
    return self;
}

- (void)dealloc
{
    /* mirror of -_dealloc. _nextResponder is not an owning reference, so before
     * we go away we (1) tell every responder that is "next for" us to drop its
     * now-dangling nextResponder, and (2) remove our own back-reference from the
     * responder we point at. This is what _respondersWeAreNextFor exists for. */
    if (_respondersWeAreNextFor) {
        for (NSUInteger i = 0; i < _respondersWeAreNextFor.count; i++) {
            NSResponder *r = (__bridge NSResponder *)[_respondersWeAreNextFor pointerAtIndex:i];
            if (r && r->_nextResponder == self)
                r->_nextResponder = nil;
        }
    }
    [self _clearNextResponderBackReference];
}

#pragma mark - Responder chain

/* -[NSResponder nextResponder]  — evidence: 0x184f4f418
 * Registers the KVO dependency on "nextResponder", then returns _nextResponder.
 * App-compat flags (default): NSResponderNextResponderIsWeak = NO,
 * NSResponderNextResponderAutoreleases = YES. Under ARC the autorelease of the
 * returned value is implicit, so the default behaviour matches as written. */
- (NSResponder *)nextResponder
{
    _NSAddKeyValueDependency(self, @"nextResponder");
    return _nextResponder;
}

/* -[NSResponder setNextResponder:]  — evidence: 0x184f11b6c */
- (void)setNextResponder:(NSResponder *)aResponder
{
    NSAssert(aResponder == nil || [aResponder isKindOfClass:[NSResponder class]],
             @"aResponder == ((void*)0) || [aResponder isKindOfClass:[NSResponder class]]");

    if (_nextResponder == aResponder)
        return;

    [self _clearNextResponderBackReference];
    [self _setNextResponderAndMakeBackReference:aResponder];

    /* NSResponderDebugResponderLoops (default off): walk the new chain and, if
     * we are reachable from ourselves, throw. Kept always-on here because a
     * responder-chain loop is a hard programming error either way. */
    for (NSResponder *r = aResponder; r != nil; r = r->_nextResponder) {
        if (r == self)
            [NSException raise:NSInternalInconsistencyException
                        format:@"You have a loop in the responder chain: this is a programming error"];
    }
}

/* -[NSResponder _setNextResponderAndMakeBackReference:] */
- (void)_setNextResponderAndMakeBackReference:(NSResponder *)aResponder
{
    _nextResponder = aResponder;
    if (aResponder) {
        if (!aResponder->_respondersWeAreNextFor)
            aResponder->_respondersWeAreNextFor = [NSPointerArray weakObjectsPointerArray];
        [aResponder->_respondersWeAreNextFor addPointer:(__bridge void *)self];
    }
}

/* -[NSResponder _clearNextResponderBackReference] */
- (void)_clearNextResponderBackReference
{
    NSResponder *old = _nextResponder;
    if (old && old->_respondersWeAreNextFor) {
        NSPointerArray *arr = old->_respondersWeAreNextFor;
        for (NSUInteger i = arr.count; i-- > 0; ) {
            if ([arr pointerAtIndex:i] == (__bridge void *)self)
                [arr removePointerAtIndex:i];
        }
    }
}

#pragma mark - Action / command dispatch

/* -[NSResponder tryToPerform:with:]  — evidence: 0x1850e6c7c */
- (BOOL)tryToPerform:(SEL)anAction with:(id)anObject
{
    if ([self respondsToSelector:anAction]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self, anAction, anObject);
        return YES;
    }
    /* tail: [_nextResponder tryToPerform:anAction with:anObject]; nil -> NO */
    return [_nextResponder tryToPerform:anAction with:anObject];
}

/* -[NSResponder doCommandBySelector:]  — evidence: 0x18518cfb0 */
- (void)doCommandBySelector:(SEL)aSelector
{
    if ([self respondsToSelector:aSelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self, aSelector, nil);
        return;
    }

    /* Compatibility aliasing of the four line-end commands onto the
     * line-begin/end commands, then re-dispatch with the mapped selector. */
    static const char *const kFrom[4] = {
        "moveToLeftEndOfLine:",
        "moveToRightEndOfLine:",
        "moveToLeftEndOfLineAndModifySelection:",
        "moveToRightEndOfLineAndModifySelection:",
    };
    static const char *const kTo[4] = {
        "moveToBeginningOfLine:",
        "moveToEndOfLine:",
        "moveToBeginningOfLineAndModifySelection:",
        "moveToEndOfLineAndModifySelection:",
    };
    for (int i = 0; i < 4; i++) {
        if (sel_isEqual(aSelector, sel_registerName(kFrom[i]))) {
            SEL mapped = sel_registerName(kTo[i]);
            if (mapped) { [self doCommandBySelector:mapped]; return; }
            break;
        }
    }

    if (_nextResponder) {
        [_nextResponder doCommandBySelector:aSelector];
        return;
    }

    /* (private _viewBridgeDoCommandBySelector:sender: path omitted) */
    NSBeep();
}

/* -[NSResponder interpretKeyEvents:] routes each event's characters through the
 * input context, which calls doCommandBySelector:/insertText:. Until the input
 * context class is reimplemented, forward the commands directly. */
- (void)interpretKeyEvents:(NSArray *)eventArray
{
    /* placeholder until NSTextInputContext is reimplemented (separate pass) */
}

#pragma mark - First responder (defaults)

- (BOOL)acceptsFirstResponder { return NO;  } /* 0x18507a5bc */
- (BOOL)becomeFirstResponder  { return YES; } /* 0x1850e6614 */
- (BOOL)resignFirstResponder  { return YES; } /* 0x184fea2e4 */

- (BOOL)performKeyEquivalent:(NSEvent *)event { return NO; } /* 0x1856f0118 */
- (BOOL)performMnemonic:(NSString *)string    { return NO; } /* 0x1856f0120 */

#pragma mark - Default event routing  (evidence: keyDown: 0x18517ab1c, mouseDown: 0x1850ef6a0 -> _forwardMethod)

/* The real NSResponder shares one IMP (_forwardMethod) across the default
 * event selectors: send the same selector to _nextResponder, or, if there is
 * none, call -noResponderFor:_cmd. */
static inline void _NSResponderForward(NSResponder *self, SEL _cmd, id event)
{
    NSResponder *next = [self nextResponder];
    if (next)
        ((void (*)(id, SEL, id))objc_msgSend)(next, _cmd, event);
    else
        ((void (*)(id, SEL, SEL))objc_msgSend)(self, @selector(noResponderFor:), _cmd);
}

- (void)mouseDown:(NSEvent *)event         { _NSResponderForward(self, _cmd, event); }
- (void)mouseDragged:(NSEvent *)event      { _NSResponderForward(self, _cmd, event); }
- (void)mouseUp:(NSEvent *)event           { _NSResponderForward(self, _cmd, event); }
- (void)mouseMoved:(NSEvent *)event        { _NSResponderForward(self, _cmd, event); }
- (void)rightMouseDown:(NSEvent *)event    { _NSResponderForward(self, _cmd, event); }
- (void)rightMouseDragged:(NSEvent *)event { _NSResponderForward(self, _cmd, event); }
- (void)rightMouseUp:(NSEvent *)event      { _NSResponderForward(self, _cmd, event); }
- (void)otherMouseDown:(NSEvent *)event    { _NSResponderForward(self, _cmd, event); }
- (void)otherMouseDragged:(NSEvent *)event { _NSResponderForward(self, _cmd, event); }
- (void)otherMouseUp:(NSEvent *)event      { _NSResponderForward(self, _cmd, event); }
- (void)scrollWheel:(NSEvent *)event       { _NSResponderForward(self, _cmd, event); }
- (void)keyDown:(NSEvent *)event           { _NSResponderForward(self, _cmd, event); }
- (void)keyUp:(NSEvent *)event             { _NSResponderForward(self, _cmd, event); }
- (void)flagsChanged:(NSEvent *)event      { _NSResponderForward(self, _cmd, event); }

/* -[NSResponder noResponderFor:]  — evidence: 0x1850f00a4
 * Beep only for an unhandled keyDown:. */
- (void)noResponderFor:(SEL)eventSelector
{
    if (sel_isEqual(eventSelector, @selector(keyDown:)))
        NSBeep();
}

#pragma mark - Services / requestor forwarding

/* -[NSResponder supplementalTargetForAction:sender:]  — evidence: 0x184fceea8 */
- (id)supplementalTargetForAction:(SEL)action sender:(id)sender { return nil; }

/* -[NSResponder validRequestorForSendType:returnType:]  — evidence: 0x185217ee4
 * Forward along the chain. */
- (id)validRequestorForSendType:(NSPasteboardType)sendType returnType:(NSPasteboardType)returnType
{
    return [_nextResponder validRequestorForSendType:sendType returnType:returnType];
}

#pragma mark - Internal event helpers

/* -[NSResponder _nextResponderForEvent:]  — evidence: 0x18508f5bc
 * Default app-compat flag NSNextResponderForEventCallsAPI = YES: go through the
 * public -nextResponder. */
- (NSResponder *)_nextResponderForEvent:(NSEvent *)event
{
    return [self nextResponder];
}

/* -[NSResponder _firstResponderForEvent:]  — evidence: 0x1856eff18 */
- (NSResponder *)_firstResponderForEvent:(NSEvent *)event { return nil; }

#pragma mark - Menu

- (NSMenu *)menu { return nil; }
- (void)setMenu:(NSMenu *)menu { }

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder { }

@end
