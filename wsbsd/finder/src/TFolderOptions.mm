/* View Options of a folder window (View > Show View Options, cmd-J), one native floating NSPanel per view mode laid out after the AX trees of the real windows (icon view 236 x 632, list view 236 x 646, column view 236 x 632, gallery view 236 x 632, each with its title bar): check boxes "Always open in ... view" / "Browse in ... view", Group By / Sort By pop-up buttons, then the controls of the mode (icon: Icon size and Grid spacing sliders, Text size, Label position, Show item info, Show icon preview, Background; list: Icon size small / large, Text size, Show Columns, Use relative dates, Calculate all sizes, Show icon preview; columns: Text size, Show icons, Show icon preview, Show preview column, Resize columns to fit filenames; gallery: Thumbnail size, Show preview column, Show icon preview, Show filename) and "Use as Defaults". The panel keeps no state: `get` returns the current values and `set` applies one change. Positions are the Mac's (from the window's top left); the labels are a little wider than the Mac's because the font here is Inter. */
#import <AppKit/AppKit.h>
#import "TFinderViews.h"
#import <objc/runtime.h>

static NSImage *PageIcon(CGFloat s)
{
	NSImage *im = [[NSImage alloc] initWithSize: NSMakeSize(s, s)]; [im lockFocus]; {
		CGFloat w = s * 0.62, h = s * 0.82, x = (s - w) / 2, y = (s - h) / 2, c = w * 0.3; NSBezierPath *p = [NSBezierPath bezierPath];
		[p moveToPoint: NSMakePoint(x, y)]; [p lineToPoint: NSMakePoint(x + w, y)]; [p lineToPoint: NSMakePoint(x + w, y + h - c)]; [p lineToPoint: NSMakePoint(x + w - c, y + h)]; [p lineToPoint: NSMakePoint(x, y + h)]; [p closePath];
		[[NSColor colorWithCalibratedWhite: 0.93 alpha: 1] setFill]; [p fill]; } [im unlockFocus]; return im;
}
static NSImage *GridIcon(CGFloat s, int n)
{
	NSImage *im = [[NSImage alloc] initWithSize: NSMakeSize(s, s)]; [im lockFocus]; {
		CGFloat cell = s / n, d = cell * 0.62, o = (cell - d) / 2; [[NSColor colorWithCalibratedWhite: 0.55 alpha: 1] setFill];
		for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) [[NSBezierPath bezierPathWithRoundedRect: NSMakeRect(i * cell + o, j * cell + o, d, d) xRadius: d * 0.25 yRadius: d * 0.25] fill];
	} [im unlockFocus]; return im;
}

@interface NSControl (TFKey) - (NSString *)identifierKey; @end
@implementation NSControl (TFKey) - (NSString *)identifierKey { return objc_getAssociatedObject(self, "tfkey"); } @end
@interface TFolderOptionsPanel : NSPanel { @public NSInteger mode; NSDictionary *(^get)(void); void (^set)(NSString *, id); NSMutableDictionary *ctl; NSTextField *sizeLabel; } @end
@implementation TFolderOptionsPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)changed:(id)sender
{
	NSString *k = [sender identifierKey]; id v = nil;
	if ([sender isKindOfClass: [NSPopUpButton class]]) v = [(NSPopUpButton *)sender titleOfSelectedItem];
	else if ([sender isKindOfClass: [NSSlider class]]) v = @(lround([(NSSlider *)sender doubleValue]));
	else if ([sender isKindOfClass: [NSButton class]]) v = @([(NSButton *)sender state] == NSOnState);
	if ([k hasPrefix: @"radio:"]) { NSArray *p = [[k substringFromIndex: 6] componentsSeparatedByString: @"="]; k = p[0]; v = @([p[1] intValue]); }
	if ([k isEqual: @"iconSize"]) [sizeLabel setStringValue: [NSString stringWithFormat: @"%d × %d", [v intValue], [v intValue]]];
	set(k, v); [self refresh];
}
- (void)refresh
{
	NSDictionary *d = get();
	for (NSString *k in ctl) { id c = ctl[k], v = d[k]; if (!v) continue;
		if ([c isKindOfClass: [NSPopUpButton class]]) [c selectItemWithTitle: [v description]];
		else if ([c isKindOfClass: [NSSlider class]]) [c setDoubleValue: [v doubleValue]];
		else if ([c isKindOfClass: [NSButton class]]) [c setState: [v boolValue] ? NSOnState : NSOffState]; }
	for (NSString *k in @[ @"labelRight", @"iconLarge", @"thumb", @"background" ]) { NSInteger cur = [d[k] integerValue]; for (NSButton *b in ctl[[k stringByAppendingString: @"#radios"]]) [b setState: [b tag] == cur ? NSOnState : NSOffState]; }
	if (d[@"iconSize"]) [sizeLabel setStringValue: [NSString stringWithFormat: @"%d × %d", [d[@"iconSize"] intValue], [d[@"iconSize"] intValue]]];
}
@end

