/* Force Quit Applications (Apple menu > Force Quit…, Command-Option-Escape), laid out from the accessibility tree of the real window (a 370 x 320 system dialog): the hint (13 pt) at (19, 51) 332 x 34, the list
 * (a scroll area with a table of rows 22 high, an 18 pt icon and the name) at (20, 92) 330 x 168, the note at (19, 275) 244 x 28 and the default button at (269, 275) 86 x 30, "Force Quit" for an application and
 * "Relaunch" for the Finder (the real one shows Relaunch for the selected Finder row). Standard AppKit controls: NSTextField, NSScrollView / NSTableView, NSButton. */
#import <AppKit/AppKit.h>
#include <signal.h>

@interface FQApp : NSObject { @public NSString *name, *path; int pid; NSImage *icon; } @end
@implementation FQApp @end

/* a click on a row selects it (GNUstep's table tracks the press in a loop that the pointer events of this window server do not feed), a double click acts */
/* the selected row is blue with white text, as in the Mac's window (the theme's table highlight is grey here and the row could only be told by guessing) */
@interface FQTable : NSTableView @end
@implementation FQTable
- (void)highlightSelectionInClipRect:(NSRect)clip
{
	NSIndexSet *sel = [self selectedRowIndexes]; [[NSColor colorWithCalibratedRed: 0.0 green: 0.38 blue: 0.88 alpha: 1] setFill];
	for (NSInteger r = (NSInteger)[sel firstIndex]; r != NSNotFound; r = (NSInteger)[sel indexGreaterThanIndex: (NSUInteger)r]) { NSRect rr = NSInsetRect([self rectOfRow: r], 4, 0); if (NSIntersectsRect(rr, clip)) [[NSBezierPath bezierPathWithRoundedRect: rr xRadius: 5 yRadius: 5] fill]; }
}
@end
@interface FQPanel : NSPanel { @public NSTableView *fqTable; } @end
@implementation FQPanel
- (void)sendEvent:(NSEvent *)e
{
	if ([e type] == NSLeftMouseDown && fqTable) {
		NSPoint p = [fqTable convertPoint: [e locationInWindow] fromView: nil]; NSInteger r = [fqTable rowAtPoint: p];
		if (r >= 0 && NSPointInRect(p, [fqTable bounds])) { [fqTable selectRowIndexes: [NSIndexSet indexSetWithIndex: r] byExtendingSelection: NO]; if ([e clickCount] > 1) [fqTable sendAction: [fqTable doubleAction] to: [fqTable target]]; return; }
	}
	[super sendEvent: e];
}
@end
@interface FQController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate> { NSPanel *win; NSTableView *table; NSButton *button; NSMutableArray *apps; }
+ (instancetype)shared; - (void)show;
@end
@implementation FQController
+ (instancetype)shared { static FQController *c; if (!c) c = [[FQController alloc] init]; return c; }
- (void)scan
{
	NSMutableArray *r = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set]; FILE *f = popen("ps -axww -o pid= -o command= 2>/dev/null", "r");
	if (f) { char line[2048]; while (fgets(line, sizeof line, f)) {
		char *mark = strstr(line, ".app/Contents/MacOS/"); int pid = atoi(line); if (pid == getpid() || pid <= 1) continue;
		if (!mark) { char *g = strstr(line, "-gnustep"); if (!g || strstr(line, "gnustep-")) continue; char *b = g; while (b > line && b[-1] != '/' && b[-1] != ' ') b--; NSString *nm = [[NSString alloc] initWithBytes: b length: (NSUInteger)(g - b) encoding: NSUTF8StringEncoding]; if ([seen containsObject: nm]) continue; [seen addObject: nm]; FQApp *a = [FQApp new]; a->path = [nm stringByAppendingString: @".app"]; a->pid = pid; a->name = nm; a->icon = nil; [r addObject: a]; continue; }
		*mark = 0; char *start = line; while (*start == ' ') start++; while (*start >= '0' && *start <= '9') start++; while (*start == ' ') start++;
		for (char *q = mark; q > start; q--) if (*q == ' ') { start = q + 1; break; }       /* "/usr/lib/dyld /System/.../Finder.app/...": the program is the last word before .app (dyld starts the applications of the image) */
		NSString *bp = [[NSString stringWithUTF8String: start] stringByAppendingString: @".app"]; if ([seen containsObject: bp]) continue; [seen addObject: bp];
		if ([bp hasPrefix: @"/System/Library/CoreServices/"] && ![bp hasSuffix: @"/Finder.app"]) continue;       /* the system's own helpers (Dock, SystemUIServer, ...) are not in the list */
		FQApp *a = [FQApp new]; a->path = bp; a->pid = pid; a->name = [[bp lastPathComponent] stringByDeletingPathExtension]; a->icon = [[NSWorkspace sharedWorkspace] iconForFile: bp]; [r addObject: a];
	} pclose(f); }
	[r sortUsingComparator: ^NSComparisonResult(FQApp *x, FQApp *y) { return [x->name caseInsensitiveCompare: y->name]; }]; apps = r;
}
- (void)show
{
	[self scan];
	if (!win) {
		win = [[FQPanel alloc] initWithContentRect: NSMakeRect(0, 0, 370, 288) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask backing: NSBackingStoreBuffered defer: NO];   /* 320 with the title bar (32) */
		[win setTitle: @"Force Quit Applications"]; [win setReleasedWhenClosed: NO]; [win setDelegate: self]; [win setLevel: NSFloatingWindowLevel]; [win setHidesOnDeactivate: NO];
		NSView *cv = [win contentView];
		NSTextField *hint = [NSTextField labelWithString: @"If an app doesn’t respond for a while, select its name and click Relaunch."]; [hint setFrame: NSMakeRect(19, 288 - 19 - 34, 332, 34)]; [hint setFont: [NSFont systemFontOfSize: 13]]; [hint setLineBreakMode: NSLineBreakByWordWrapping]; [[hint cell] setWraps: YES]; [cv addSubview: hint];
		NSScrollView *sc = [[NSScrollView alloc] initWithFrame: NSMakeRect(20, 288 - 60 - 168, 330, 168)]; [sc setHasVerticalScroller: YES]; [sc setBorderType: NSBezelBorder];
		table = [[FQTable alloc] initWithFrame: NSMakeRect(0, 0, 328, 168)]; [table setRowHeight: 22]; [table setHeaderView: nil]; [table setIntercellSpacing: NSMakeSize(0, 0)]; [table setAllowsEmptySelection: YES]; [table setAllowsMultipleSelection: NO];
		NSTableColumn *ic = [[NSTableColumn alloc] initWithIdentifier: @"icon"]; [ic setWidth: 24]; [ic setMinWidth: 24]; [ic setMaxWidth: 24]; [ic setDataCell: [[NSImageCell alloc] init]]; [table addTableColumn: ic];
		NSTableColumn *nc = [[NSTableColumn alloc] initWithIdentifier: @"name"]; [nc setWidth: 300]; [[nc dataCell] setFont: [NSFont systemFontOfSize: 13]]; [table addTableColumn: nc];
		((FQPanel *)win)->fqTable = table; [table setDataSource: self]; [table setDelegate: self]; [table setTarget: self]; [table setDoubleAction: @selector(forceQuit:)]; [sc setDocumentView: table]; [cv addSubview: sc];
		NSTextField *note = [NSTextField labelWithString: @"You can open this window by pressing Command‑Option‑Escape."]; [note setFrame: NSMakeRect(19, 288 - 243 - 28, 244, 28)]; [note setFont: [NSFont systemFontOfSize: 11]]; [note setLineBreakMode: NSLineBreakByWordWrapping]; [[note cell] setWraps: YES]; [cv addSubview: note];
		button = [[NSButton alloc] initWithFrame: NSMakeRect(269, 288 - 243 - 30, 86, 30)]; [button setBezelStyle: NSRoundedBezelStyle]; [button setTarget: self]; [button setAction: @selector(forceQuit:)]; [button setKeyEquivalent: @"\r"]; [cv addSubview: button];
	}
		[table reloadData]; [self refreshButton]; { NSRect sf = [[NSScreen mainScreen] frame], wf = [win frame]; [win setFrameOrigin: NSMakePoint(NSMidX(sf) - wf.size.width / 2, NSMaxY(sf) - 30 - 140 - wf.size.height)]; } [NSApp activateIgnoringOtherApps: YES]; [win makeKeyAndOrderFront: nil]; [win makeFirstResponder: table];
}
- (void)refreshButton
{
	NSInteger r = [table selectedRow]; FQApp *a = r >= 0 && r < (NSInteger)[apps count] ? apps[r] : nil; BOOL fin = a && [a->path hasSuffix: @"/Finder.app"];
	[button setTitle: fin ? @"Relaunch" : @"Force Quit"]; [button setEnabled: a != nil];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t { return (NSInteger)[apps count]; }
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r { if (r < 0 || r >= (NSInteger)[apps count]) return nil; FQApp *a = apps[r]; return [[c identifier] isEqual: @"icon"] ? a->icon : a->name; }
- (void)tableView:(NSTableView *)t willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)c row:(NSInteger)r { if ([cell respondsToSelector: @selector(setTextColor:)]) [cell setTextColor: [t isRowSelected: r] ? [NSColor whiteColor] : [NSColor controlTextColor]]; }
- (void)tableViewSelectionDidChange:(NSNotification *)n { if (getenv("FQ_DEBUG")) NSLog(@"fq: selection %ld", (long)[table selectedRow]); [self refreshButton]; }
- (BOOL)tableView:(NSTableView *)t shouldSelectRow:(NSInteger)r { if (getenv("FQ_DEBUG")) NSLog(@"fq: shouldSelect %ld", (long)r); return YES; }
- (void)forceQuit:(id)s
{
	NSInteger r = [table selectedRow]; if (r < 0 || r >= (NSInteger)[apps count]) return; FQApp *a = apps[r]; BOOL fin = [a->path hasSuffix: @"/Finder.app"];
	if (!fin) {
		NSAlert *al = [[NSAlert alloc] init]; [al setMessageText: [NSString stringWithFormat: @"Do you want to force %@ to quit?", a->name]]; [al setInformativeText: @"You will lose any unsaved changes."]; [al addButtonWithTitle: @"Force Quit"]; [al addButtonWithTitle: @"Cancel"];
		if ([al runModal] != NSAlertFirstButtonReturn) return;
	}
	kill(a->pid, SIGKILL);       /* the Finder is started again by launchd (KeepAlive): that is the Relaunch */
	if (fin) [self performSelector: @selector(ensureFinder) withObject: nil afterDelay: 12.0];       /* without launchd (a dev machine) it is started here */
	[self performSelector: @selector(rescan) withObject: nil afterDelay: 0.5];
}
- (void)ensureFinder
{
	if (system("pgrep -f 'Finder.app/Contents/MacOS/Finder' >/dev/null 2>&1") == 0 || system("pgrep -x Finder >/dev/null 2>&1") == 0) return;
	NSString *f = @"/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"; NSTask *t = [[NSTask alloc] init];
	if ([[NSFileManager defaultManager] isExecutableFileAtPath: @"/usr/lib/dyld"]) { [t setLaunchPath: @"/usr/lib/dyld"]; [t setArguments: @[ f ]]; } else { [t setLaunchPath: f]; }
	@try { [t launch]; } @catch (NSException *e) {}
}
- (void)rescan { [self scan]; [table reloadData]; [self refreshButton]; }
@end

void ShowForceQuit(void) { [[FQController shared] show]; }
@interface FQObserver : NSObject @end
@implementation FQObserver - (void)show:(NSNotification *)n { @try { ShowForceQuit(); } @catch (NSException *e) { NSLog(@"Force Quit: %@", e); } } @end
void ForceQuitStart(void)
{
	static FQObserver *o; if (o) return; o = [[FQObserver alloc] init];
	[[NSDistributedNotificationCenter defaultCenter] addObserver: o selector: @selector(show:) name: @"com.wsbsd.forcequit.show" object: nil suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
}
