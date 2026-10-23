/* Sheets and alerts as AppKit has them on the Mac, replacing what GNUstep does (it runs a sheet as a modal session that blocks the caller, puts it in the middle of the screen and has no endSheet on
 * NSWindow). Measured on the Mac with a test program (accessibility tree and captures of an NSWindow sheet and of an NSAlert as a sheet and as a modal window):
 *  - a sheet is not modal in the caller's sense: beginSheet:completionHandler: returns at once and the handler runs when endSheet:returnCode: is called; the sheet is centred on its window (the title bar
 *    included), the window below does not answer while it is there; corners of 12 pt, the window colour for the fill (27 on the test machine: the wallpaper tinted dark window colour);
 *  - an alert: 260 wide, 292 when its accessory view needs more (accessory width + 30); a modal alert has the application's icon 66 x 66 centred at y 19, then the message (13 pt bold) at y 99 and the
 *    informative text (13 pt) 8 pt under it, both centred in 218 pt (W - 42), the accessory view 14 pt under, the buttons 112 x 30 (two side by side with 6 between, centred, the first one on the right)
 *    14 pt under the last item and 15 pt from the bottom; as a sheet there is no icon and the message is at y 19; the corners are 22 pt, the material is the glass of the window server.
 * Not measured: alerts of three or more buttons (they are put side by side here), the dimming of the window under a sheet, the arrows and the animations. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <GNUstepGUI/GSDisplayServer.h>

@interface GSDisplayServer (WsdSheets) - (void) wsdGlassSlot: (int)slot : (int)win : (NSRect)r : (int)radius : (int)mode; - (void) wsdWindowCorners: (int)radius : (int)win; @end
static char kSheetOf, kParentOf, kHandlerOf;
extern NSImage *WsdGenericAppIcon(void);

/* ---- sheets ---- */
typedef void (^WsdSheetHandler)(NSInteger);
static void wsdBeginSheet(NSWindow *parent, NSWindow *sheet, WsdSheetHandler handler)
{
	if (!parent || !sheet || objc_getAssociatedObject(parent, &kSheetOf)) return;
	objc_setAssociatedObject(parent, &kSheetOf, sheet, OBJC_ASSOCIATION_RETAIN); objc_setAssociatedObject(sheet, &kParentOf, parent, OBJC_ASSOCIATION_ASSIGN);
	if (handler) objc_setAssociatedObject(sheet, &kHandlerOf, [[handler copy] autorelease], OBJC_ASSOCIATION_RETAIN);
	[[NSNotificationCenter defaultCenter] postNotificationName: NSWindowWillBeginSheetNotification object: parent];
	NSRect pf = [parent frame], sf = [sheet frame]; sf.origin = NSMakePoint(NSMidX(pf) - sf.size.width / 2, NSMidY(pf) - sf.size.height / 2); [sheet setFrame: sf display: YES];
	[sheet setLevel: [parent level] + 1]; [sheet makeKeyAndOrderFront: nil];                 /* one level above the window it is on, so that it stays above it */
	id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdWindowCorners::)]) [srv wsdWindowCorners: 12 : (int)[sheet windowNumber]];
	if (getenv("WSD_DEBUG")) NSLog(@"sheet %@ visible %d key %d frame %@ parent %@", sheet, (int)[sheet isVisible], (int)[sheet isKeyWindow], NSStringFromRect([sheet frame]), parent);
}
static void wsdEndSheet(NSWindow *parent, NSInteger rc)
{
	NSWindow *sheet = objc_getAssociatedObject(parent, &kSheetOf); if (!sheet) return;
	WsdSheetHandler h = objc_getAssociatedObject(sheet, &kHandlerOf); [[sheet retain] autorelease]; objc_setAssociatedObject(parent, &kSheetOf, nil, OBJC_ASSOCIATION_RETAIN); objc_setAssociatedObject(sheet, &kParentOf, nil, OBJC_ASSOCIATION_ASSIGN);
	[sheet orderOut: nil]; [parent makeKeyAndOrderFront: nil]; if (h) { [[h retain] autorelease]; objc_setAssociatedObject(sheet, &kHandlerOf, nil, OBJC_ASSOCIATION_RETAIN); h(rc); }
	[[NSNotificationCenter defaultCenter] postNotificationName: NSWindowDidEndSheetNotification object: parent];
}
static void wsdWinBeginSheet(NSWindow *self, SEL _cmd, NSWindow *sheet, WsdSheetHandler handler) { wsdBeginSheet(self, sheet, handler); }
static void wsdWinEndSheetRC(NSWindow *self, SEL _cmd, NSWindow *sheet, NSInteger rc) { NSWindow *p = objc_getAssociatedObject(sheet, &kParentOf) ?: self; wsdEndSheet(p, rc); }
static void wsdWinEndSheet(NSWindow *self, SEL _cmd, NSWindow *sheet) { wsdWinEndSheetRC(self, _cmd, sheet, NSModalResponseOK); }
static NSWindow *wsdAttachedSheet(NSWindow *self, SEL _cmd) { return objc_getAssociatedObject(self, &kSheetOf); }
static NSWindow *wsdSheetParent(NSWindow *self, SEL _cmd) { return objc_getAssociatedObject(self, &kParentOf); }
static BOOL wsdIsSheet(NSWindow *self, SEL _cmd) { return objc_getAssociatedObject(self, &kParentOf) != nil; }
static void wsdAppBeginSheet(NSApplication *self, SEL _cmd, NSWindow *sheet, NSWindow *win, id delegate, SEL end, void *ctx)
{
	wsdBeginSheet(win, sheet, ^(NSInteger rc) { if (delegate && end && [delegate respondsToSelector: end]) ((void (*)(id, SEL, id, NSInteger, void *))objc_msgSend)(delegate, end, sheet, rc, ctx); });
}
static void wsdAppEndSheetRC(NSApplication *self, SEL _cmd, NSWindow *sheet, NSInteger rc) { NSWindow *p = objc_getAssociatedObject(sheet, &kParentOf); if (p) wsdEndSheet(p, rc); }
static void wsdAppEndSheet(NSApplication *self, SEL _cmd, NSWindow *sheet) { wsdAppEndSheetRC(self, _cmd, sheet, NSModalResponseOK); }

