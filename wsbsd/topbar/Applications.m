/* The Applications window ("Apps" in the Dock, Command-1 in Spotlight): the macOS 27 Launchpad replacement, laid out from the accessibility tree of the real window (844 x 617 centred, its top at 29 % of the screen):
 * a Back button (191, 28; 34 x 26), the search field (235, 29; 377 x 28), the "More" button (624, 28; 23 x 28), a row of category chips at y 117 (26 high, 8 apart), and under it, from y 158, a scroll area 844 x 459 with
 * cells 112 x 92 on a pitch of 112.5 x 102 (seven to a row, the icon 77 x 77 at (17, -1) from the cell, the name 18 high at y 75). The applications are the bundles of /Applications, /System/Applications and
 * /System/Applications/Utilities; the category of an application is its LSApplicationCategoryType (Other when it has none). Standard AppKit controls: NSSearchField, NSButton, NSScrollView. */
#import <AppKit/AppKit.h>

@interface NSObject (APRound) + (void)roundWindow:(NSWindow *)w radius:(int)r; @end
#define AW 844.0
#define AH 617.0

@interface APApp : NSObject { @public NSString *name, *path, *cat; NSImage *icon; } @end
@implementation APApp @end
@interface APClip : NSView @end
@implementation APClip - (BOOL)isFlipped { return YES; } @end

@interface APController : NSObject <NSSearchFieldDelegate> { NSPanel *win; NSSearchField *field; NSScrollView *scroll; NSView *grid; NSMutableArray *apps; NSString *chip; NSMutableArray *chipButtons; }
+ (instancetype)shared; - (void)toggle;
@end

static NSString *CategoryOf(NSString *bundle)
{
	NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: [bundle stringByAppendingPathComponent: @"Contents/Info.plist"]] ?: [NSDictionary dictionaryWithContentsOfFile: [bundle stringByAppendingPathComponent: @"Resources/Info-gnustep.plist"]];
	NSString *c = [[info[@"LSApplicationCategoryType"] description] lowercaseString]; if (![c length]) return @"Other";
	if ([c containsString: @"utilities"]) return @"Utilities";
	for (NSString *k in @[ @"productivity", @"finance", @"business" ]) if ([c containsString: k]) return @"Productivity & Finance";
	if ([c containsString: @"social"]) return @"Social";
	if ([c containsString: @"developer"]) return @"Developer Tools";
	for (NSString *k in @[ @"entertainment", @"games", @"music", @"video" ]) if ([c containsString: k]) return @"Entertainment";
	for (NSString *k in @[ @"graphics", @"photography", @"design" ]) if ([c containsString: k]) return @"Creativity";
	for (NSString *k in @[ @"news", @"reference", @"books", @"education", @"weather", @"lifestyle" ]) if ([c containsString: k]) return @"Information & Reading";
	return @"Other";
}

