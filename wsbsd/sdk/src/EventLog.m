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

/* WSBSD_SNAPVIEW=ClassName: every 3 seconds the first view of that class is drawn into a bitmap and written to /tmp/wsbsd-snap-ClassName.tiff, to tell a view that does not draw from one that is not shown */
__attribute__((constructor(131))) static void WsbsdSnapInit(void)
{
	const char *cn = getenv("WSBSD_SNAPVIEW"); if (!cn) return;
	dispatch_async(dispatch_get_main_queue(), ^{ NSString *name = [NSString stringWithUTF8String: cn];
		[NSTimer scheduledTimerWithTimeInterval: 3 repeats: YES block: ^(NSTimer *t) {
			Class c = NSClassFromString(name); if (!c) return;
			for (NSWindow *w in [NSApp windows]) {
				NSMutableArray *todo = [NSMutableArray arrayWithObject: [w contentView]];
				while ([todo count]) { NSView *v = [todo lastObject]; [todo removeLastObject]; if (!v) continue;
					if ([v isKindOfClass: c]) {
						NSBitmapImageRep *rep = [v bitmapImageRepForCachingDisplayInRect: [v bounds]]; if (!rep) return;
						[v cacheDisplayInRect: [v bounds] toBitmapImageRep: rep];
						NSData *d = [rep TIFFRepresentation]; [d writeToFile: [NSString stringWithFormat: @"/tmp/wsbsd-snap-%@.tiff", name] atomically: YES];
						fprintf(stderr, "snapshot of %s %.0fx%.0f -> %lu bytes\n", cn, [v bounds].size.width, [v bounds].size.height, (unsigned long)[d length]); return;
					}
					[todo addObjectsFromArray: [v subviews]]; }
			}
		}];
	});
}