/* the window below a sheet does not answer: its mouse and key events are dropped */
static IMP origSendEvent;
static void wsdSendEvent(NSWindow *self, SEL _cmd, NSEvent *e)
{
	if (objc_getAssociatedObject(self, &kSheetOf)) { NSEventType t = [e type]; if (t == NSLeftMouseDown || t == NSRightMouseDown || t == NSKeyDown || t == NSOtherMouseDown) { NSBeep(); return; } }
	((void (*)(id, SEL, NSEvent *))origSendEvent)(self, _cmd, e);
}

/* ---- alerts ---- */
@interface WsdAlertButtons : NSObject { @public NSWindow *panel; NSWindow *parent; BOOL sheet; NSInteger rc; } - (void) pressed: (id)b; @end
@implementation WsdAlertButtons
- (void) pressed: (id)b { rc = [b tag]; if (sheet && parent) wsdEndSheet(parent, rc); else [NSApp stopModalWithCode: rc]; }
@end
/* a borderless panel is not key by default: the alert must be */
@interface WsdAlertPanel : NSPanel @end
@implementation WsdAlertPanel - (BOOL) canBecomeKeyWindow { return YES; } - (BOOL) canBecomeMainWindow { return NO; } @end
@interface WsdAlertView : NSView @end
@implementation WsdAlertView - (BOOL) isFlipped { return YES; } - (BOOL) isOpaque { return NO; } - (void) drawRect: (NSRect)r { [[NSColor clearColor] set]; NSRectFillUsingOperation(r, NSCompositeCopy); } @end