@implementation APController
+ (instancetype)shared { static APController *c; if (!c) c = [[APController alloc] init]; return c; }
- (void)scan
{
	apps = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableSet *seen = [NSMutableSet set];
	for (NSString *dir in @[ @"/Applications", @"/System/Applications", @"/System/Applications/Utilities", @"/Applications/Utilities", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"] ])
		for (NSString *n in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
			if (![n hasSuffix: @".app"]) continue; NSString *p = [dir stringByAppendingPathComponent: n], *nm = [n stringByDeletingPathExtension]; if ([seen containsObject: nm]) continue; [seen addObject: nm];
			APApp *a = [APApp new]; a->name = nm; a->path = p; a->cat = CategoryOf(p); a->icon = [[NSWorkspace sharedWorkspace] iconForFile: p]; [apps addObject: a];
		}
	[apps sortUsingComparator: ^NSComparisonResult(APApp *x, APApp *y) { return [x->name caseInsensitiveCompare: y->name]; }];
}
- (void)build
{
	NSRect sc = [[NSScreen mainScreen] frame];
	win = [[NSPanel alloc] initWithContentRect: NSMakeRect((sc.size.width - AW) / 2, MAX(8.0, sc.size.height - MIN(0.29 * sc.size.height, sc.size.height - AH - 8) - AH), AW, AH) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]]; [win setHasShadow: YES]; [win setLevel: 22]; [win setHidesOnDeactivate: NO]; [win setReleasedWhenClosed: NO];
	NSVisualEffectView *ev = [[NSVisualEffectView alloc] initWithFrame: NSMakeRect(0, 0, AW, AH)]; [ev setMaterial: NSVisualEffectMaterialPopover]; [ev setBlendingMode: NSVisualEffectBlendingModeBehindWindow]; [ev setState: NSVisualEffectStateActive]; [win setContentView: ev];
	[(id)NSClassFromString(@"WsdFinderSupport") roundWindow: win radius: 30];
	CGFloat (^Y)(CGFloat, CGFloat) = ^CGFloat(CGFloat top, CGFloat h) { return AH - top - h; };
	NSButton *back = [NSButton buttonWithTitle: @"" target: self action: @selector(back:)]; [back setFrame: NSMakeRect(191, Y(28, 26), 34, 26)]; [back setBezelStyle: NSRoundedBezelStyle]; [back setTitle: @"‹"]; [back setFont: [NSFont systemFontOfSize: 18]]; [ev addSubview: back];
	field = [[NSSearchField alloc] initWithFrame: NSMakeRect(235, Y(29, 28), 377, 28)]; [field setPlaceholderString: @"Applications"]; [field setDelegate: self]; [ev addSubview: field];
	NSButton *more = [NSButton buttonWithTitle: @"…" target: nil action: NULL]; [more setFrame: NSMakeRect(624, Y(28, 28), 23, 28)]; [more setBezelStyle: NSRoundedBezelStyle]; [ev addSubview: more];
	chipButtons = [NSMutableArray array]; CGFloat x = 20;
	for (NSString *c in @[ @"Utilities", @"Productivity & Finance", @"Social", @"Developer Tools", @"Entertainment", @"Creativity", @"Information & Reading", @"Other" ]) {
		NSButton *b = [NSButton buttonWithTitle: c target: self action: @selector(chip:)]; [b setBezelStyle: NSRoundedBezelStyle]; [b setFont: [NSFont systemFontOfSize: 12]]; [b sizeToFit]; NSRect f = [b frame]; f.origin = NSMakePoint(x, Y(117, 26)); f.size.height = 26; [b setFrame: f]; [ev addSubview: b]; [chipButtons addObject: b]; x += f.size.width + 8;
	}
	scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, AW, 459)]; [scroll setHasVerticalScroller: YES]; [scroll setDrawsBackground: NO]; [scroll setBorderType: NSNoBorder]; [ev addSubview: scroll];
	grid = [[APClip alloc] initWithFrame: NSMakeRect(0, 0, AW, 459)]; [scroll setDocumentView: grid];
}
- (void)relayout
{
	NSString *q = [[field stringValue] lowercaseString]; NSMutableArray *shown = [NSMutableArray array];
	for (APApp *a in apps) { if (chip && ![a->cat isEqual: chip]) continue; if ([q length] && [[a->name lowercaseString] rangeOfString: q].location == NSNotFound) continue; [shown addObject: a]; }
	for (NSView *v in [[grid subviews] copy]) [v removeFromSuperview];
	NSUInteger rows = ([shown count] + 6) / 7; CGFloat h = MAX(459, 12 + rows * 102 + 12); [grid setFrame: NSMakeRect(0, 0, AW, h)];
	for (NSUInteger i = 0; i < [shown count]; i++) {
		APApp *a = shown[i]; NSButton *b = [[NSButton alloc] initWithFrame: NSMakeRect(20 + (i % 7) * 112.5, 12 + (i / 7) * 102, 112, 92)];
		[b setBordered: NO]; [b setImagePosition: NSImageAbove]; [b setImage: a->icon]; [[b image] setSize: NSMakeSize(64, 64)]; [b setTitle: a->name]; [b setFont: [NSFont systemFontOfSize: 12]]; [[b cell] setLineBreakMode: NSLineBreakByTruncatingTail];
		[b setTarget: self]; [b setAction: @selector(open:)]; [b setToolTip: a->path]; [grid addSubview: b];
	}
	[grid setNeedsDisplay: YES];
	for (NSButton *b in chipButtons) [b setState: [chip isEqual: [b title]] ? NSOnState : NSOffState];
}
- (void)controlTextDidChange:(NSNotification *)n { [self relayout]; }
- (void)chip:(NSButton *)b { chip = [chip isEqual: [b title]] ? nil : [b title]; [self relayout]; }
- (void)open:(NSButton *)b { NSString *p = [b toolTip]; [win orderOut: nil]; [[NSWorkspace sharedWorkspace] launchApplication: p]; }
- (void)back:(id)s { [win orderOut: nil]; [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.spotlight.toggle" object: nil userInfo: nil deliverImmediately: YES]; }       /* the search window */
- (void)toggle
{
	if (win && [win isVisible]) { [win orderOut: nil]; return; }
	[self scan]; if (!win) [self build]; chip = nil; [field setStringValue: @""]; [self relayout];
	[NSApp activateIgnoringOtherApps: YES]; [win makeKeyAndOrderFront: nil]; [win makeFirstResponder: field];
}
@end

void ToggleApplications(void) { [[APController shared] toggle]; }
@interface APObserver : NSObject @end
@implementation APObserver - (void)toggle:(NSNotification *)n { @try { ToggleApplications(); } @catch (NSException *e) { NSLog(@"Applications: %@", e); } } @end
void ApplicationsStart(void)
{
	static APObserver *o; if (o) return; o = [[APObserver alloc] init];
	[[NSDistributedNotificationCenter defaultCenter] addObserver: o selector: @selector(toggle:) name: @"com.wsbsd.apps.toggle" object: nil suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
}
