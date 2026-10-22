/* Finder Settings (Finder > Settings…, cmd-,): General, Tags, Sidebar, Advanced. The preferences are kept where the Mac keeps them, ~/Library/Preferences/com.apple.finder.plist, under the keys the Finder uses
 * (NewWindowTarget, ShowExternalHardDrivesOnDesktop, AppleShowAllExtensions, FXRemoveOldTrashItems, _FXSortFoldersFirst, FXDefaultSearchScope ...). The window is drawn like the Finder's own. */
#import "TFinderViews.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static void FillRound(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }
static NSDictionary *Font(CGFloat sz, BOOL bold, NSColor *c) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: sz] : [NSFont systemFontOfSize: sz], NSForegroundColorAttributeName: c }; }
static NSString *PrefFile(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.apple.finder.plist"]; }
static NSMutableDictionary *gPrefs; static time_t gPrefsAt;
static NSMutableDictionary *Prefs(void) { if (!gPrefs) gPrefs = [[NSMutableDictionary dictionaryWithContentsOfFile: PrefFile()] mutableCopy] ?: [NSMutableDictionary dictionary]; return gPrefs; }
id TFPref(NSString *key, id def) { id v = Prefs()[key]; return v ?: def; }
BOOL TFPrefBool(NSString *key, BOOL def) { id v = Prefs()[key]; return v ? [v boolValue] : def; }
void TFSetPref(NSString *key, id value)
{
	if (value) Prefs()[key] = value; else [Prefs() removeObjectForKey: key];
	[[NSFileManager defaultManager] createDirectoryAtPath: [PrefFile() stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; [Prefs() writeToFile: PrefFile() atomically: YES];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"TFPrefsChanged" object: nil];
}

@interface NSObject (TSetDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
static void TextAtView(NSString *s, CGFloat x, CGFloat cy);
@interface TSettingsView : NSView { @public NSInteger page; NSMutableArray *_hits; }
@end
@implementation TSettingsView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 70 && (p.x < 90 || p.y < 24); }
- (NSArray *)_rows                                     /* what a page shows: @[ kind, key, title, default, options ] */
{
	if (page == 0) return @[
		@[ @"popup", @"NewWindowTarget", @"New Finder windows show:", @"PfHm", @[ @[ @"PfHm", NSUserName() ], @[ @"PfDe", @"Desktop" ], @[ @"PfDo", @"Documents" ], @[ @"PfCm", @"Macintosh HD" ] ] ],
		@[ @"head", @"", @"Show these items on the desktop:" ],
		@[ @"check", @"ShowHardDrivesOnDesktop", @"Hard disks", @NO ], @[ @"check", @"ShowExternalHardDrivesOnDesktop", @"External disks", @YES ], @[ @"check", @"ShowRemovableMediaOnDesktop", @"CDs, DVDs and iPods", @YES ], @[ @"check", @"ShowMountedServersOnDesktop", @"Connected servers", @NO ],
		@[ @"check", @"FinderSpawnTab", @"Open folders in tabs instead of new windows", @YES ] ];
	if (page == 1) { NSMutableArray *r = [NSMutableArray arrayWithObject: @[ @"head", @"", @"Show these tags in the sidebar:" ]]; for (NSString *t in @[ @"Red", @"Orange", @"Yellow", @"Green", @"Blue", @"Purple", @"Gray" ]) [r addObject: @[ @"tag", [@"SidebarTag" stringByAppendingString: t], t, @YES ]]; return r; }
	if (page == 2) return @[
		@[ @"head", @"", @"Favorites" ], @[ @"check", @"SidebarShowRecents", @"Recents", @YES ], @[ @"check", @"SidebarShowShared", @"Shared", @YES ], @[ @"check", @"SidebarShowApplications", @"Applications", @YES ], @[ @"check", @"SidebarShowDesktop", @"Desktop", @YES ], @[ @"check", @"SidebarShowDocuments", @"Documents", @YES ], @[ @"check", @"SidebarShowDownloads", @"Downloads", @YES ],
		@[ @"head", @"", @"Locations" ], @[ @"check", @"SidebarShowICloud", @"iCloud Drive", @YES ], @[ @"check", @"SidebarShowHome", @"Home folder", @YES ], @[ @"check", @"SidebarShowHardDisks", @"Hard disks", @YES ], @[ @"check", @"SidebarShowAirDrop", @"AirDrop", @YES ], @[ @"check", @"SidebarShowTrash", @"Trash", @YES ] ];
	return @[
		@[ @"check", @"AppleShowAllExtensions", @"Show all filename extensions", @NO ], @[ @"check", @"FXEnableExtensionChangeWarning", @"Show warning before changing an extension", @YES ], @[ @"check", @"FXEnableRemoveFromICloudDriveWarning", @"Show warning before removing from iCloud Drive", @YES ],
		@[ @"check", @"WarnOnEmptyTrash", @"Show warning before emptying the Trash", @YES ], @[ @"check", @"FXRemoveOldTrashItems", @"Remove items from the Trash after 30 days", @NO ],
		@[ @"head", @"", @"Keep folders on top:" ], @[ @"check", @"_FXSortFoldersFirst", @"In windows when sorting by name", @YES ], @[ @"check", @"_FXSortFoldersFirstOnDesktop", @"On Desktop", @NO ],
		@[ @"popup", @"FXDefaultSearchScope", @"When performing a search:", @"SCev", @[ @[ @"SCev", @"Search This Mac" ], @[ @"SCcf", @"Search the Current Folder" ], @[ @"SCsp", @"Use the Previous Search Scope" ] ] ] ];
}
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_SIDEBAR setFill]; NSRectFill(b); NSArray *tabs = @[ @[ @"General", @"gearshape" ], @[ @"Tags", @"tag" ], @[ @"Sidebar", @"sidebar.left" ], @[ @"Advanced", @"gearshape.2" ] ];
	NSString *t = tabs[page][0]; NSSize ts = [t sizeWithAttributes: Font(13, YES, TF_TEXT)]; [t drawAtPoint: NSMakePoint(b.size.width / 2 - ts.width / 2, 19) withAttributes: Font(13, YES, TF_TEXT)];
	_hits = [NSMutableArray array]; CGFloat tw = 76, x0 = b.size.width / 2 - tw * 2;
	for (int i = 0; i < 4; i++) { NSRect c = NSMakeRect(x0 + i * tw, 44, tw, 52); if (i == page) FillRound(c, 10, TFDark() ? TFRGBA(255, 255, 255, 0.10) : TFRGBA(0, 0, 0, 0.07)); TFSymbol(tabs[i][1], NSMakeRect(c.origin.x, c.origin.y + 6, tw, 24), 18, i == page ? TF_ACCENT : TF_DIM); NSSize z = [tabs[i][0] sizeWithAttributes: Font(11, NO, TF_TEXT)]; [tabs[i][0] drawAtPoint: NSMakePoint(NSMidX(c) - z.width / 2, c.origin.y + 32) withAttributes: Font(11, NO, i == page ? TF_ACCENT : TF_DIM)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: c], @"tab": @(i) }]; }
	[TF_LINE setFill]; NSRectFill(NSMakeRect(0, 106, b.size.width, 1)); CGFloat y = 132, lx = 60;
	for (NSArray *row in [self _rows]) {
		NSString *kind = row[0];
		if ([kind isEqual: @"head"]) { y += 6; [row[2] drawAtPoint: NSMakePoint(lx, y) withAttributes: Font(13, NO, TF_TEXT)]; y += 28; continue; }
		if ([kind isEqual: @"popup"]) {
			NSString *cur = TFPref(row[1], row[3]), *label = cur; for (NSArray *o in row[4]) if ([o[0] isEqual: cur]) label = o[1];
			NSSize z = [row[2] sizeWithAttributes: Font(13, NO, TF_TEXT)]; [row[2] drawAtPoint: NSMakePoint(lx, y + 4) withAttributes: Font(13, NO, TF_TEXT)];
			NSRect pr = NSMakeRect(lx + z.width + 10, y, 190, 24); FillRound(pr, 12, TF_PILL); TextAtView(label, pr.origin.x + 12, NSMidY(pr)); TFSymbol(@"chevron.up.chevron.down", NSMakeRect(NSMaxX(pr) - 26, pr.origin.y, 16, 24), 9, TF_DIM);
			[_hits addObject: @{ @"r": [NSValue valueWithRect: pr], @"popup": row }]; y += 40; continue;
		}
		BOOL on = TFPrefBool(row[1], [row[3] boolValue]); NSRect cb = NSMakeRect(lx + ([kind isEqual: @"tag"] || row[1] ? 14 : 0), y, 16, 16);
		FillRound(cb, 4, on ? TF_ACCENT : (TFDark() ? TFRGBA(255, 255, 255, 0.14) : TFRGBA(0, 0, 0, 0.12))); if (on) TFSymbol(@"checkmark", cb, 10, TFRGB(255, 255, 255));
		CGFloat tx = NSMaxX(cb) + 8; if ([kind isEqual: @"tag"]) { NSColor *c = [NSClassFromString(@"WsdFinderSupport") colorOfTag: row[2]]; [c setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(tx, y + 2, 12, 12)] fill]; tx += 20; }
		TextAtView(row[2], tx, y + 8); [_hits addObject: @{ @"r": [NSValue valueWithRect: NSMakeRect(cb.origin.x, y - 3, 380, 22)], @"check": row }]; y += 26;
	}
}
static void TextAtView(NSString *s, CGFloat x, CGFloat cy) { NSDictionary *a = Font(13, NO, TF_TEXT); NSSize z = [s sizeWithAttributes: a]; [s drawAtPoint: NSMakePoint(x, cy - z.height / 2) withAttributes: a]; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	for (NSDictionary *h in _hits) if (NSPointInRect(p, [h[@"r"] rectValue])) {
		if (h[@"tab"]) { page = [h[@"tab"] integerValue]; [self setNeedsDisplay: YES]; return; }
		if (h[@"check"]) { NSArray *row = h[@"check"]; TFSetPref(row[1], @(!TFPrefBool(row[1], [row[3] boolValue]))); [self setNeedsDisplay: YES]; return; }
		if (h[@"popup"]) { NSArray *row = h[@"popup"]; NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSString *cur = TFPref(row[1], row[3]);
			for (NSArray *o in row[4]) { NSMenuItem *it = [m addItemWithTitle: o[1] action: @selector(_pick:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: @[ row[1], o[0] ]]; [it setState: [o[0] isEqual: cur] ? NSOnState : NSOffState]; }
			NSRect pr = [h[@"r"] rectValue]; TFPopupMenu(self, NSMakePoint(pr.origin.x, NSMaxY(pr) + 2), m); return; }
	}
}
- (void)_pick:(NSMenuItem *)it { NSArray *kv = [it representedObject]; TFSetPref(kv[0], kv[1]); [self setNeedsDisplay: YES]; }
@end

void TFOpenSettings(void)
{
	static NSWindow *w; if (w && [w isVisible]) { [w makeKeyAndOrderFront: nil]; return; }
	w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(380, 220, 560, 470) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(560, 470)]; [w setMaxSize: NSMakeSize(560, 470)];
	TSettingsView *v = [[TSettingsView alloc] initWithFrame: NSMakeRect(0, 0, 560, 470)]; [w setContentView: v]; TWindowTrim *trim = [[TWindowTrim alloc] initWithFrame: [v bounds]]; [trim setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [v addSubview: trim];
	[w makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: w radius: 16];
}
