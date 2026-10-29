/* The menu bar of the Mac, drawn by every program: the logo item (the Apple menu, with the pear of pearOS in place of the apple) first, the titles on a pitch of title + 22 pt, a translucent
 * pill behind the open menu, no background of its own (the wallpaper shows through), text that is light over a dark wallpaper and dark over a light one. Measured on the Mac (3440 x 1440):
 * the bar is 30 pt, the first item starts at x = 10 and is 34 wide with the logo 16 high centred in it, titles have 11 pt on each side and 13 pt text (the name of the application in bold),
 * the pill is the item's width, 24 high, from y = 3, corner radius 6, white 13 % in the dark. The system menu: rows 24 pt, separators 11, 5 above the first row, 312 wide. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

extern BOOL WsdBarWantsLightText(void);
static NSString *const kPearItem = @"wsd.pear";

/* the pear (pearos-settings, usr/share/extras/pearlogo.svg, one path): 0 move, 1 line, 2 curve, 3 close; the box of the path is x 18.05 .. 201.54, y 3.27 .. 292.57 */
static const double kPear[][7] = {
	{0, 115.0585, 51.2254},
	{2, 138.5134, 46.3713, 153.5157, 27.1532, 153.5817, 3.2681},
	{2, 131.5276, 3.4507, 108.7953, 28.4442, 115.0585, 51.2254},
	{0, 201.5385, 215.5369},
	{2, 161.7327, 215.5369, 131.6596, 178.7674, 141.7072, 139.2774},
	{2, 143.8352, 130.9117, 148.3142, 123.2982, 153.5023, 116.4782},
	{2, 155.9866, 113.2126, 160.9371, 109.8396, 161.1935, 105.4717},
	{2, 162.1161, 89.7765, 148.1020, 74.8623, 135.4995, 67.9802},
	{2, 111.5460, 54.9012, 74.8614, 62.0398, 62.4790, 88.1756},
	{2, 56.9597, 99.8262, 60.3248, 112.5314, 56.0525, 124.3398},
	{2, 49.9242, 141.2805, 37.6175, 152.3673, 28.9143, 167.5800},
	{2, 16.9731, 188.4546, 14.1367, 217.7768, 24.1071, 239.9085},
	{2, 52.8867, 303.7961, 149.4251, 311.1422, 188.4320, 253.2736},
	{2, 195.9519, 242.1171, 201.5009, 229.1655, 201.5385, 215.5369},
	{3},
	{0, 201.5385, 215.5369}
};
static NSBezierPath *PearPath(void)
{
	static NSBezierPath *p; if (p) return p; p = [[NSBezierPath bezierPath] retain];             /* the library is not ARC */
	for (unsigned i = 0; i < sizeof kPear / sizeof kPear[0]; i++) {
		const double *s = kPear[i];
		if (s[0] == 0) [p moveToPoint: NSMakePoint(s[1], s[2])]; else if (s[0] == 1) [p lineToPoint: NSMakePoint(s[1], s[2])];
		else if (s[0] == 2) [p curveToPoint: NSMakePoint(s[5], s[6]) controlPoint1: NSMakePoint(s[1], s[2]) controlPoint2: NSMakePoint(s[3], s[4])]; else [p closePath];
	}
	return p;
}
/* the logo, h high, centred in r */
void WsdDrawPear(NSRect r, double h, NSColor *color, BOOL flipped)
{
	double bw = 201.5385 - 18.0530, bh = 292.5686 - 3.2681, k = h / bh, w = bw * k; NSAffineTransform *t = [NSAffineTransform transform];
	[t translateXBy: NSMidX(r) - w / 2 yBy: flipped ? NSMidY(r) - h / 2 : NSMidY(r) + h / 2]; [t scaleXBy: k yBy: flipped ? k : -k]; [t translateXBy: -18.0530 yBy: -3.2681];
	NSBezierPath *p = [t transformBezierPath: PearPath()]; [color setFill]; [p fill];
}

/* text colour of the bar */
NSColor *WsdBarTextColor(BOOL enabled) { return WsdBarWantsLightText() ? [NSColor colorWithCalibratedWhite: 1 alpha: enabled ? 1.0 : 0.35] : [NSColor colorWithCalibratedWhite: 0 alpha: enabled ? 0.9 : 0.3]; }

