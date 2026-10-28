/* View Options of the Desktop (View > Show View Options on the desktop), as native controls laid out after the AX tree of the real window ("Desktop", 236 x 632 with its title bar, a floating window): Stack By and Sort By pop-up buttons, Icon size (slider 16...128, "64 x 64" beside the label, a small and a large document icon at its ends), Grid spacing (slider 1...100, small and large grid icons), Text size (pop-up 10...16), Label position (Bottom / Right radio buttons), Show item info, Show icon preview; lines between the groups. The options go to the view (and from there to com.apple.finder DesktopViewSettings). */
#import <AppKit/AppKit.h>
#import "TFinderViews.h"

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

@interface TDesktopOptionsPanel : NSPanel { @public TIconView *view; void (^changed)(void); NSTextField *sizeLabel; NSPopUpButton *stackBy, *sortBy, *textSize; NSSlider *iconSlider, *gridSlider; NSButton *bottom, *right, *info, *preview; } @end
@implementation TDesktopOptionsPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)_apply { [view applyOptions]; if (changed) changed(); }
- (void)iconSize:(NSSlider *)s { view->_isz = (CGFloat)lround([s doubleValue]); [sizeLabel setStringValue: [NSString stringWithFormat: @"%d × %d", (int)view->_isz, (int)view->_isz]]; [self _apply]; }
- (void)gridSpacing:(NSSlider *)s { view->_grid = (CGFloat)lround([s doubleValue]); [self _apply]; }
- (void)textSize:(NSPopUpButton *)p { view->_textSize = [[p titleOfSelectedItem] doubleValue]; [self _apply]; }
- (void)labelPos:(NSButton *)b { view->_labelRight = [b tag] == 1; [bottom setState: view->_labelRight ? NSOffState : NSOnState]; [right setState: view->_labelRight ? NSOnState : NSOffState]; [self _apply]; }
- (void)showInfo:(NSButton *)b { view->_showInfo = [b state] == NSOnState; [self _apply]; }
- (void)showPreview:(NSButton *)b { view->_showPreview = [b state] == NSOnState; [self _apply]; }
- (void)stackBy:(NSPopUpButton *)p { NSArray *k = @[ @"", @"", @"kind", @"dateLastOpened", @"dateAdded", @"dateModified", @"dateCreated", @"tags" ]; NSString *g = k[[p indexOfSelectedItem]]; [view setGroup: [g length] ? g : nil]; if (changed) changed(); }
- (void)sortBy:(NSPopUpButton *)p { NSArray *k = @[ @"", @"", @"snap", @"", @"name", @"kind", @"opened", @"created", @"modified", @"created", @"size", @"tags" ]; NSString *g = k[[p indexOfSelectedItem]]; if ([g isEqual: @"snap"]) [view setSnapToGrid: YES]; else { [view setSnapToGrid: NO]; [view arrangeBy: [g length] ? g : nil]; } if (changed) changed(); }
@end