static TFolderOptionsPanel *gFolder;
void TFOpenFolderViewOptions(NSInteger mode, NSString *folderName, NSDictionary *(^get)(void), void (^set)(NSString *, id))
{
	if (gFolder && [gFolder isVisible]) { BOOL same = gFolder->mode == mode; [gFolder orderOut: nil]; if (same) return; }
	gFolder = nil;
	NSString *vn = @[ @"icon", @"list", @"column", @"gallery" ][MAX(0, MIN(3, mode))]; CGFloat total = mode == 1 ? 646 : 632;
	TFolderOptionsPanel *p = [[TFolderOptionsPanel alloc] initWithContentRect: NSMakeRect(0, 0, 236, 600) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask backing: NSBackingStoreBuffered defer: NO];
	gFolder = p; p->mode = mode; p->get = get; p->set = set; p->ctl = [NSMutableDictionary dictionary]; [p setReleasedWhenClosed: NO]; [p setFloatingPanel: YES]; [p setBecomesKeyOnlyIfNeeded: YES]; [p setHidesOnDeactivate: NO]; [p setTitle: folderName];
	CGFloat th = [p frame].size.height - [[p contentView] frame].size.height; [p setContentSize: NSMakeSize(236, total - th)]; NSView *cv = [p contentView]; CGFloat H = [cv frame].size.height;
	CGFloat (^Y)(CGFloat, CGFloat) = ^CGFloat(CGFloat yWin, CGFloat h) { return H - (yWin - th) - h; };
	NSFont *f13 = [NSFont systemFontOfSize: 13];
	NSTextField *(^Label)(NSString *, CGFloat, CGFloat, CGFloat) = ^NSTextField *(NSString *t, CGFloat x, CGFloat yw, CGFloat w) { NSTextField *l = [NSTextField labelWithString: t]; [l setFont: f13]; [l setFrame: NSMakeRect(x, Y(yw, 16), w + 24, 16)]; [cv addSubview: l]; return l; };
	void (^Key)(NSControl *, NSString *) = ^(NSControl *c, NSString *k) { objc_setAssociatedObject(c, "tfkey", k, OBJC_ASSOCIATION_RETAIN); [c setTarget: p]; [c setAction: @selector(changed:)]; };
	NSPopUpButton *(^Pop)(NSString *, CGFloat, CGFloat, CGFloat, NSArray *) = ^NSPopUpButton *(NSString *k, CGFloat x, CGFloat yw, CGFloat w, NSArray *items) { NSPopUpButton *b = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(x, Y(yw, 22), w, 22) pullsDown: NO]; [b setFont: f13]; for (NSString *t in items) { if ([t isEqual: @"-"]) [[b menu] addItem: [NSMenuItem separatorItem]]; else [b addItemWithTitle: t]; } Key(b, k); [cv addSubview: b]; p->ctl[k] = b; return b; };
	NSButton *(^Check)(NSString *, NSString *, CGFloat, CGFloat, CGFloat) = ^NSButton *(NSString *k, NSString *t, CGFloat x, CGFloat yw, CGFloat w) { NSButton *b = [[NSButton alloc] initWithFrame: NSMakeRect(x, Y(yw, 16), w + 28, 16)]; [b setButtonType: NSSwitchButton]; [b setTitle: t]; [b setFont: f13]; Key(b, k); [cv addSubview: b]; p->ctl[k] = b; return b; };
	void (^Radios)(NSString *, NSArray *) = ^(NSString *k, NSArray *specs) { NSMutableArray *rs = [NSMutableArray array]; for (NSArray *s in specs) { NSButton *b = [[NSButton alloc] initWithFrame: NSMakeRect([s[1] doubleValue], Y([s[2] doubleValue], 16), [s[3] doubleValue] + 28, 16)]; [b setButtonType: NSRadioButton]; [b setTitle: s[0]]; [b setFont: f13]; [b setTag: [s[4] integerValue]]; Key(b, [NSString stringWithFormat: @"radio:%@=%@", k, s[4]]); [cv addSubview: b]; [rs addObject: b]; } p->ctl[[k stringByAppendingString: @"#radios"]] = rs; };
	void (^Line)(CGFloat) = ^(CGFloat yw) { NSBox *b = [[NSBox alloc] initWithFrame: NSMakeRect(0, Y(yw, 1), 236, 1)]; [b setBoxType: NSBoxSeparator]; [cv addSubview: b]; };
	NSSlider *(^Slide)(NSString *, CGFloat, CGFloat, double, double) = ^NSSlider *(NSString *k, CGFloat yw, CGFloat x, double lo, double hi) { NSSlider *s = [[NSSlider alloc] initWithFrame: NSMakeRect(x, Y(yw, 20), 134, 20)]; [s setMinValue: lo]; [s setMaxValue: hi]; [s setNumberOfTickMarks: 8]; Key(s, k); [cv addSubview: s]; p->ctl[k] = s; return s; };
	void (^Pic)(NSImage *, CGFloat, CGFloat, CGFloat) = ^(NSImage *im, CGFloat x, CGFloat yw, CGFloat s) { NSImageView *v = [[NSImageView alloc] initWithFrame: NSMakeRect(x, Y(yw, s), s, s)]; [v setImage: im]; [cv addSubview: v]; };
	NSArray *groups = @[ @"None", @"-", @"Name", @"Kind", @"Application", @"Date Last Opened", @"Date Added", @"Date Modified", @"Date Created", @"Size", @"Tags" ];
	NSArray *sorts = @[ @"None", @"-", @"Snap to Grid", @"-", @"Name", @"Kind", @"Date Last Opened", @"Date Added", @"Date Modified", @"Date Created", @"Size", @"Tags" ];
	Check(@"alwaysOpen", [NSString stringWithFormat: @"Always open in %@ view", vn], 19, 35, mode == 2 ? 167 : mode == 3 ? 164 : mode == 1 ? 144 : 151); Check(@"browseIn", [NSString stringWithFormat: @"Browse in %@ view", vn], 29, 57, mode == 2 ? 140 : mode == 3 ? 137 : mode == 1 ? 117 : 123);
	if (mode == 3) { Label(@"Sort By:", 19, 91, 44); Pop(@"sortBy", 80, 88, 137, @[ @"None", @"-", @"Name", @"Kind", @"Date Last Opened", @"Date Added", @"Date Modified", @"Date Created", @"Size", @"Tags" ]); Line(118); }
	else { Label(@"Group By:", 19, 91, 55); Pop(@"groupBy", 80, 88, 137, groups); Label(@"Sort By:", 19, 119, 44); Pop(@"sortBy", 80, 116, 137, sorts); Line(146); }
	if (mode == 0) {
		Label(@"Icon size:", 19, 153, 52); p->sizeLabel = Label(@"64 × 64", 86, 153, 60); Pic(PageIcon(18), 19, 171, 18); Slide(@"iconSize", 170, 43, 16, 256); Pic(PageIcon(34), 183, 163, 34);
		Label(@"Grid spacing:", 19, 198, 72); Pic(GridIcon(18, 2), 19, 216, 18); Slide(@"gridSpacing", 215, 43, 36, 100); Pic(GridIcon(34, 3), 183, 208, 34); Line(248);
		Label(@"Text size:", 19, 260, 52); Pop(@"textSize", 86, 257, 66, @[ @"10", @"11", @"12", @"13", @"14", @"15", @"16" ]);
		Label(@"Label position:", 19, 285, 79); Radios(@"labelRight", @[ @[ @"Bottom", @19, @306, @59, @0 ], @[ @"Right", @104, @306, @48, @1 ] ]); Line(327);
		Check(@"showInfo", @"Show item info", 19, 337, 98); Check(@"showPreview", @"Show icon preview", 19, 357, 118); Line(379);
		Label(@"Background:", 19, 408, 68); Radios(@"background", @[ @[ @"Default", @19, @425, @68, @0 ], @[ @"Color", @19, @443, @68, @1 ], @[ @"Picture", @19, @461, @68, @2 ] ]);
	} else if (mode == 1) {
		Label(@"Icon size:", 19, 171, 52); NSButton *sm = [[NSButton alloc] initWithFrame: NSMakeRect(93, Y(169, 18), 18, 18)]; [sm setBordered: NO]; [sm setImage: PageIcon(18)]; [cv addSubview: sm]; Pic(PageIcon(34), 130, 153, 34);
		Radios(@"iconLarge", @[ @[ @"", @94, @193, @0, @0 ], @[ @"", @139, @193, @0, @1 ] ]);
		Label(@"Text size:", 19, 220, 52); Pop(@"textSize", 86, 217, 66, @[ @"10", @"11", @"12", @"13", @"14", @"15", @"16" ]); Label(@"Show Columns:", 19, 245, 83);
		CGFloat y = 263; for (NSString *c in @[ @"iCloud Status", @"Last Modified By", @"Shared By", @"Date Modified", @"Date Created", @"Date Last Opened", @"Date Added", @"Size", @"Kind", @"Version", @"Comments", @"Tags" ]) { Check([@"col." stringByAppendingString: c], c, 19, y, 170); y += 20; }
		Check(@"relDates", @"Use relative dates", 19, 514, 115); Check(@"calcSizes", @"Calculate all sizes", 19, 534, 114); Check(@"showPreview", @"Show icon preview", 19, 554, 118);
	} else if (mode == 2) {
		Label(@"Text size:", 19, 156, 52); Pop(@"textSize", 86, 153, 66, @[ @"10", @"11", @"12", @"13", @"14", @"15", @"16" ]);
		Check(@"showIcons", @"Show icons", 19, 181, 80); Check(@"showPreview", @"Show icon preview", 19, 201, 118); Check(@"showPreviewColumn", @"Show preview column", 19, 221, 134); Check(@"resizeToFit", @"Resize columns to fit filenames", 19, 241, 183);
	} else {
		Label(@"Thumbnail size:", 19, 125, 85); Pic(PageIcon(28), 19, 173, 28); Pic(PageIcon(41), 77, 160, 41); Pic(PageIcon(54), 151, 147, 54);
		Radios(@"thumb", @[ @[ @"", @28, @207, @0, @0 ], @[ @"", @94, @207, @0, @1 ], @[ @"", @176, @207, @0, @2 ] ]);
		Check(@"showPreviewColumn", @"Show preview column", 19, 238, 134); Check(@"showPreview", @"Show icon preview", 19, 258, 118); Check(@"showFilename", @"Show filename", 19, 278, 97);
	}
	if (mode != 2) { NSButton *u = [[NSButton alloc] initWithFrame: NSMakeRect(57, Y(mode == 1 ? 605 : 591, 22), 123, 22)]; [u setTitle: @"Use as Defaults"]; [u setBezelStyle: NSRoundedBezelStyle]; [u setFont: f13]; objc_setAssociatedObject(u, "tfkey", @"useAsDefaults", OBJC_ASSOCIATION_RETAIN); [u setTarget: p]; [u setAction: @selector(changed:)]; [cv addSubview: u]; }
	[p setFrameTopLeftPoint: NSMakePoint(NSMaxX([[NSScreen mainScreen] frame]) - 280, NSMaxY([[NSScreen mainScreen] frame]) - 120)];
	[p refresh]; [p orderFront: nil];
}
