/* The Spotlight window (the search item of the status area), measured on the Mac (3440 x 1440): 640 wide, centred, its top at 30 % of the screen height, the search row is 56 high (the magnifier 25 x 22 centred at (35, 27), the text from x 62 with its centre at y 28), a 1 pt line at y 56 (600 wide from x 20), results from y 67 in cells 619 wide at x 2 on a pitch of 57: an application's icon 47 at (13, 5) from the cell,
 * another icon 38 at (17, 10), the title at x 70 (23 high; at y 17 alone, at y 7 with a subtitle at y 29), the chosen row a light rounded rectangle (x 10, 603 wide); 7 rows are visible, the window is 467 high with them.
 * Read from the accessibility tree of the real window (it belongs to the process "Siri AI"). Not measured: the corner radius and the blur; the rest of the look is from a capture. The results here are the applications and the files whose name holds the text (the system has no Spotlight index). */
#import <AppKit/AppKit.h>
@interface NSObject (SPSymbols) + (void)drawIconOfName:(NSString *)n directory:(BOOL)d inRect:(NSRect)r; + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end

#define SW 640.0
#define SROW 57.0
#define STOP 67.0
@interface SPView : NSView { @public NSMutableString *query; NSMutableArray *hits; NSInteger sel; NSInteger first; NSWindow *win; }
@end
static NSArray *Roots(void) { return @[ @"/Applications", @"/System/Applications", @"/Applications/Utilities", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"], NSHomeDirectory() ]; }
static void Collect(NSString *dir, NSString *q, int depth, NSMutableArray *out, NSFileManager *fm, NSDate *end)
{
	if (depth > 3 || [out count] > 60 || [end timeIntervalSinceNow] < 0) return;
	for (NSString *n in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
		if ([n hasPrefix: @"."]) continue; NSString *p = [dir stringByAppendingPathComponent: n]; BOOL d = NO; [fm fileExistsAtPath: p isDirectory: &d];
		if ([n rangeOfString: q options: NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) [out addObject: p];
		if (d && ![[n pathExtension] isEqual: @"app"] && ![n isEqual: @"Library"] && ![[n pathExtension] length] == 0) {} if (d && ![n isEqual: @"Library"] && ![[n pathExtension] isEqual: @"app"]) Collect(p, q, depth + 1, out, fm, end);
	}
}
@implementation SPView
- (BOOL)isFlipped { return YES; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil; hits = [NSMutableArray array];
	query = [NSMutableString string];
	return self;
}
- (void)search:(NSString *)q
{ [self setNeedsDisplay: YES];
	[hits removeAllObjects]; sel = 0; first = 0; if ([q length]) {
		NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *r = [NSMutableArray array]; NSDate *end = [NSDate dateWithTimeIntervalSinceNow: 0.25];
		for (NSString *root in Roots()) Collect(root, q, [root isEqual: NSHomeDirectory()] ? 1 : 2, r, fm, end);
		[r sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) { BOOL aa = [[a pathExtension] isEqual: @"app"], bb = [[b pathExtension] isEqual: @"app"]; if (aa != bb) return aa ? NSOrderedAscending : NSOrderedDescending; BOOL ap = [[[a lastPathComponent] lowercaseString] hasPrefix: [q lowercaseString]], bp = [[[b lastPathComponent] lowercaseString] hasPrefix: [q lowercaseString]]; if (ap != bp) return ap ? NSOrderedAscending : NSOrderedDescending; return [[a lastPathComponent] caseInsensitiveCompare: [b lastPathComponent]]; }];
		[hits addObjectsFromArray: r];
	}
	NSInteger rows = MIN(7, (NSInteger)[hits count]); double h = [hits count] ? STOP + rows * SROW + 1 : 56; NSRect f = [win frame]; double top = NSMaxY(f); f.size.height = h; f.origin.y = top - h; [win setFrame: f display: YES]; [self setFrameSize: NSMakeSize(SW, h)]; [self setNeedsDisplay: YES];
}
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)keyDown:(NSEvent *)e
{
	NSString *c = [e characters]; if (![c length]) return; unichar k = [c characterAtIndex: 0];
	if (k == 0x1b) { [win orderOut: nil]; return; }
	if (k == '\r' || k == '\n') { if ([hits count]) { [[NSWorkspace sharedWorkspace] openFile: hits[sel]]; [win orderOut: nil]; } return; }
	if (k == NSDownArrowFunctionKey) { if (sel + 1 < (NSInteger)[hits count]) { sel++; if (sel >= first + 7) first = sel - 6; [self setNeedsDisplay: YES]; } return; }
	if (k == NSUpArrowFunctionKey) { if (sel > 0) { sel--; if (sel < first) first = sel; [self setNeedsDisplay: YES]; } return; }
	if (k == 0x7f || k == 8) { if ([query length]) { [query deleteCharactersInRange: NSMakeRange([query length] - 1, 1)]; [self search: query]; } return; }
	if (k >= 32 && k != 0x7f && !(k >= 0xF700 && k <= 0xF8FF)) { [query appendString: c]; [self search: query]; }
}
- (void)drawRect:(NSRect)dirty
{
	NSRect b = [self bounds]; NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: b xRadius: 28 yRadius: 28]; [[NSColor colorWithCalibratedRed: 0.13 green: 0.13 blue: 0.14 alpha: 0.96] setFill]; [p fill];
	NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(b, 0.5, 0.5) xRadius: 28 yRadius: 28]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.16] setStroke]; [rim stroke];
	{ NSString *shown = [query length] ? query : @"Spotlight Search"; NSColor *tc = [query length] ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite: 1 alpha: 0.45]; NSDictionary *qa = @{ NSFontAttributeName: [NSFont systemFontOfSize: 20], NSForegroundColorAttributeName: tc }; NSSize qs = [shown sizeWithAttributes: qa]; [shown drawAtPoint: NSMakePoint(62, 28 - qs.height / 2) withAttributes: qa]; if ([query length]) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.85] setFill]; NSRectFill(NSMakeRect(62 + qs.width + 1, 15, 1.5, 26)); } }
	[NSClassFromString(@"WsdFinderSupport") drawSymbol: @"magnifyingglass" inRect: NSMakeRect(23, 16, 25, 22) size: 22 weight: 5 color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.7]];
	NSDictionary *tf = @{ NSFontAttributeName: [NSFont systemFontOfSize: 15], NSForegroundColorAttributeName: [NSColor whiteColor] }, *sf = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.5] };
	for (NSInteger i = first; i < (NSInteger)[hits count] && i < first + 7; i++) {
		double y = STOP - 10 + (i - first) * SROW + 10; NSString *path = hits[i]; BOOL app = [[path pathExtension] isEqual: @"app"];
		if (i == sel) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.16] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSMakeRect(10, y, 603, SROW - 1) xRadius: 14 yRadius: 14] fill]; }
		BOOL isDir = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &isDir]; Class fs = NSClassFromString(@"WsdFinderSupport"); if (app) { NSImage *ic = [[NSWorkspace sharedWorkspace] iconForFile: path]; [ic drawInRect: NSMakeRect(13, y + 5, 47, 47) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else [fs drawIconOfName: [path lastPathComponent] directory: isDir inRect: NSMakeRect(17, y + 10, 38, 38)];
		NSString *name = app ? [[path lastPathComponent] stringByDeletingPathExtension] : [path lastPathComponent]; if (app) [name drawAtPoint: NSMakePoint(70, y + 17 + (23 - [name sizeWithAttributes: tf].height) / 2) withAttributes: tf]; else { [name drawAtPoint: NSMakePoint(70, y + 7 + (23 - [name sizeWithAttributes: tf].height) / 2) withAttributes: tf]; [[[path stringByDeletingLastPathComponent] lastPathComponent] drawAtPoint: NSMakePoint(70, y + 29 + (21 - [@"X" sizeWithAttributes: sf].height) / 2) withAttributes: sf]; }
	}
}
@end

@interface SPWindow : NSWindow @end
@implementation SPWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
@end
void ToggleSpotlight(void)
{
	static NSWindow *w; static SPView *v; NSRect scr = [[NSScreen mainScreen] frame];
	if (w && [w isVisible]) { [w orderOut: nil]; return; }
	if (!w) {
		w = [[SPWindow alloc] initWithContentRect: NSMakeRect((scr.size.width - SW) / 2, scr.size.height - 0.30 * scr.size.height - 56, SW, 56) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; v = [[SPView alloc] initWithFrame: NSMakeRect(0, 0, SW, 56)]; v->win = w; [w setContentView: v];
	}
	[v->query setString: @""]; [v search: @""]; [NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil]; [w makeFirstResponder: v];
}