static TDesktopOptionsPanel *gDesk;
void TFOpenDesktopViewOptions(TIconView *view, void (^changed)(void))
{
	if (gDesk && [gDesk isVisible]) { [gDesk orderOut: nil]; return; }
	if (!gDesk) {
		gDesk = [[TDesktopOptionsPanel alloc] initWithContentRect: NSMakeRect(0, 0, 236, 600) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask backing: NSBackingStoreBuffered defer: NO];
		[gDesk setReleasedWhenClosed: NO]; [gDesk setFloatingPanel: YES]; [gDesk setBecomesKeyOnlyIfNeeded: YES]; [gDesk setHidesOnDeactivate: NO]; [gDesk setTitle: @"Desktop"];
		CGFloat th = [gDesk frame].size.height - [[gDesk contentView] frame].size.height; [gDesk setContentSize: NSMakeSize(236, 632 - th)]; NSView *cv = [gDesk contentView]; CGFloat H = [cv frame].size.height;
		CGFloat (^Y)(CGFloat, CGFloat) = ^CGFloat(CGFloat yWin, CGFloat h) { return H - (yWin - th) - h; };
		NSTextField *(^Label)(NSString *, CGFloat, CGFloat, CGFloat) = ^NSTextField *(NSString *t, CGFloat x, CGFloat yw, CGFloat w) { NSTextField *l = [NSTextField labelWithString: t]; [l setFont: [NSFont systemFontOfSize: 13]]; [l setFrame: NSMakeRect(x, Y(yw, 16), w + 24, 16)]; [cv addSubview: l]; return l; };
		NSPopUpButton *(^Pop)(CGFloat, CGFloat, CGFloat, NSArray *, SEL) = ^NSPopUpButton *(CGFloat x, CGFloat yw, CGFloat w, NSArray *items, SEL a) { NSPopUpButton *p = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(x, Y(yw, 22), w, 22) pullsDown: NO]; [p setFont: [NSFont systemFontOfSize: 13]]; for (NSString *t in items) { if ([t isEqual: @"-"]) [[p menu] addItem: [NSMenuItem separatorItem]]; else [p addItemWithTitle: t]; } [p setTarget: gDesk]; [p setAction: a]; [cv addSubview: p]; return p; };
		void (^Line)(CGFloat) = ^(CGFloat yw) { NSBox *b = [[NSBox alloc] initWithFrame: NSMakeRect(0, Y(yw, 1), 236, 1)]; [b setBoxType: NSBoxSeparator]; [cv addSubview: b]; };
		Label(@"Stack By:", 19, 34, 52); gDesk->stackBy = Pop(80, 31, 137, @[ @"None", @"-", @"Kind", @"Date Last Opened", @"Date Added", @"Date Modified", @"Date Created", @"Tags" ], @selector(stackBy:));
		Label(@"Sort By:", 19, 62, 44); gDesk->sortBy = Pop(80, 59, 137, @[ @"None", @"-", @"Snap to Grid", @"-", @"Name", @"Kind", @"Date Last Opened", @"Date Added", @"Date Modified", @"Date Created", @"Size", @"Tags" ], @selector(sortBy:));
		Line(87);
		Label(@"Icon size:", 19, 96, 52); gDesk->sizeLabel = Label(@"64 × 64", 86, 96, 60);
		NSImageView *(^Pic)(NSImage *, CGFloat, CGFloat, CGFloat) = ^NSImageView *(NSImage *im, CGFloat x, CGFloat yw, CGFloat s) { NSImageView *v = [[NSImageView alloc] initWithFrame: NSMakeRect(x, Y(yw, s), s, s)]; [v setImage: im]; [cv addSubview: v]; return v; };
		Pic(PageIcon(18), 19, 114, 18); gDesk->iconSlider = [[NSSlider alloc] initWithFrame: NSMakeRect(43, Y(113, 20), 134, 20)]; [gDesk->iconSlider setMinValue: 16]; [gDesk->iconSlider setMaxValue: 128]; [gDesk->iconSlider setNumberOfTickMarks: 8]; [gDesk->iconSlider setTarget: gDesk]; [gDesk->iconSlider setAction: @selector(iconSize:)]; [cv addSubview: gDesk->iconSlider]; Pic(PageIcon(34), 183, 106, 34);
		Label(@"Grid spacing:", 19, 141, 72); Pic(GridIcon(18, 2), 19, 159, 18); gDesk->gridSlider = [[NSSlider alloc] initWithFrame: NSMakeRect(43, Y(158, 20), 134, 20)]; [gDesk->gridSlider setMinValue: 1]; [gDesk->gridSlider setMaxValue: 100]; [gDesk->gridSlider setNumberOfTickMarks: 8]; [gDesk->gridSlider setTarget: gDesk]; [gDesk->gridSlider setAction: @selector(gridSpacing:)]; [cv addSubview: gDesk->gridSlider]; Pic(GridIcon(34, 3), 183, 151, 34);
		Line(191);
		Label(@"Text size:", 19, 203, 52); gDesk->textSize = Pop(86, 200, 66, @[ @"10", @"11", @"12", @"13", @"14", @"15", @"16" ], @selector(textSize:));
		Label(@"Label position:", 19, 228, 79);
		NSButton *(^Btn)(NSString *, NSButtonType, CGFloat, CGFloat, CGFloat, SEL, NSInteger) = ^NSButton *(NSString *t, NSButtonType ty, CGFloat x, CGFloat yw, CGFloat w, SEL a, NSInteger tag) { NSButton *b = [[NSButton alloc] initWithFrame: NSMakeRect(x, Y(yw, 16), w, 16)]; [b setButtonType: ty]; [b setTitle: t]; [b setFont: [NSFont systemFontOfSize: 13]]; [b setTag: tag]; [b setTarget: gDesk]; [b setAction: a]; [b setFrameSize: NSMakeSize(w + 28, 16)]; [cv addSubview: b]; return b; };
		gDesk->bottom = Btn(@"Bottom", NSRadioButton, 19, 249, 59, @selector(labelPos:), 0); gDesk->right = Btn(@"Right", NSRadioButton, 104, 249, 48, @selector(labelPos:), 1);
		Line(270);
		gDesk->info = Btn(@"Show item info", NSSwitchButton, 19, 280, 98, @selector(showInfo:), 0); gDesk->preview = Btn(@"Show icon preview", NSSwitchButton, 19, 300, 118, @selector(showPreview:), 0);
		Line(322);
		[gDesk setFrameTopLeftPoint: NSMakePoint(NSMaxX([[NSScreen mainScreen] frame]) - 280, NSMaxY([[NSScreen mainScreen] frame]) - 200)];
	}
	gDesk->view = view; gDesk->changed = changed;
	[gDesk->iconSlider setDoubleValue: view->_isz]; [gDesk->sizeLabel setStringValue: [NSString stringWithFormat: @"%d × %d", (int)view->_isz, (int)view->_isz]]; [gDesk->gridSlider setDoubleValue: view->_grid]; [gDesk->textSize selectItemWithTitle: [NSString stringWithFormat: @"%d", (int)view->_textSize]];
	[gDesk->bottom setState: view->_labelRight ? NSOffState : NSOnState]; [gDesk->right setState: view->_labelRight ? NSOnState : NSOffState]; [gDesk->info setState: view->_showInfo ? NSOnState : NSOffState]; [gDesk->preview setState: view->_showPreview ? NSOnState : NSOffState];
	[gDesk orderFront: nil];
}