static CGFloat TextHeight(NSString *s, NSDictionary *a, CGFloat w)
{
	if (![s length]) return 0; NSTextStorage *st = [[[NSTextStorage alloc] initWithString: s attributes: a] autorelease]; NSLayoutManager *lm = [[[NSLayoutManager alloc] init] autorelease]; NSTextContainer *tc = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(w, 10000)] autorelease];
	[tc setLineFragmentPadding: 0]; [lm addTextContainer: tc]; [st addLayoutManager: lm]; return ceil([lm usedRectForTextContainer: tc].size.height);
}
/* the borderless panel that holds the alert; sheet = no icon, the message at the top */
static NSPanel *BuildAlert(NSAlert *al, BOOL sheet, WsdAlertButtons *tg)
{
	NSView *acc = [al accessoryView]; NSSize as = acc ? [acc frame].size : NSZeroSize; CGFloat W = MAX(260, acc ? as.width + 30 : 0), TW = W - 42; NSString *title = [al messageText] ?: @"", *info = [al informativeText] ?: @"";
	NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease]; [ps setAlignment: NSCenterTextAlignment];
	NSDictionary *ta = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor controlTextColor], NSParagraphStyleAttributeName: ps }, *ba = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor controlTextColor], NSParagraphStyleAttributeName: ps };
	CGFloat th = MAX(18, TextHeight(title, ta, TW)), ih = [info length] ? MAX(18, TextHeight(info, ba, TW)) : 0, y = sheet ? 19 : 99, titleY = y; y += th; CGFloat infoY = y + 8; if (ih) y = infoY + ih;
	CGFloat accY = y + 14; if (acc) y = accY + as.height; CGFloat btnY = y + 14, H = btnY + 30 + 15;
	NSPanel *p = [[[WsdAlertPanel alloc] initWithContentRect: NSMakeRect(0, 0, W, H) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO] autorelease]; [p setOpaque: NO]; [p setBackgroundColor: [NSColor clearColor]]; [p setHasShadow: NO]; [p setReleasedWhenClosed: NO];
	WsdAlertView *back = [[[WsdAlertView alloc] initWithFrame: NSMakeRect(0, 0, W, H)] autorelease]; [p setContentView: back];
	if (!sheet) { NSImage *ic = [al icon]; if (!ic || ic == [NSApp applicationIconImage] || [[ic name] isEqualToString: @"NSApplicationIcon"]) ic = WsdGenericAppIcon(); if (ic) { NSImageView *iv = [[[NSImageView alloc] initWithFrame: NSMakeRect((W - 66) / 2, 19, 66, 66)] autorelease]; [iv setImage: ic]; [iv setImageScaling: NSImageScaleProportionallyUpOrDown]; [back addSubview: iv]; } }
	NSTextField *(^label)(NSString *, NSDictionary *, NSRect) = ^NSTextField *(NSString *t, NSDictionary *a, NSRect f) { NSTextField *l = [[[NSTextField alloc] initWithFrame: f] autorelease]; [l setBezeled: NO]; [l setDrawsBackground: NO]; [l setEditable: NO]; [l setSelectable: NO]; [l setAttributedStringValue: [[[NSAttributedString alloc] initWithString: t attributes: a] autorelease]]; return l; };
	[back addSubview: label(title, ta, NSMakeRect(21, titleY, TW, th))]; if (ih) [back addSubview: label(info, ba, NSMakeRect(21, infoY, TW, ih))];
	if (acc) { [acc setFrameOrigin: NSMakePoint((W - as.width) / 2, accY)]; [back addSubview: acc]; }
	NSArray *btns = [al buttons]; NSUInteger n = [btns count]; CGFloat bw = n > 2 ? (W - 30 - 6 * (n - 1)) / n : 112, total = n * bw + (n - 1) * 6, x0 = (W - total) / 2;
	for (NSUInteger i = 0; i < n; i++) {                                           /* the first button is the rightmost, as on macOS */
		NSButton *src = [btns objectAtIndex: i]; NSButton *b = [[[NSButton alloc] initWithFrame: NSMakeRect(x0 + (n - 1 - i) * (bw + 6), btnY, bw, 30)] autorelease];
		[b setTitle: [src title]]; [b setBezelStyle: NSRoundedBezelStyle]; [b setTag: NSAlertFirstButtonReturn + (NSInteger)i]; [b setTarget: tg]; [b setAction: @selector(pressed:)];
		if (i == 0) [b setKeyEquivalent: @"\r"]; else if (![[src keyEquivalent] length] && [[[src title] lowercaseString] isEqualToString: @"cancel"]) [b setKeyEquivalent: @"\033"]; [back addSubview: b];
	}
	return p;
}
static void Glass(NSWindow *w) { id srv = GSCurrentServer(); NSRect b = [[w contentView] bounds]; if ([srv respondsToSelector: @selector(wsdGlassSlot:::::)]) [srv wsdGlassSlot: 1 : (int)[w windowNumber] : b : 22 : 1]; }
static IMP origRunModal;
static NSInteger wsdAlertRunModal(NSAlert *al, SEL _cmd)
{
	if (![[al buttons] count]) return origRunModal ? ((NSInteger (*)(id, SEL))origRunModal)(al, _cmd) : 0;
	WsdAlertButtons *tg = [[[WsdAlertButtons alloc] init] autorelease]; NSPanel *p = BuildAlert(al, NO, tg); [p setLevel: NSModalPanelWindowLevel]; [p center]; [p makeKeyAndOrderFront: nil]; Glass(p);
	NSInteger rc = [NSApp runModalForWindow: p]; [p orderOut: nil]; return rc;
}
static void wsdAlertSheet(NSAlert *al, SEL _cmd, NSWindow *parent, WsdSheetHandler handler)
{
	if (!parent) { NSInteger rc = wsdAlertRunModal(al, _cmd); if (handler) handler(rc); return; }
	WsdAlertButtons *tg = [[[WsdAlertButtons alloc] init] autorelease]; tg->sheet = YES; tg->parent = parent; NSPanel *p = BuildAlert(al, YES, tg); objc_setAssociatedObject(p, &kHandlerOf, nil, OBJC_ASSOCIATION_RETAIN); objc_setAssociatedObject(p, "buttons", tg, OBJC_ASSOCIATION_RETAIN);
	wsdBeginSheet(parent, p, handler); Glass(p);
}
static void wsdAlertSheetLegacy(NSAlert *al, SEL _cmd, NSWindow *parent, id delegate, SEL end, void *ctx)
{
	wsdAlertSheet(al, _cmd, parent, ^(NSInteger rc) { if (delegate && end && [delegate respondsToSelector: end]) ((void (*)(id, SEL, id, NSInteger, void *))objc_msgSend)(delegate, end, al, rc, ctx); });
}

