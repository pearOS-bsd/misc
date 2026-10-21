/* -[NSTextInputContext handleEvent:] of gnustep-gui does nothing. The input context of a text view turns a key event into the calls of the NSTextInputClient protocol: the characters through insertText:replacementRange:,
 * the editing keys through doCommandBySelector: with the standard key binding of the key (arrows, delete, return, tab, escape; Shift extends the selection, Option moves by word, Command by line). */
#import <AppKit/AppKit.h>

static SEL CommandFor(unichar c, NSUInteger m)
{
	BOOL shift = (m & NSShiftKeyMask) != 0, opt = (m & NSAlternateKeyMask) != 0, cmd = (m & NSCommandKeyMask) != 0;
	switch (c) {
	case NSLeftArrowFunctionKey:  return cmd ? (shift ? @selector(moveToBeginningOfLineAndModifySelection:) : @selector(moveToBeginningOfLine:)) : opt ? (shift ? @selector(moveWordLeftAndModifySelection:) : @selector(moveWordLeft:)) : shift ? @selector(moveLeftAndModifySelection:) : @selector(moveLeft:);
	case NSRightArrowFunctionKey: return cmd ? (shift ? @selector(moveToEndOfLineAndModifySelection:) : @selector(moveToEndOfLine:)) : opt ? (shift ? @selector(moveWordRightAndModifySelection:) : @selector(moveWordRight:)) : shift ? @selector(moveRightAndModifySelection:) : @selector(moveRight:);
	case NSUpArrowFunctionKey:    return cmd ? (shift ? @selector(moveToBeginningOfDocumentAndModifySelection:) : @selector(moveToBeginningOfDocument:)) : shift ? @selector(moveUpAndModifySelection:) : @selector(moveUp:);
	case NSDownArrowFunctionKey:  return cmd ? (shift ? @selector(moveToEndOfDocumentAndModifySelection:) : @selector(moveToEndOfDocument:)) : shift ? @selector(moveDownAndModifySelection:) : @selector(moveDown:);
	case NSHomeFunctionKey:       return shift ? @selector(moveToBeginningOfDocumentAndModifySelection:) : @selector(scrollToBeginningOfDocument:);
	case NSEndFunctionKey:        return shift ? @selector(moveToEndOfDocumentAndModifySelection:) : @selector(scrollToEndOfDocument:);
	case NSPageUpFunctionKey:     return shift ? @selector(pageUpAndModifySelection:) : @selector(pageUp:);
	case NSPageDownFunctionKey:   return shift ? @selector(pageDownAndModifySelection:) : @selector(pageDown:);
	case NSDeleteFunctionKey:     return opt ? @selector(deleteWordForward:) : @selector(deleteForward:);
	case 0x7f:                    return cmd ? @selector(deleteToBeginningOfLine:) : opt ? @selector(deleteWordBackward:) : @selector(deleteBackward:);
	case '\r': case 0x03:         return @selector(insertNewline:);
	case '\t':                    return @selector(insertTab:);
	case 0x19:                    return @selector(insertBacktab:);
	case 0x1b:                    return @selector(cancelOperation:);
	}
	return NULL;
}

@implementation NSTextInputContext (WsbsdHandleEvent)
- (BOOL)handleEvent:(NSEvent *)event
{
	if ([event type] != NSKeyDown) return NO;
	id<NSTextInputClient> client = [self client]; if (!client) return NO;
	NSString *chars = [event characters]; if (![chars length]) return NO;
	NSUInteger m = [event modifierFlags]; unichar c = [chars characterAtIndex: 0];
	if ([event keyCode] == 48 && (m & NSShiftKeyMask)) c = 0x19;                     /* Shift-Tab */
	SEL cmd = CommandFor(c, m);
	if (cmd) { if ([(id)client respondsToSelector: @selector(doCommandBySelector:)]) { [(id)client doCommandBySelector: cmd]; return YES; } return NO; }
	if (m & (NSCommandKeyMask | NSControlKeyMask)) return NO;
	if (c < 0x20 || (c >= 0xF700 && c <= 0xF8FF)) return NO;
	[client insertText: chars replacementRange: NSMakeRange(NSNotFound, 0)];
	return YES;
}
@end
