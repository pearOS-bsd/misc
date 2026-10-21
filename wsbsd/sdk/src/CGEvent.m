/* CGEvent values and -[NSEvent eventWithCGEvent:]. The characters of a key event come from the US layout (ANSI key codes); the Option key adds no dead-key or symbol layer. */
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <wsbsd/CGEvent.h>
#include <Carbon/Carbon.h>

/* CGEventRef and CGEventSourceRef are CF types: callers CFRelease them (TextMate does), so they are objects whose payload follows the isa */
@interface WsbsdCGObject : NSObject @end
@implementation WsbsdCGObject @end
struct __CGEventSource { Class isa; int state; };
struct __CGEvent { Class isa; CGEventType type; CGKeyCode key; CGEventFlags flags; CGPoint where; uint32_t button; UniChar chars[4]; size_t nchars; };

CGEventSourceRef CGEventSourceCreate(CGEventSourceStateID s) { struct __CGEventSource *o = (struct __CGEventSource *)(__bridge_retained void *)NSAllocateObject([WsbsdCGObject class], sizeof *o - sizeof(Class), NULL); o->state = s; return o; }
CGEventRef CGEventCreate(CGEventSourceRef s) { (void)s; return (CGEventRef)(__bridge_retained void *)NSAllocateObject([WsbsdCGObject class], sizeof(struct __CGEvent) - sizeof(Class), NULL); }
CGEventRef CGEventCreateKeyboardEvent(CGEventSourceRef s, CGKeyCode k, bool down) { struct __CGEvent *e = (struct __CGEvent *)CGEventCreate(s); e->type = down ? kCGEventKeyDown : kCGEventKeyUp; e->key = k; return e; }
CGEventRef CGEventCreateMouseEvent(CGEventSourceRef s, CGEventType t, CGPoint p, uint32_t b) { struct __CGEvent *e = (struct __CGEvent *)CGEventCreate(s); e->type = t; e->where = p; e->button = b; return e; }
CGEventType CGEventGetType(CGEventRef e) { return e ? e->type : kCGEventNull; }
void CGEventSetFlags(CGEventRef e, CGEventFlags f) { if (e) e->flags = f; }
CGEventFlags CGEventGetFlags(CGEventRef e) { return e ? e->flags : 0; }
int64_t CGEventGetIntegerValueField(CGEventRef e, CGEventField f) { return e && f == kCGKeyboardEventKeycode ? e->key : 0; }
void CGEventSetIntegerValueField(CGEventRef e, CGEventField f, int64_t v) { if (e && f == kCGKeyboardEventKeycode) e->key = (CGKeyCode)v; }
CGPoint CGEventGetLocation(CGEventRef e) { return e ? e->where : CGPointZero; }
void CGEventKeyboardSetUnicodeString(CGEventRef e, size_t n, const UniChar *s) { if (!e) return; e->nchars = n > 4 ? 4 : n; memcpy(e->chars, s, e->nchars * sizeof(UniChar)); }
void CGEventPost(CGEventTapLocation t, CGEventRef e) { (void)t; (void)e; }
CGEventFlags CGEventSourceFlagsState(CGEventSourceStateID s) { (void)s; return 0; }

