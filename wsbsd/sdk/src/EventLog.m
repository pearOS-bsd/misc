/* WSBSD_LOGEVENTS=1: every key event the application sends is printed with the key window and its first responder. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@implementation NSApplication (WsbsdEventLog)
- (void)wsbsdLogSendEvent:(NSEvent *)e
{
	NSEventType t = [e type];
	if (t == NSKeyDown || t == NSKeyUp) {
		NSWindow *w = [self keyWindow];
		fprintf(stderr, "event key %s code %d chars '%s' mods %lx -> key window '%s' responder %s\n", t == NSKeyDown ? "down" : "up", (int)[e keyCode], [[e characters] UTF8String] ?: "", (unsigned long)[e modifierFlags],
			[[w title] UTF8String] ?: "(none)", w ? object_getClassName([w firstResponder]) : "-");
	}
	[self wsbsdLogSendEvent: e];
}
@end

__attribute__((constructor(130))) static void WsbsdEventLogInit(void)
{
	if (!getenv("WSBSD_LOGEVENTS")) return;
	dispatch_async(dispatch_get_main_queue(), ^{                                         /* a class must not be touched from a constructor: its +initialize needs the runtime up */
		Method a = class_getInstanceMethod([NSApplication class], @selector(sendEvent:)), b = class_getInstanceMethod([NSApplication class], @selector(wsbsdLogSendEvent:));
		if (a && b) method_exchangeImplementations(a, b);
	});
}