/* the item of the logo */
BOOL WsdIsPearItem(NSMenuItem *i) { return [[i representedObject] isEqual: kPearItem]; }
void WsdDrawBarItem(NSMenuItemCell *cell, NSRect f, BOOL highlighted)
{
	NSRect pill = NSMakeRect(f.origin.x, 3, f.size.width, 24); BOOL flipped = [[cell controlView] isFlipped]; if (!flipped) pill.origin.y = [[cell controlView] bounds].size.height - 3 - 24;
	if (highlighted) { [(WsdBarWantsLightText() ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.13] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.12]) setFill]; [[NSBezierPath bezierPathWithRoundedRect: pill xRadius: 6 yRadius: 6] fill]; }
	if (WsdIsPearItem([cell menuItem])) WsdDrawPear(NSMakeRect(f.origin.x, flipped ? -1 : 1, f.size.width, f.size.height), 16, WsdBarTextColor(YES), flipped);
}

/* ---- the system menu (the Apple menu of the Mac): what its rows do ---- */
@interface WsdSystemMenu : NSObject
+ (instancetype)shared;
- (NSMenu *)menu;
@end
@implementation WsdSystemMenu
+ (instancetype)shared { static WsdSystemMenu *s; if (!s) s = [WsdSystemMenu new]; return s; }
/* the name for the log-out row: the full name of the account ("&" stands for the capitalised login name in the password file) */
static NSString *WsdFullName(void) { NSString *n = NSFullUserName(), *u = NSUserName(); if (![n length]) return u; if ([n rangeOfString: @"&"].location != NSNotFound) n = [n stringByReplacingOccurrencesOfString: @"&" withString: [u length] ? [[[u substringToIndex: 1] uppercaseString] stringByAppendingString: [u substringFromIndex: 1]] : u]; return n; }
static void Launch(NSString *path, NSArray *args) { NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: path]; [t setArguments: args ?: @[]]; @try { [t launch]; } @catch (NSException *e) { NSBeep(); } }
static BOOL Confirm(NSString *msg, NSString *info, NSString *button)
{
	NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: msg]; [a setInformativeText: info]; [a addButtonWithTitle: button]; [a addButtonWithTitle: @"Cancel"]; return [a runModal] == NSAlertFirstButtonReturn;
}
- (void)aboutThisMac:(id)s
{
	NSString *rel = [NSString stringWithContentsOfFile: @"/etc/os-release" encoding: NSUTF8StringEncoding error: NULL]; NSString *name = @"pearOS"; NSString *ver = @"";
	for (NSString *l in [rel componentsSeparatedByString: @"\n"]) { if ([l hasPrefix: @"PRETTY_NAME="]) name = [[l substringFromIndex: 12] stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"\""]]; }
	NSTask *t = [[NSTask alloc] init]; NSPipe *p = [NSPipe pipe]; [t setLaunchPath: @"/usr/bin/uname"]; [t setArguments: @[ @"-sr" ]]; [t setStandardOutput: p]; @try { [t launch]; [t waitUntilExit]; ver = [[NSString alloc] initWithData: [[p fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding]; } @catch (NSException *e) {}
	NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: name]; [a setInformativeText: [NSString stringWithFormat: @"%@\nHost: %@", [ver stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]], [[NSProcessInfo processInfo] hostName]]]; [a runModal];
}
- (void)openSettings:(id)s { for (NSString *a in @[ @"/System/Applications/System Settings.app", @"/Applications/System Settings.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; return; } NSBeep(); }
- (void)openAppStore:(id)s { for (NSString *a in @[ @"/System/Applications/App Store.app", @"/Applications/App Store.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; return; } NSBeep(); }
- (void)clearRecents:(id)s { [[NSDocumentController sharedDocumentController] clearRecentDocuments: nil]; }
- (void)forceQuit:(id)s { [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.forcequit.show" object: nil userInfo: nil deliverImmediately: YES]; }       /* the Force Quit Applications window of the top bar */
- (void)sleepNow:(id)s { Launch(@"/usr/sbin/acpiconf", @[ @"-s", @"3" ]); }
- (void)restart:(id)s { if (Confirm(@"Are you sure you want to restart your computer now?", @"If you do nothing, your computer will restart automatically in 1 minute.", @"Restart")) Launch(@"/sbin/shutdown", @[ @"-r", @"now" ]); }
- (void)shutDown:(id)s { if (Confirm(@"Are you sure you want to shut down your computer now?", @"If you do nothing, your computer will shut down automatically in 1 minute.", @"Shut Down")) Launch(@"/sbin/shutdown", @[ @"-p", @"now" ]); }
- (void)lockScreen:(id)s { NSBeep(); }
- (void)logOut:(id)s { if (Confirm([NSString stringWithFormat: @"Are you sure you want to quit all applications and log out %@ now?", WsdFullName()], @"If you do nothing, you will be logged out automatically in 1 minute.", @"Log Out")) Launch(@"/usr/bin/pkill", @[ @"-x", @"wsd" ]); }
- (NSMenu *)menu
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @"pear"]; if ([m respondsToSelector: @selector(setMinimumWidth:)]) ((void (*)(id, SEL, double))objc_msgSend)(m, @selector(setMinimumWidth:), 312.0);
	NSMenuItem *(^Add)(NSString *, SEL, NSString *, NSUInteger) = ^NSMenuItem *(NSString *t, SEL a, NSString *k, NSUInteger mask) { NSMenuItem *i = [m addItemWithTitle: t action: a keyEquivalent: k ?: @""]; [i setTarget: self]; if (k) [i setKeyEquivalentModifierMask: mask]; return i; };
	[Add(@"About This Mac", @selector(aboutThisMac:), nil, 0) setToolTip: @"sym:laptopcomputer"]; [m addItem: [NSMenuItem separatorItem]];
	[Add(@"System Settings…", @selector(openSettings:), nil, 0) setToolTip: @"sym:gearshape"]; [Add(@"App Store…", @selector(openAppStore:), nil, 0) setToolTip: @"sym:a.square"]; [m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *ri = [m addItemWithTitle: @"Recent Items" action: NULL keyEquivalent: @""]; NSMenu *rs = [[NSMenu alloc] initWithTitle: @"Recent Items"]; for (NSString *t in @[ @"Applications", @"Documents", @"Servers" ]) { NSMenuItem *x = [rs addItemWithTitle: t action: NULL keyEquivalent: @""]; NSMenu *e = [[NSMenu alloc] initWithTitle: t]; NSMenuItem *none = [e addItemWithTitle: @"Clear Menu" action: @selector(clearRecents:) keyEquivalent: @""]; [none setTarget: self]; [x setSubmenu: e]; } [ri setSubmenu: rs];
	[m addItem: [NSMenuItem separatorItem]];
	Add(@"Force Quit…", @selector(forceQuit:), @"\x1b", NSCommandKeyMask | NSAlternateKeyMask); [m addItem: [NSMenuItem separatorItem]];
	Add(@"Sleep", @selector(sleepNow:), nil, 0); Add(@"Restart…", @selector(restart:), nil, 0); Add(@"Shut Down…", @selector(shutDown:), nil, 0); [m addItem: [NSMenuItem separatorItem]];
	Add(@"Lock Screen", @selector(lockScreen:), @"q", NSCommandKeyMask | NSControlKeyMask); Add([NSString stringWithFormat: @"Log Out %@…", WsdFullName()], @selector(logOut:), @"q", NSCommandKeyMask | NSShiftKeyMask);
	return m;
}
@end

/* every main menu starts with the logo item, and the application's own menu title is bold */
BOOL WsdMenuBarPrepare(NSMenu *m)
{
	if (!m || ![m numberOfItems]) return NO; NSUInteger sig = [m numberOfItems]; id first = [m itemAtIndex: 0], second = [m numberOfItems] > 1 ? [m itemAtIndex: 1] : nil;
	if (getenv("WSD_MENU_DEBUG")) { NSMutableString *d = [NSMutableString string]; for (NSMenuItem *i in [m itemArray]) [d appendFormat: @"[%@|%@|%d|%p|img%d]", [i title], [i representedObject], (int)[i hasSubmenu], i, [i image] != nil]; NSLog(@"main menu %p %@: %@", m, [m title], d); }
	/* GNUstep puts the application's icon and process name ("Terminal-gnustep") into the menu bar as a first item: the Mac has none, and the logo item must exist once only */
	{ NSString *pn = [[NSProcessInfo processInfo] processName]; BOOL seenPear = NO;
	  /* the items the application put there itself (those present when the menu is first seen) are never dropped: when the process is named like the application ("Terminal") GNUstep puts the icon on the application's own menu item instead of adding one */
	  static NSMutableSet *own, *seenMenus; if (!own) { own = [[NSMutableSet alloc] init]; seenMenus = [[NSMutableSet alloc] init]; }       /* the library is not ARC */
	  NSValue *mk = [NSValue valueWithNonretainedObject: m]; if (![seenMenus containsObject: mk]) { [seenMenus addObject: mk]; for (NSMenuItem *i in [m itemArray]) [own addObject: [NSValue valueWithNonretainedObject: i]]; }
	  for (NSInteger k = 0; k < [m numberOfItems]; k++) { NSMenuItem *it = [m itemAtIndex: k]; BOOL pear = WsdIsPearItem(it), named = !pear && [[it title] isEqual: pn] && [it image], mine = [own containsObject: [NSValue valueWithNonretainedObject: it]], icon = named && !mine; if (named && mine) [it setImage: nil];
		if (icon || (pear && (seenPear || k > 1))) { [m removeItemAtIndex: k--]; continue; } if (pear) seenPear = YES; } }
	if (![m numberOfItems]) return YES;
	if (!WsdIsPearItem([m itemAtIndex: 0])) { NSMenuItem *i = [[NSMenuItem alloc] initWithTitle: @"" action: NULL keyEquivalent: @""]; [i setRepresentedObject: kPearItem]; [i setSubmenu: [[WsdSystemMenu shared] menu]]; [m insertItem: i atIndex: 0]; }
	if ([m numberOfItems] > 1) { NSMenuItem *app = [m itemAtIndex: 1]; if (![app attributedTitle] && [[app title] length]) [app setAttributedTitle: [[NSAttributedString alloc] initWithString: [app title] attributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13] }]]; }
	return sig != [m numberOfItems] || first != [m itemAtIndex: 0] || second != ([m numberOfItems] > 1 ? [m itemAtIndex: 1] : nil);
}
/* the places of the cells of the bar: the logo item is 34 wide at x = 10, the others have 11 pt on each side of the title */
NSRect WsdBarItemRect(NSMenuView *mv, NSInteger i, NSRect r)
{
	if (i == 0) return NSMakeRect(10, r.origin.y, 34, r.size.height);
	r.origin.x += 2 + (34 - 22); return r;
}

static IMP origRectOfItem;
static NSRect wsdRectOfItem(id self, SEL _cmd, NSInteger i)
{
	NSRect r = ((NSRect (*)(id, SEL, NSInteger))origRectOfItem)(self, _cmd, i);
	if ([(NSMenuView *)self isHorizontal] && [(NSMenuView *)self menu] == [NSApp mainMenu]) return WsdBarItemRect(self, i, r);
	return r;
}
static IMP origCellForItem, origTitleRect;
/* the application's title is bold */
static id wsdCellForItem(id self, SEL _cmd, NSInteger i)
{
	NSMenuItemCell *c = ((id (*)(id, SEL, NSInteger))origCellForItem)(self, _cmd, i);
	if (c && [(NSMenuView *)self isHorizontal] && [(NSMenuView *)self menu] == [NSApp mainMenu]) {
		static NSFont *regular; NSFont *b = [NSFont boldSystemFontOfSize: 13];
		if (i == 1) { if (![[c font] isEqual: b]) { [c setFont: b]; [c setNeedsSizing: YES]; [(NSMenuView *)self setNeedsSizing: YES]; } }
		else if (i > 1) { if (![[c font] isEqual: b]) regular = [c font]; else if (regular) [c setFont: regular]; }      /* a cell that was the application's title before the items moved keeps the bold font */
	}
	return c;
}
/* the text of the bar sits one point higher than the stock cell puts it */
static NSRect wsdTitleRect(id self, SEL _cmd, NSRect b)
{
	NSRect r = ((NSRect (*)(id, SEL, NSRect))origTitleRect)(self, _cmd, b);
	NSMenuView *mv = [(NSMenuItemCell *)self menuView]; if (mv && [mv isHorizontal] && [mv menu] == [NSApp mainMenu]) r.origin.y += [mv isFlipped] ? -1 : 1;
	else if (mv && ![mv isHorizontal] && [[[(NSMenuItemCell *)self menuItem] toolTip] hasPrefix: @"sym:"]) { r.origin.x += 25; r.size.width -= 25; }      /* a row with an icon: the title starts 25 pt further in */
	return r;
}
/* a submenu of a vertical menu opens beside its parent row (its first row level with it), on the left of the parent when it does not fit on the right, and is kept on the screen; GNUstep put its top at the top of the parent menu */
static IMP origLocForSub;
static NSPoint wsdLocationForSubmenu(id self, SEL _cmd, NSMenu *sub)
{
	NSMenuView *mv = self; NSPoint o = ((NSPoint (*)(id, SEL, id))origLocForSub)(self, _cmd, sub);
	if (!sub || [mv isHorizontal]) return o;
	NSInteger i = [[mv menu] indexOfItemWithSubmenu: sub]; if (i < 0) return o;
	NSWindow *pw = [mv window], *sw = [[sub menuRepresentation] window]; if (!pw || !sw) return o;
	NSRect row = [mv convertRect: [mv rectOfItemAtIndex: i] toView: nil]; NSPoint rp = [pw convertBaseToScreen: row.origin];
	NSRect pf = [pw frame], sf = [sw frame], sc = [[NSScreen mainScreen] frame];
	CGFloat inset = 5.0, overlap = NSMaxX(pf) - o.x;       /* the theme's menu area inset (WsdMacTheme menuItemAreaInsets) */
	NSPoint p = NSMakePoint(o.x, rp.y + NSHeight(row) + inset - NSHeight(sf));       /* first row level with the parent's row */
	if (p.x + NSWidth(sf) > NSMaxX(sc)) p.x = NSMinX(pf) - NSWidth(sf) + overlap;
	if (p.y < NSMinY(sc)) p.y = NSMinY(sc); if (p.y + NSHeight(sf) > NSMaxY(sc)) p.y = NSMaxY(sc) - NSHeight(sf);
	return p;
}
/* closing the main menu closes its open submenu, never the bar itself (a chosen item of a pop-up menu ended with the bar ordered out) */
static IMP origMenuClose;
static void wsdMenuClose(id self, SEL _cmd)
{
	if (self != [NSApp mainMenu]) { ((void (*)(id, SEL))origMenuClose)(self, _cmd); return; }
	NSMenu *sub = [(NSMenu *)self attachedMenu]; if (sub) [sub close];
}
/* the main menu window is never ordered out when the application deactivates (GNUstep hides windows that hide on deactivate): the Mac's menu bar is always there */
static IMP origHidesOnDeact, origCanHide;
static BOOL wsdHidesOnDeactivate(id self, SEL _cmd) { if (self == [[NSApp mainMenu] window]) return NO; return ((BOOL (*)(id, SEL))origHidesOnDeact)(self, _cmd); }
static BOOL wsdCanHide(id self, SEL _cmd) { if (self == [[NSApp mainMenu] window]) return NO; return ((BOOL (*)(id, SEL))origCanHide)(self, _cmd); }
void WsdInstallMenuBar(void)
{
	if (origRectOfItem) return; Method m = class_getInstanceMethod([NSMenuView class], @selector(rectOfItemAtIndex:)); if (m) origRectOfItem = method_setImplementation(m, (IMP)wsdRectOfItem);
	Method c = class_getInstanceMethod([NSMenuView class], @selector(menuItemCellForItemAtIndex:)); if (c) origCellForItem = method_setImplementation(c, (IMP)wsdCellForItem);
	Method t = class_getInstanceMethod([NSMenuItemCell class], @selector(titleRectForBounds:)); if (t) origTitleRect = method_setImplementation(t, (IMP)wsdTitleRect);
	Method ls = class_getInstanceMethod([NSMenuView class], @selector(locationForSubmenu:)); if (ls && !origLocForSub) origLocForSub = method_setImplementation(ls, (IMP)wsdLocationForSubmenu);
	Method mc = class_getInstanceMethod([NSMenu class], @selector(close)); if (mc && !origMenuClose) origMenuClose = method_setImplementation(mc, (IMP)wsdMenuClose);
	Method hd = class_getInstanceMethod([NSWindow class], @selector(hidesOnDeactivate)); if (hd && !origHidesOnDeact) origHidesOnDeact = method_setImplementation(hd, (IMP)wsdHidesOnDeactivate);
	Method ch = class_getInstanceMethod([NSWindow class], @selector(canHide)); if (ch && !origCanHide) origCanHide = method_setImplementation(ch, (IMP)wsdCanHide);
}