/* US layout: key code -> character without and with Shift */
static unichar USChar(CGKeyCode k, BOOL shift)
{
	static const char *plain = "asdfhgzxcv\0bqweryt123465=97-80]ou[ip\rlj'k;\\,/nm.\t `";           /* 0x00 .. 0x32 */
	static const char *upper = "ASDFHGZXCV\0BQWERYT!@#$^%+(&_*)}OU{IP\rLJ\"K:|<?NM>\t ~";
	if (k > 0x32) return 0; unichar c = (unichar)(shift ? upper : plain)[k]; return c;
}
@implementation NSEvent (WsbsdCGEvent)
+ (NSEvent *)eventWithCGEvent:(CGEventRef)e
{
	if (!e) return nil; NSUInteger fl = 0;
	if (e->flags & kCGEventFlagMaskShift) fl |= NSShiftKeyMask; if (e->flags & kCGEventFlagMaskControl) fl |= NSControlKeyMask; if (e->flags & kCGEventFlagMaskAlternate) fl |= NSAlternateKeyMask;
	if (e->flags & kCGEventFlagMaskCommand) fl |= NSCommandKeyMask; if (e->flags & kCGEventFlagMaskAlphaShift) fl |= NSAlphaShiftKeyMask;
	if (e->type != kCGEventKeyDown && e->type != kCGEventKeyUp) return nil;
	NSString *chars; BOOL shift = (e->flags & kCGEventFlagMaskShift) != 0, caps = (e->flags & kCGEventFlagMaskAlphaShift) != 0;
	if (e->nchars) chars = [NSString stringWithCharacters: e->chars length: e->nchars];
	else {
		unichar c = 0;
		switch (e->key) {
		case kVK_Return: case kVK_ANSI_KeypadEnter: c = '\r'; break; case kVK_Tab: c = '\t'; break; case kVK_Space: c = ' '; break; case kVK_Delete: c = 0x7f; break; case kVK_Escape: c = 0x1b; break;
		case kVK_LeftArrow: c = NSLeftArrowFunctionKey; break; case kVK_RightArrow: c = NSRightArrowFunctionKey; break; case kVK_UpArrow: c = NSUpArrowFunctionKey; break; case kVK_DownArrow: c = NSDownArrowFunctionKey; break;
		case kVK_Home: c = NSHomeFunctionKey; break; case kVK_End: c = NSEndFunctionKey; break; case kVK_PageUp: c = NSPageUpFunctionKey; break; case kVK_PageDown: c = NSPageDownFunctionKey; break; case kVK_ForwardDelete: c = NSDeleteFunctionKey; break;
		case kVK_F1: c = NSF1FunctionKey; break; case kVK_F2: c = NSF2FunctionKey; break; case kVK_F3: c = NSF3FunctionKey; break; case kVK_F4: c = NSF4FunctionKey; break; case kVK_F5: c = NSF5FunctionKey; break; case kVK_F6: c = NSF6FunctionKey; break;
		case kVK_F7: c = NSF7FunctionKey; break; case kVK_F8: c = NSF8FunctionKey; break; case kVK_F9: c = NSF9FunctionKey; break; case kVK_F10: c = NSF10FunctionKey; break; case kVK_F11: c = NSF11FunctionKey; break; case kVK_F12: c = NSF12FunctionKey; break;
		default: c = USChar(e->key, shift); if (caps && !shift && c >= 'a' && c <= 'z') c -= 32; else if (caps && shift && c >= 'A' && c <= 'Z') c += 32;
			if ((fl & NSControlKeyMask) && c >= 'a' && c <= 'z') c -= 96; else if ((fl & NSControlKeyMask) && c >= 'A' && c <= 'Z') c -= 64; break;
		}
		chars = c ? [NSString stringWithCharacters: &c length: 1] : @"";
	}
	NSString *ign = chars; if (!e->nchars) { unichar b = USChar(e->key, NO); if (b && e->key < 0x33) ign = [NSString stringWithCharacters: &b length: 1]; }
	return [NSEvent keyEventWithType: e->type == kCGEventKeyDown ? NSKeyDown : NSKeyUp location: NSZeroPoint modifierFlags: fl timestamp: 0 windowNumber: 0 context: nil characters: chars charactersIgnoringModifiers: ign isARepeat: NO keyCode: e->key];
}
- (CGEventRef)CGEvent
{
	NSEventType t = [self type]; if (t != NSKeyDown && t != NSKeyUp) return NULL;
	struct __CGEvent *e = (struct __CGEvent *)CGEventCreateKeyboardEvent(NULL, [self keyCode], t == NSKeyDown); NSUInteger m = [self modifierFlags]; CGEventFlags f = 0;
	if (m & NSShiftKeyMask) f |= kCGEventFlagMaskShift; if (m & NSControlKeyMask) f |= kCGEventFlagMaskControl; if (m & NSAlternateKeyMask) f |= kCGEventFlagMaskAlternate; if (m & NSCommandKeyMask) f |= kCGEventFlagMaskCommand;
	e->flags = f; return e;
}
@end
