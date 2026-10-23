/* Sheets, alerts and popovers as the Mac has them (WsdSheets.m, WsdPopover.m): beginSheet does not block, the sheet is centred on its parent and ends with the code, NSAlert sheets call the handler, NSPopover shows next to the rect and closes. */
#import <AppKit/AppKit.h>
@interface NSWindow (S) - (void)endSheet:(NSWindow *)s returnCode:(NSInteger)c; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
#define STEP(n) fprintf(stderr, "step %s\n", n)
static void spin(double s)                                                                  /* the backend reports window moves as events: they have to be taken from the queue */
{
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow: s];
	while ([end timeIntervalSinceNow] > 0) { NSEvent *e = [NSApp nextEventMatchingMask: NSAnyEventMask untilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02] inMode: NSDefaultRunLoopMode dequeue: YES]; if (e) [NSApp sendEvent: e]; }
}
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSWindow *p = [[NSWindow alloc] initWithContentRect: NSMakeRect(200, 200, 600, 400) styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing: NSBackingStoreBuffered defer: NO]; STEP("1"); [p makeKeyAndOrderFront: nil]; spin(0.2);
		NSWindow *s = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 300, 100) styleMask: NSWindowStyleMaskTitled backing: NSBackingStoreBuffered defer: NO];
		__block NSInteger code = -999;
		[p beginSheet: s completionHandler: ^(NSModalResponse r) { code = r; }]; spin(0.2);
		CHECK([p attachedSheet] == s); CHECK([s sheetParent] == p); CHECK([s isVisible]);
		fprintf(stderr, "sheet %s parent %s\n", [NSStringFromRect([s frame]) UTF8String], [NSStringFromRect([p frame]) UTF8String]); CHECK(fabs(NSMidX([s frame]) - NSMidX([p frame])) < 1.5);
		STEP("3"); [p endSheet: s returnCode: NSModalResponseOK]; spin(0.2);
		CHECK(code == NSModalResponseOK); CHECK([p attachedSheet] == nil); CHECK(![s isVisible]);
		NSAlert *al = [[NSAlert alloc] init]; [al setMessageText: @"Sure?"]; [al addButtonWithTitle: @"OK"]; [al addButtonWithTitle: @"Cancel"];
		STEP("4"); __block NSInteger ar = -1; [al beginSheetModalForWindow: p completionHandler: ^(NSModalResponse r) { ar = r; }]; spin(0.3);
		STEP("4b"); NSWindow *as = [p attachedSheet]; CHECK(as != nil);
		[p endSheet: as returnCode: NSAlertSecondButtonReturn]; spin(0.2); CHECK(ar == NSAlertSecondButtonReturn);
		STEP("5"); NSPopover *po = [[NSPopover alloc] init]; NSViewController *vc = [[NSViewController alloc] init]; [vc setView: [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 200, 120)]]; [po setContentViewController: vc]; [po setBehavior: NSPopoverBehaviorApplicationDefined];
		[po showRelativeToRect: NSMakeRect(10, 10, 30, 20) ofView: [p contentView] preferredEdge: NSMaxYEdge]; spin(0.2);
		CHECK([po isShown]); [po close]; spin(0.1); CHECK(![po isShown]);
	}
	printf(fails ? "sheets: %d failed\n" : "sheets ok\n", fails);
	return fails != 0;
}