void WsdInstallSheets(void)
{
	static BOOL done; if (done) return; done = YES; Class w = [NSWindow class], a = [NSApplication class], al = [NSAlert class];
	class_replaceMethod(w, @selector(beginSheet:completionHandler:), (IMP)wsdWinBeginSheet, "v@:@@?"); class_replaceMethod(w, @selector(endSheet:), (IMP)wsdWinEndSheet, "v@:@"); class_replaceMethod(w, @selector(endSheet:returnCode:), (IMP)wsdWinEndSheetRC, "v@:@q");
	class_replaceMethod(w, @selector(attachedSheet), (IMP)wsdAttachedSheet, "@@:"); class_replaceMethod(w, @selector(sheetParent), (IMP)wsdSheetParent, "@@:"); class_replaceMethod(w, @selector(isSheet), (IMP)wsdIsSheet, "c@:");
	class_replaceMethod(a, @selector(beginSheet:modalForWindow:modalDelegate:didEndSelector:contextInfo:), (IMP)wsdAppBeginSheet, "v@:@@@:^v"); class_replaceMethod(a, @selector(endSheet:), (IMP)wsdAppEndSheet, "v@:@"); class_replaceMethod(a, @selector(endSheet:returnCode:), (IMP)wsdAppEndSheetRC, "v@:@q");
	Method se = class_getInstanceMethod(w, @selector(sendEvent:)); if (se && !origSendEvent) origSendEvent = method_setImplementation(se, (IMP)wsdSendEvent);
	Method rm = class_getInstanceMethod(al, @selector(runModal)); if (rm && !origRunModal) origRunModal = method_getImplementation(rm); class_replaceMethod(al, @selector(runModal), (IMP)wsdAlertRunModal, "q@:");
	class_replaceMethod(al, @selector(beginSheetModalForWindow:completionHandler:), (IMP)wsdAlertSheet, "v@:@@?"); class_replaceMethod(al, @selector(beginSheetModalForWindow:modalDelegate:didEndSelector:contextInfo:), (IMP)wsdAlertSheetLegacy, "v@:@@:^v");
}
