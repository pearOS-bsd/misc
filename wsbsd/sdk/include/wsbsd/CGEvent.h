/* Core Graphics events: keyboard and mouse events as plain values (CGEventCreateKeyboardEvent ... CGEventGetFlags). Posting is not supported here (no event tap system), a posted event is dropped.
 * Opal has no CGEvent; implemented in sdk/src/CGEvent.m together with -[NSEvent eventWithCGEvent:], which gives the characters of the US layout. */
#ifndef WSBSD_CGEVENT_H
#define WSBSD_CGEVENT_H
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef uint16_t CGKeyCode;
typedef uint64_t CGEventFlags;
typedef uint32_t CGEventType;
typedef int CGEventField;                         /* as Opal declares it */
typedef struct __CGEvent *CGEventRef;
typedef struct __CGEventSource *CGEventSourceRef;
typedef int32_t CGEventSourceStateID;
typedef uint32_t CGEventTapLocation;
enum { kCGEventNull = 0, kCGEventLeftMouseDown = 1, kCGEventLeftMouseUp = 2, kCGEventRightMouseDown = 3, kCGEventRightMouseUp = 4, kCGEventMouseMoved = 5, kCGEventKeyDown = 10, kCGEventKeyUp = 11, kCGEventFlagsChanged = 12 };
enum { kCGEventFlagMaskAlphaShift = 0x10000, kCGEventFlagMaskShift = 0x20000, kCGEventFlagMaskControl = 0x40000, kCGEventFlagMaskAlternate = 0x80000, kCGEventFlagMaskCommand = 0x100000,
       kCGEventFlagMaskHelp = 0x400000, kCGEventFlagMaskSecondaryFn = 0x800000, kCGEventFlagMaskNumericPad = 0x200000 };
enum { kCGKeyboardEventKeycode = 9, kCGKeyboardEventAutorepeat = 8 };
enum { kCGEventSourceStateCombinedSessionState = 0, kCGEventSourceStateHIDSystemState = 1, kCGEventSourceStatePrivate = -1 };
enum { kCGHIDEventTap = 0, kCGSessionEventTap = 1, kCGAnnotatedSessionEventTap = 2 };
CGEventSourceRef CGEventSourceCreate(CGEventSourceStateID stateID);
CGEventRef CGEventCreate(CGEventSourceRef source);
CGEventRef CGEventCreateKeyboardEvent(CGEventSourceRef source, CGKeyCode virtualKey, bool keyDown);
CGEventRef CGEventCreateMouseEvent(CGEventSourceRef source, CGEventType mouseType, CGPoint mouseCursorPosition, uint32_t mouseButton);
CGEventType CGEventGetType(CGEventRef event);
void CGEventSetFlags(CGEventRef event, CGEventFlags flags);
CGEventFlags CGEventGetFlags(CGEventRef event);
int64_t CGEventGetIntegerValueField(CGEventRef event, CGEventField field);
void CGEventSetIntegerValueField(CGEventRef event, CGEventField field, int64_t value);
CGPoint CGEventGetLocation(CGEventRef event);
void CGEventKeyboardSetUnicodeString(CGEventRef event, size_t stringLength, const UniChar *unicodeString);
void CGEventPost(CGEventTapLocation tap, CGEventRef event);
CGEventFlags CGEventSourceFlagsState(CGEventSourceStateID stateID);
#ifdef __cplusplus
}
#endif
#ifdef __OBJC__
#import <AppKit/NSEvent.h>
@interface NSEvent (WsbsdCGEvent)
+ (NSEvent *)eventWithCGEvent:(CGEventRef)cgEvent;
- (CGEventRef)CGEvent;                  /* a new event of the same type, key code and modifiers (not owned: release it with CFRelease) */
@end
#endif
#endif
