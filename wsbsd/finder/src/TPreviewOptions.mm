/* The "Preview Options" palette of the Finder (View > Show Preview Options, shown beside a window with the preview pane): a floating NSPanel of NSButton check boxes, laid out after the AX tree of the real one (240 x 479 with its title bar, "Preview Options - Text"): "Show Info:" at (19, 33), the check boxes on a pitch of 24 at x 19 (groups) and 39 (their items), a line, "Show Quick Actions" at y 442. The groups are Tags, Dates (Created, Modified, Last opened), General (Keywords, Where from) and More (Title, Subject, Organizations, Authors, Editors, Comment); a group's box is on when all its items are, mixed when some are. The options are kept in the preference PreviewOptions. Only Tags, the three dates and Quick Actions change the pane; the others (document metadata the pane cannot read yet) are only stored. Measured for a text file; the lists of other kinds (images, folders, audio) were not read. */
#import <AppKit/AppKit.h>
#import "TFinderViews.h"

static NSString *const kOpts[][3] = {   /* key, title, parent key ("" for a group or a single box) */
	{ @"tags", @"Tags", @"" }, { @"dates", @"Dates", @"" }, { @"created", @"Created", @"dates" }, { @"modified", @"Modified", @"dates" }, { @"lastOpened", @"Last opened", @"dates" },
	{ @"general", @"General", @"" }, { @"keywords", @"Keywords", @"general" }, { @"whereFrom", @"Where from", @"general" },
	{ @"more", @"More", @"" }, { @"title", @"Title", @"more" }, { @"subject", @"Subject", @"more" }, { @"organizations", @"Organizations", @"more" }, { @"authors", @"Authors", @"more" }, { @"editors", @"Editors", @"more" }, { @"comment", @"Comment", @"more" },
};
static const int kOptN = (int)(sizeof kOpts / sizeof kOpts[0]);

BOOL TFPreviewOpt(NSString *key)
{
	NSDictionary *d = TFPref(@"PreviewOptions", @{}); id v = [d isKindOfClass: [NSDictionary class]] ? d[key] : nil; if (v) return [v boolValue];
	return [@[ @"tags", @"created", @"modified", @"lastOpened", @"quickActions" ] containsObject: key];
}
static void SetOpt(NSString *key, BOOL on) { NSMutableDictionary *d = [TFPref(@"PreviewOptions", @{}) mutableCopy] ?: [NSMutableDictionary dictionary]; d[key] = @(on); TFSetPref(@"PreviewOptions", d); }

@interface TPreviewOptionsPanel : NSPanel { @public NSMutableDictionary *boxes; void (^changed)(void); } - (void)toggle:(NSButton *)b; - (void)sync; @end
@implementation TPreviewOptionsPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)sync
{
	for (int i = 0; i < kOptN; i++) {
		NSString *k = kOpts[i][0]; NSButton *b = boxes[k]; if (![kOpts[i][2] length]) {
			int on = 0, n = 0; for (int j = 0; j < kOptN; j++) if ([kOpts[j][2] isEqual: k]) { n++; if (TFPreviewOpt(kOpts[j][0])) on++; }
			if (n) [b setState: on == n ? NSOnState : on ? NSMixedState : NSOffState]; else [b setState: TFPreviewOpt(k) ? NSOnState : NSOffState];
		} else [b setState: TFPreviewOpt(k) ? NSOnState : NSOffState];
	}
	[boxes[@"quickActions"] setState: TFPreviewOpt(@"quickActions") ? NSOnState : NSOffState];
}
- (void)toggle:(NSButton *)b
{
	NSString *k = [b tag] == 100 ? @"quickActions" : kOpts[[b tag]][0]; BOOL on = [b state] != NSOffState; if ([b state] == NSMixedState) on = YES;
	BOOL group = NO; for (int i = 0; i < kOptN; i++) if ([kOpts[i][2] isEqual: k]) { group = YES; SetOpt(kOpts[i][0], on); }
	if (!group) SetOpt(k, on); [self sync]; if (changed) changed();
}
@end

static TPreviewOptionsPanel *gPanel;
BOOL TFPreviewOptionsVisible(void) { return gPanel && [gPanel isVisible]; }
void TFTogglePreviewOptions(NSString *kindTitle, void (^changed)(void))
{
	if (gPanel && [gPanel isVisible]) { [gPanel orderOut: nil]; return; }
	if (!gPanel) {
		gPanel = [[TPreviewOptionsPanel alloc] initWithContentRect: NSMakeRect(0, 0, 240, 451) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask backing: NSBackingStoreBuffered defer: NO];
		[gPanel setReleasedWhenClosed: NO]; [gPanel setFloatingPanel: YES]; [gPanel setBecomesKeyOnlyIfNeeded: YES]; [gPanel setHidesOnDeactivate: NO];
		NSRect fr = [gPanel frame]; CGFloat th = fr.size.height - [[gPanel contentView] frame].size.height;       /* the title bar: the whole window is 479 high */
		[gPanel setContentSize: NSMakeSize(240, 479 - th)]; NSView *cv = [gPanel contentView]; CGFloat H = [cv frame].size.height;
		CGFloat (^Y)(CGFloat, CGFloat) = ^CGFloat(CGFloat yWin, CGFloat h) { return H - (yWin - th) - h; };       /* y measured from the top of the window -> the content view's y */
		gPanel->boxes = [NSMutableDictionary dictionary];
		NSTextField *sh = [NSTextField labelWithString: @"Show Info:"]; [sh setFont: [NSFont systemFontOfSize: 13]]; [sh setFrame: NSMakeRect(19, Y(33, 16), 212, 16)]; [cv addSubview: sh];
		CGFloat y = 56;
		for (int i = 0; i < kOptN; i++) { BOOL child = [kOpts[i][2] length]; NSButton *b = [[NSButton alloc] initWithFrame: NSMakeRect(child ? 39 : 19, Y(y, 18), child ? 182 : 202, 18)]; [b setButtonType: NSSwitchButton]; [b setAllowsMixedState: !child]; [b setTitle: kOpts[i][1]]; [b setFont: [NSFont systemFontOfSize: 13]]; [b setTag: i]; [b setTarget: gPanel]; [b setAction: @selector(toggle:)]; [cv addSubview: b]; gPanel->boxes[kOpts[i][0]] = b; y += 24; }
		NSBox *ln = [[NSBox alloc] initWithFrame: NSMakeRect(19, Y(430, 1), 202, 1)]; [ln setBoxType: NSBoxSeparator]; [cv addSubview: ln];
		NSButton *qa = [[NSButton alloc] initWithFrame: NSMakeRect(19, Y(442, 18), 202, 18)]; [qa setButtonType: NSSwitchButton]; [qa setTitle: @"Show Quick Actions"]; [qa setFont: [NSFont systemFontOfSize: 13]]; [qa setTag: 100]; [qa setTarget: gPanel]; [qa setAction: @selector(toggle:)]; [cv addSubview: qa]; gPanel->boxes[@"quickActions"] = qa;
		[gPanel center];
	}
	gPanel->changed = changed; [gPanel setTitle: [NSString stringWithFormat: @"Preview Options - %@", kindTitle ?: @"Text"]]; [gPanel sync]; [gPanel orderFront: nil];
}
