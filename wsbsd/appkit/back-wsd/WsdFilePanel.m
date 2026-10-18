/* The Open and Save panels of the Mac, drawn after the real ones (AppKit's NSOpenPanel / NSSavePanel run in the "Open and Save Panel Service", not in the Finder). The sizes and colours come from the panel of this Mac measured in a test program:
 * the Open panel is 880 x 448 with a sidebar 135 wide, a toolbar 63 high, columns 244 wide with rows of 22, a bar of 66 at the bottom; the Save panel is a form of 370 x 204 (Save As, Tags, Where).
 * GNUstep's NSSavePanel / NSOpenPanel stay the API: -[NSApplication runModalForWindow:] of one of them runs this panel instead, and the answers are handed out through the panel's accessors. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <math.h>

static IMP origSetName, origRunModal, origRunModalRel, origBeginCompletion, origSaveFilename, origOpenFilenames;
static const char kResult = 0;

@interface GSDisplayServer (WsdCorners) - (void) wsdWindowCorners: (int)radius : (int)win; @end
static void RoundWindow(NSWindow *w, int radius) { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdWindowCorners::)]) [srv wsdWindowCorners: radius : (int)[w windowNumber]]; }
static NSTextField *Field(NSRect f, NSString *val); static NSButton *Btn(NSString *title, NSRect f, id target, SEL action, BOOL def);
static NSColor *RGB(int r, int g, int b) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: 1]; }
static NSColor *RGBA(int r, int g, int b, double a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }
static BOOL PDark(void) { const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }
/* the palette: measured on the dark panel (the light one is the same structure on white) */
#define P_CONTENT   (PDark() ? RGB(28, 36, 44) : RGB(255, 255, 255))
#define P_SIDEBAR   (PDark() ? RGB(31, 41, 50) : RGB(236, 236, 238))
#define P_CONTROL   (PDark() ? RGB(45, 52, 60) : RGB(245, 245, 247))
#define P_FIELD     (PDark() ? RGB(23, 24, 25) : RGB(255, 255, 255))
#define P_LINE      (PDark() ? RGB(50, 57, 65) : RGB(214, 214, 218))
#define P_SELECT    (PDark() ? RGB(46, 55, 64) : RGB(222, 222, 226))
#define P_TEXT      (PDark() ? RGBA(255, 255, 255, 0.85) : RGBA(0, 0, 0, 0.85))
#define P_DIM       (PDark() ? RGBA(255, 255, 255, 0.42) : RGBA(0, 0, 0, 0.42))
#define P_HEADER    (PDark() ? RGB(150, 157, 160) : RGB(120, 120, 124))

static NSDictionary *Attr(CGFloat size, BOOL bold, NSColor *col) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: size] : [NSFont systemFontOfSize: size], NSForegroundColorAttributeName: col }; }
static void Text(NSString *s, NSPoint left_center, CGFloat size, BOOL bold, NSColor *col, BOOL flipped)       /* the text's vertical centre at left_center.y */
{
	NSDictionary *a = Attr(size, bold, col); NSSize ts = [s sizeWithAttributes: a];
	[s drawAtPoint: NSMakePoint(left_center.x, left_center.y - ts.height / 2) withAttributes: a]; (void)flipped;
}
static void TextFit(NSString *s, NSPoint left_center, CGFloat size, NSColor *col, CGFloat maxW)               /* the text cut with an ellipsis to fit */
{
	NSDictionary *a = Attr(size, NO, col);
	if ([s sizeWithAttributes: a].width > maxW) { NSString *t = s; while ([t length] > 1 && [[t stringByAppendingString: @"\u2026"] sizeWithAttributes: a].width > maxW) t = [t substringToIndex: [t length] - 1]; s = [t stringByAppendingString: @"\u2026"]; }
	Text(s, left_center, size, NO, col, NO);
}
static void FillRound(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }

/* ---- icons: a folder, a PDF, a plain document, drawn in a 16 pt box */
static void DrawFolder(NSRect r)
{
	NSBezierPath *b = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(r.origin.x, r.origin.y + 2.5, r.size.width, r.size.height - 4.5) xRadius: 2 yRadius: 2];
	[RGB(86, 176, 244) setFill]; [b fill];
	NSBezierPath *tab = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(r.origin.x, r.origin.y + 0.5, r.size.width * 0.45, 4) xRadius: 1.5 yRadius: 1.5]; [RGB(64, 150, 226) setFill]; [tab fill];
}
static void DrawDoc(NSRect r, BOOL pdf)
{
	NSRect d = NSInsetRect(r, 2.5, 0.5); FillRound(d, 1.5, pdf ? RGB(250, 250, 250) : RGB(236, 238, 240));
	if (pdf) { [RGB(214, 40, 40) setFill]; NSRectFill(NSMakeRect(d.origin.x + 1.5, d.origin.y + d.size.height * 0.45, d.size.width - 3, 3)); }
	else { [RGB(170, 176, 182) setFill]; for (int i = 0; i < 3; i++) NSRectFill(NSMakeRect(d.origin.x + 2, d.origin.y + 4 + i * 3, d.size.width - 5, 1)); }
}

/* ---- the entries of a directory, newest first, in the groups the Mac shows */
@interface WsdEntry : NSObject { @public NSString *name, *path; BOOL dir, enabled; NSDate *date; } @end
@implementation WsdEntry @end
static NSString *GroupOf(NSDate *d)
{
	NSCalendar *cal = [NSCalendar currentCalendar]; NSDate *now = [NSDate date]; NSTimeInterval age = [now timeIntervalSinceDate: d];
	NSDateComponents *a = [cal components: NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate: d], *n = [cal components: NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate: now];
	if ([a day] == [n day] && [a month] == [n month] && [a year] == [n year]) return @"Today";
	if (age < 2 * 86400 && [a day] != [n day]) return @"Yesterday";
	if (age < 7 * 86400) return @"Previous 7 Days";
	if (age < 30 * 86400) return @"Previous 30 Days";
	NSArray *months = @[ @"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December" ];
	NSString *m = months[([a month] - 1) % 12];
	return [a year] == [n year] ? m : [NSString stringWithFormat: @"%@ %ld", m, (long)[a year]];
}

static NSString *KindOf(NSString *path, BOOL dir)
{
	if (dir) return @"Folder";
	static NSDictionary *k; if (!k) k = @{ @"pdf": @"PDF document", @"txt": @"Plain text document", @"c": @"C source code", @"h": @"C header", @"m": @"Objective-C source code", @"py": @"Python script", @"md": @"Markdown document", @"png": @"PNG image", @"jpg": @"JPEG image", @"jpeg": @"JPEG image", @"gif": @"GIF image", @"tiff": @"TIFF image", @"zip": @"ZIP archive", @"hex": @"Document", @"elf": @"Unix executable", @"js": @"JavaScript source code", @"json": @"JSON document", @"html": @"HTML document", @"sh": @"Shell script", @"iso": @"Disk image", @"log": @"Log file" };
	return k[[[path pathExtension] lowercaseString]] ?: @"Document";
}
static NSString *SizeText(unsigned long long n)
{
	if (n < 1024) return [NSString stringWithFormat: @"%llu bytes", n];
	if (n < 1024ULL * 1024) return [NSString stringWithFormat: @"%.0f KB", n / 1024.0];
	if (n < 1024ULL * 1024 * 1024) return [NSString stringWithFormat: @"%.1f MB", n / 1048576.0];
	return [NSString stringWithFormat: @"%.2f GB", n / 1073741824.0];
}
static void DrawFileIcon(NSRect ic, NSString *name)
{
	NSString *ext = [[name pathExtension] lowercaseString];
	if ([ext isEqual: @"pdf"]) { DrawDoc(ic, YES); return; }
	DrawDoc(ic, NO);
	NSString *badge = ([ext isEqual: @"c"] || [ext isEqual: @"h"] || [ext isEqual: @"m"]) ? ext : ([ext isEqual: @"py"] ? @"py" : nil);
	if (badge) { NSDictionary *a = Attr(9, YES, RGB(60, 130, 230)); NSSize ts = [badge sizeWithAttributes: a]; [badge drawAtPoint: NSMakePoint(NSMidX(ic) - ts.width / 2, NSMidY(ic) - ts.height / 2 + 1) withAttributes: a]; }
}

/* ---- the preview of a selected file: a picture, the name, the kind and size, Information */
@interface WsdPreview : NSView { @public NSString *path; } @end
@implementation WsdPreview
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty); if (!path) return;
	NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: path error: NULL]; double W = [self bounds].size.width;
	NSString *ext = [[path pathExtension] lowercaseString]; NSImage *img = [@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"bmp" ] containsObject: ext] ? [[NSImage alloc] initWithContentsOfFile: path] : nil;
	NSRect th = NSMakeRect(floor((W - 132) / 2) - 2, 11, 132, 188);                                        /* the picture: a page of 132 x 188 */
	if (img && [img size].width > 0) { double k = fmin(132.0 / [img size].width, 188.0 / [img size].height); NSSize z = NSMakeSize([img size].width * k, [img size].height * k); NSRect r = NSMakeRect(NSMidX(th) - z.width / 2, NSMidY(th) - z.height / 2, z.width, z.height); [img drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
	else { [RGB(250, 250, 250) setFill]; NSRectFill(th); NSRect ic = NSMakeRect(NSMidX(th) - 28, NSMidY(th) - 34, 56, 68); DrawFileIcon(ic, [path lastPathComponent]); }
	Text([path lastPathComponent], NSMakePoint(11, 230 + 7), 15, YES, P_TEXT, YES);
	Text([NSString stringWithFormat: @"%@ - %@", KindOf(path, NO), SizeText([at fileSize])], NSMakePoint(11, 252 + 6), 13, NO, P_DIM, YES);
	Text(@"Information", NSMakePoint(11, 275 + 5), 13, YES, P_TEXT, YES);
	NSDictionary *la = Attr(13, NO, RGB(10, 132, 255)); NSSize ls = [@"Show More" sizeWithAttributes: la]; [@"Show More" drawAtPoint: NSMakePoint(W - 28 - ls.width, 275 + 5 - ls.height / 2) withAttributes: la];
	NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"EEEE, d MMMM yyyy 'at' HH:mm"];
	NSArray *rows = @[ @[ @"Created", [at fileCreationDate] ?: [NSDate date] ], @[ @"Modified", [at fileModificationDate] ?: [NSDate date] ] ]; double y = 299 + 5;
	for (NSArray *r in rows) { [P_LINE setFill]; NSRectFill(NSMakeRect(11, y - 15, W - 24, 1)); Text(r[0], NSMakePoint(11, y + 4), 13, NO, P_DIM, YES); NSString *v = [df stringFromDate: r[1]]; NSDictionary *va = Attr(13, NO, P_TEXT); NSSize vs = [v sizeWithAttributes: va]; [v drawAtPoint: NSMakePoint(W - 28 - vs.width, y + 4 - vs.height / 2) withAttributes: va]; y += 24; }
}
@end

/* ---- one column of the browser */
@class WsdColumn;
@protocol WsdColumnDelegate - (void)column:(WsdColumn *)c clicked:(WsdEntry *)e doubleClick:(BOOL)dbl; @end
@interface WsdColumn : NSView { @public NSString *dir; NSMutableArray *rows; NSInteger selected; BOOL active; id<WsdColumnDelegate> delegate; NSArray *types; BOOL filesOK, dirsOK; NSString *filter; } @end
@implementation WsdColumn
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { active = YES; [self setNeedsDisplay: YES]; return YES; }
- (BOOL)isFlipped { return YES; }
- (void)load
{
	rows = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *ents = [NSMutableArray array];
	for (NSString *n in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
		if ([n hasPrefix: @"."]) continue;
		if ([filter length] && [n rangeOfString: filter options: NSCaseInsensitiveSearch].location == NSNotFound) continue;
		WsdEntry *e = [WsdEntry new]; e->name = n; e->path = [dir stringByAppendingPathComponent: n]; BOOL d = NO; [fm fileExistsAtPath: e->path isDirectory: &d]; e->dir = d;
		e->date = [[fm attributesOfItemAtPath: e->path error: NULL] fileModificationDate] ?: [NSDate distantPast];
		e->enabled = d || (filesOK && (!types.count || [types containsObject: [[n pathExtension] lowercaseString]]));
		[ents addObject: e];
	}
	[ents sortUsingComparator: ^NSComparisonResult(WsdEntry *a, WsdEntry *b) { return [b->date compare: a->date]; }];
	NSString *last = nil;
	for (WsdEntry *e in ents) { NSString *g = GroupOf(e->date); if (![g isEqualToString: last]) { [rows addObject: g]; last = g; } [rows addObject: e]; }
	selected = -1;
	double h = 8; BOOL first = YES; for (id r in rows) { if ([r isKindOfClass: [NSString class]]) { h += first ? 26 : 48; first = NO; } else h += 22; }
	[self setFrameSize: NSMakeSize([self frame].size.width, fmax(h + 8, 40))];
}
- (NSRect)rectOfRow:(NSInteger)i
{
	double y = 0; BOOL first = YES;
	for (NSInteger k = 0; k <= i; k++) {
		id r = rows[k];
		if ([r isKindOfClass: [NSString class]]) { y += first ? 8 : 22; if (k == i) return NSMakeRect(0, y, [self bounds].size.width, 26); y += 26; first = NO; }
		else { if (k == i) return NSMakeRect(0, y, [self bounds].size.width, 22); y += 22; }
	}
	return NSZeroRect;
}
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty);
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) {
		NSRect rr = [self rectOfRow: i]; if (!NSIntersectsRect(rr, dirty)) continue; id r = rows[i];
		if ([r isKindOfClass: [NSString class]]) { Text(r, NSMakePoint(37, NSMinY(rr) + 14), 11, YES, P_HEADER, YES); continue; }
		WsdEntry *e = r; BOOL sel = i == selected; double W = rr.size.width;
		if (sel) { NSColor *sc = active ? RGB(0, 89, 209) : P_SELECT; if (e->dir) FillRound(NSMakeRect(10, NSMinY(rr), W - 20, 22), 7, sc); else { [sc setFill]; NSRectFill(NSMakeRect(0, NSMinY(rr), W, 22)); } }     /* a folder's row is a rounded capsule, a file's runs edge to edge */
		NSRect ic = NSMakeRect(17, NSMinY(rr) + 3, 16, 16);
		if (e->dir) DrawFolder(ic); else DrawFileIcon(ic, e->name);
		NSColor *tc = sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM);
		TextFit(e->name, NSMakePoint(40, NSMidY(rr)), 13, tc, W - 40 - (e->dir ? 30 : 14));
		if (e->dir) { NSBezierPath *p = [NSBezierPath bezierPath]; double cx = W - 22, cy = NSMidY(rr); [p setLineWidth: 1.3]; [p moveToPoint: NSMakePoint(cx, cy - 3.5)]; [p lineToPoint: NSMakePoint(cx + 3.5, cy)]; [p lineToPoint: NSMakePoint(cx, cy + 3.5)]; [(sel && active ? [NSColor whiteColor] : P_DIM) setStroke]; [p stroke]; }
	}
}
- (void)keyDown:(NSEvent *)ev
{
	NSString *k = [ev characters]; if (![k length]) return; unichar ch = [k characterAtIndex: 0];
	NSInteger n = (NSInteger)[rows count], i = selected;
	if (ch == NSDownArrowFunctionKey || ch == NSUpArrowFunctionKey) {
		NSInteger d = ch == NSDownArrowFunctionKey ? 1 : -1; i = i < 0 ? (d > 0 ? -1 : n) : i;
		for (i += d; i >= 0 && i < n; i += d) if (![rows[i] isKindOfClass: [NSString class]] && ((WsdEntry *)rows[i])->enabled) break;
		if (i < 0 || i >= n) return;
		selected = i; [self scrollRectToVisible: [self rectOfRow: i]]; [self setNeedsDisplay: YES]; [delegate column: self clicked: rows[i] doubleClick: NO];
	} else if (ch == NSRightArrowFunctionKey) [(id)delegate performSelector: @selector(focusNextColumnFrom:) withObject: self];
	else if (ch == NSLeftArrowFunctionKey) [(id)delegate performSelector: @selector(focusPreviousColumnFrom:) withObject: self];
	else [super keyDown: ev];
}
- (void)mouseDown:(NSEvent *)ev
{
	[[self window] makeFirstResponder: self];
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) if (![rows[i] isKindOfClass: [NSString class]] && NSPointInRect(p, [self rectOfRow: i])) {
		WsdEntry *e = rows[i]; if (!e->enabled) return;
		selected = i; [self setNeedsDisplay: YES]; [delegate column: self clicked: e doubleClick: [ev clickCount] >= 2]; return;
	}
}
@end

/* ---- the list: name, size, kind, date added (the expanded Save panel; also the Open panel's list mode) */
@interface WsdListColumn : WsdColumn @end
@implementation WsdListColumn
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty); double W = [self bounds].size.width;
	NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"d MMM yyyy 'at' HH:mm"];
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) {
		NSRect rr = [self rectOfRow: i]; if (!NSIntersectsRect(rr, dirty)) continue; id r = rows[i];
		if ([r isKindOfClass: [NSString class]]) { Text(r, NSMakePoint(40, NSMinY(rr) + 14), 11, YES, P_HEADER, YES); continue; }
		WsdEntry *e = r; BOOL sel = i == selected;
		if (sel) FillRound(NSMakeRect(10, NSMinY(rr), W - 20, 22), 7, active ? RGB(0, 89, 209) : P_SELECT);
		NSColor *tc = sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM), *dc = sel && active ? RGBA(255, 255, 255, 0.85) : P_DIM;
		NSRect ic = NSMakeRect(26, NSMinY(rr) + 3, 16, 16); if (e->dir) DrawFolder(ic); else DrawFileIcon(ic, e->name);
		TextFit(e->name, NSMakePoint(48, NSMidY(rr)), 13, tc, 250 - 48 - 12);
		NSDictionary *at = [[NSFileManager defaultManager] attributesOfItemAtPath: e->path error: NULL];
		NSString *sz = e->dir ? @"--" : SizeText([at fileSize]); NSDictionary *sa = Attr(13, NO, dc); NSSize ss = [sz sizeWithAttributes: sa]; [sz drawAtPoint: NSMakePoint(341 - ss.width, NSMidY(rr) - ss.height / 2) withAttributes: sa];
		Text(KindOf(e->path, e->dir), NSMakePoint(355, NSMidY(rr)), 13, NO, dc, YES);
		Text([df stringFromDate: e->date], NSMakePoint(469, NSMidY(rr)), 13, NO, dc, YES);
	}
}
@end
/* ---- the icon view: a grid of 96 x 92 cells, the picture above the name */
@interface WsdIconColumn : WsdColumn { NSMutableArray *ents; NSInteger perRow; } @end
@implementation WsdIconColumn
- (void)load
{
	[super load]; ents = [NSMutableArray array]; for (id r in rows) if (![r isKindOfClass: [NSString class]]) [ents addObject: r];
	double W = [self frame].size.width; perRow = (NSInteger)fmax(1, floor((W - 16) / 96)); NSInteger nr = ((NSInteger)[ents count] + perRow - 1) / perRow;
	[self setFrameSize: NSMakeSize(W, fmax(nr * 92 + 24, 60))]; selected = -1;
}
- (NSRect)cell:(NSInteger)k { return NSMakeRect(8 + (k % perRow) * 96, 10 + (k / perRow) * 92, 96, 92); }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty);
	for (NSInteger k = 0; k < (NSInteger)[ents count]; k++) {
		NSRect c = [self cell: k]; if (!NSIntersectsRect(c, dirty)) continue; WsdEntry *e = ents[k]; BOOL sel = k == selected;
		NSRect ic = NSMakeRect(NSMidX(c) - 28, c.origin.y + 4, 56, 56);
		if (sel) FillRound(NSInsetRect(ic, -4, -3), 8, active ? RGBA(255, 255, 255, 0.14) : P_SELECT);
		NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; NSAffineTransform *t = [NSAffineTransform transform]; [t translateXBy: ic.origin.x yBy: ic.origin.y]; [t scaleBy: 3.5]; [t concat];
		if (e->dir) DrawFolder(NSMakeRect(0, 0, 16, 16)); else DrawFileIcon(NSMakeRect(0, 0, 16, 16), e->name);
		[g restoreGraphicsState];
		NSDictionary *a = Attr(12, NO, sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM)); NSString *nm = e->name;
		if ([nm sizeWithAttributes: a].width > 88) { while ([nm length] > 1 && [[nm stringByAppendingString: @"\u2026"] sizeWithAttributes: a].width > 88) nm = [nm substringToIndex: [nm length] - 1]; nm = [nm stringByAppendingString: @"\u2026"]; }
		NSSize ts = [nm sizeWithAttributes: a]; NSRect lr = NSMakeRect(NSMidX(c) - ts.width / 2 - 5, c.origin.y + 64, ts.width + 10, 18);
		if (sel && active) FillRound(lr, 6, RGB(0, 89, 209));
		[nm drawAtPoint: NSMakePoint(NSMidX(c) - ts.width / 2, lr.origin.y + 9 - ts.height / 2) withAttributes: a];
	}
}
- (void)mouseDown:(NSEvent *)ev
{
	[[self window] makeFirstResponder: self]; NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger k = 0; k < (NSInteger)[ents count]; k++) if (NSPointInRect(p, [self cell: k])) { WsdEntry *e = ents[k]; if (!e->enabled) return; selected = k; [self setNeedsDisplay: YES]; [delegate column: self clicked: e doubleClick: [ev clickCount] >= 2]; return; }
}
- (void)keyDown:(NSEvent *)ev
{
	NSString *k = [ev characters]; if (![k length]) return; unichar ch = [k characterAtIndex: 0]; NSInteger n = (NSInteger)[ents count], i = selected < 0 ? 0 : selected;
	if (ch == NSRightArrowFunctionKey) i++; else if (ch == NSLeftArrowFunctionKey) i--; else if (ch == NSDownArrowFunctionKey) i += perRow; else if (ch == NSUpArrowFunctionKey) i -= perRow; else { [super keyDown: ev]; return; }
	if (i < 0 || i >= n) return; selected = i; [self scrollRectToVisible: [self cell: i]]; [self setNeedsDisplay: YES]; [delegate column: self clicked: ents[i] doubleClick: NO];
}
@end
@interface WsdListHeader : NSView { @public NSString *group; } @end
@implementation WsdListHeader
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty); double W = [self bounds].size.width;
	[P_LINE setFill]; NSRectFill(NSMakeRect(0, 25, W, 1));
	Text(group ?: @"", NSMakePoint(40, 13), 11, YES, P_HEADER, YES);
	for (NSNumber *x in @[ @250, @347, @460 ]) NSRectFill(NSMakeRect([x doubleValue], 3, 1, 19));
	Text(@"Size", NSMakePoint(255, 13), 11, YES, P_HEADER, YES); Text(@"Kind", NSMakePoint(353, 13), 11, YES, P_HEADER, YES); Text(@"Date Added", NSMakePoint(467, 13), 11, YES, P_TEXT, YES);
	NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.3]; [ch moveToPoint: NSMakePoint(W - 28, 11)]; [ch lineToPoint: NSMakePoint(W - 24, 15)]; [ch lineToPoint: NSMakePoint(W - 20, 11)]; [P_TEXT setStroke]; [ch stroke];
}
@end

/* ---- the sidebar */
static void StrokeLine(NSBezierPath *p, double x, double y, double x2, double y2) { [p moveToPoint: NSMakePoint(x, y)]; [p lineToPoint: NSMakePoint(x2, y2)]; }
static void DrawSideIcon(NSString *name, NSRect r, NSColor *tint)                                              /* the symbols of the sidebar, drawn in the accent colour inside a 18 x 16 box */
{
	double cx = NSMidX(r), cy = NSMidY(r); NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.5]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle]; [tint setStroke]; [tint setFill];
	if ([name isEqual: @"Recents"]) { NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(cx - 7.5, cy - 7.5, 15, 15)]; [c setLineWidth: 1.5]; [c stroke]; StrokeLine(p, cx, cy - 4, cx, cy); StrokeLine(p, cx, cy, cx + 3.5, cy + 2); [p stroke]; }
	else if ([name isEqual: @"Shared"]) { [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(cx - 7, cy - 6, 6, 6)] stroke]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(cx + 1, cy - 6, 6, 6)] stroke]; [p appendBezierPathWithArcWithCenter: NSMakePoint(cx - 4, cy + 7) radius: 5 startAngle: 180 endAngle: 360]; [p appendBezierPathWithArcWithCenter: NSMakePoint(cx + 4, cy + 7) radius: 5 startAngle: 180 endAngle: 360]; [p stroke]; }
	else if ([name isEqual: @"Applications"]) { NSDictionary *a = Attr(15, YES, tint); NSSize ts = [@"A" sizeWithAttributes: a]; [@"A" drawAtPoint: NSMakePoint(cx - ts.width / 2, cy - ts.height / 2) withAttributes: a]; }
	else if ([name isEqual: @"Desktop"]) { NSBezierPath *m = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(cx - 8, cy - 6, 16, 10) xRadius: 2 yRadius: 2]; [m setLineWidth: 1.5]; [m stroke]; StrokeLine(p, cx - 4, cy + 7, cx + 4, cy + 7); StrokeLine(p, cx, cy + 4, cx, cy + 7); [p stroke]; }
	else if ([name isEqual: @"Documents"]) { StrokeLine(p, cx - 5, cy - 7, cx + 2, cy - 7); StrokeLine(p, cx + 2, cy - 7, cx + 6, cy - 3); StrokeLine(p, cx + 6, cy - 3, cx + 6, cy + 7); StrokeLine(p, cx + 6, cy + 7, cx - 5, cy + 7); StrokeLine(p, cx - 5, cy + 7, cx - 5, cy - 7); StrokeLine(p, cx + 2, cy - 7, cx + 2, cy - 3); StrokeLine(p, cx + 2, cy - 3, cx + 6, cy - 3); [p stroke]; }
	else if ([name isEqual: @"Downloads"]) { NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(cx - 7.5, cy - 7.5, 15, 15)]; [c setLineWidth: 1.5]; [c stroke]; StrokeLine(p, cx, cy - 4, cx, cy + 3.5); StrokeLine(p, cx - 3.5, cy, cx, cy + 3.5); StrokeLine(p, cx + 3.5, cy, cx, cy + 3.5); [p stroke]; }
	else if ([name isEqual: @"Macintosh HD"]) { FillRound(NSMakeRect(cx - 8, cy - 4, 16, 9), 3, P_DIM); }
	else { StrokeLine(p, cx - 7, cy + 1, cx, cy - 6); StrokeLine(p, cx, cy - 6, cx + 7, cy + 1); StrokeLine(p, cx - 5, cy, cx - 5, cy + 6); StrokeLine(p, cx - 5, cy + 6, cx + 5, cy + 6); StrokeLine(p, cx + 5, cy + 6, cx + 5, cy); [p stroke]; }     /* the home folder: a house */
}
@interface WsdSidebar : NSView { @public NSMutableArray *items; NSInteger selected; id target; SEL action; } @end
@implementation WsdSidebar
- (BOOL)isFlipped { return YES; }
- (void)setup
{
	NSString *home = NSHomeDirectory(); items = [NSMutableArray array];
	void (^add)(NSString *, NSString *, NSString *) = ^(NSString *kind, NSString *title, NSString *path) { [items addObject: @{ @"k": kind, @"t": title, @"p": path ?: @"" }]; };
	add(@"item", @"Recents", home); add(@"item", @"Shared", @"/Users");
	add(@"head", @"Favorites", nil); add(@"item", @"Applications", @"/Applications"); add(@"item", @"Desktop", [home stringByAppendingPathComponent: @"Desktop"]);
	add(@"item", @"Documents", [home stringByAppendingPathComponent: @"Documents"]); add(@"item", @"Downloads", [home stringByAppendingPathComponent: @"Downloads"]);
	add(@"head", @"Locations", nil); add(@"item", @"Macintosh HD", @"/"); add(@"item", [home lastPathComponent], home);
	add(@"head", @"Tags", nil); for (NSString *t in @[ @"Red", @"Orange", @"Yellow", @"Green", @"Blue", @"Purple", @"Gray" ]) add(@"tag", t, nil);
	selected = -1; [self setFrameSize: NSMakeSize(135, NSMaxY([self rectOfItem: (NSInteger)[items count] - 1]) + 12)];
}
- (NSRect)rectOfItem:(NSInteger)i
{
	double y = 11;                                                                                                       /* measured: rows 30 high every 32, a header 24 high with 11 above and 21 to the next row's top */
	for (NSInteger k = 0; k <= i; k++) { BOOL head = [items[k][@"k"] isEqual: @"head"]; if (head) { y += 11; if (k == i) return NSMakeRect(0, y, 135, 24); y += 21; } else { if (k == i) return NSMakeRect(10, y, 108, 30); y += 32; } }
	return NSZeroRect;
}
- (void)drawRect:(NSRect)dirty
{
	[P_SIDEBAR setFill]; NSRectFill(dirty);
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) {
		NSDictionary *it = items[i]; NSRect r = [self rectOfItem: i]; if (!NSIntersectsRect(r, dirty)) continue;
		if ([it[@"k"] isEqual: @"head"]) { Text(it[@"t"], NSMakePoint(16, NSMidY(r)), 11, YES, P_HEADER, YES); continue; }
		if (i == selected) FillRound(r, 8, P_SELECT);
		NSRect ic = NSMakeRect(18, NSMidY(r) - 8, 18, 16);
		if ([it[@"k"] isEqual: @"tag"]) {
			NSDictionary *cols = @{ @"Red": RGB(255, 69, 58), @"Orange": RGB(255, 159, 10), @"Yellow": RGB(255, 214, 10), @"Green": RGB(48, 209, 88), @"Blue": RGB(10, 132, 255), @"Purple": RGB(191, 90, 242), @"Gray": RGB(152, 152, 157) };
			[cols[it[@"t"]] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(21, NSMidY(r) - 6, 12, 12)] fill];
		} else DrawSideIcon(it[@"t"] == [NSHomeDirectory() lastPathComponent] || [it[@"p"] isEqual: NSHomeDirectory()] && ![it[@"t"] isEqual: @"Recents"] ? @"Home" : it[@"t"], ic, RGB(64, 156, 255));
		TextFit(it[@"t"], NSMakePoint(46, NSMidY(r)), 13, P_TEXT, 72);
	}
}
- (void)mouseDown:(NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) if ([items[i][@"k"] isEqual: @"item"] && NSPointInRect(p, [self rectOfItem: i])) { selected = i; [self setNeedsDisplay: YES]; [target performSelector: action withObject: items[i][@"p"]]; return; }
}
@end

/* ---- the toolbar: back / forward, view mode, grouping, the path pop-up, the search field */
@interface WsdToolbar : NSView { @public id target; BOOL canBack, canFwd, compact; int mode; NSString *pathTitle; NSTextField *search; } @end
@implementation WsdToolbar
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill([self bounds]);
	[P_LINE setFill]; NSRectFill(NSMakeRect(0, 63, [self bounds].size.width, 1));
	double x0 = 20;                                                                                               /* measured in the panel's own coordinates minus the sidebar (135) */
	FillRound(NSMakeRect(x0, 20, 50, 24), 8, P_CONTROL);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; double cx = x0 + 13 + k * 24 + (k ? -2 : 2), cy = 32; [p setLineWidth: 1.5]; [p moveToPoint: NSMakePoint(cx + (k ? -3 : 3), cy - 5)]; [p lineToPoint: NSMakePoint(cx + (k ? 3 : -3), cy)]; [p lineToPoint: NSMakePoint(cx + (k ? -3 : 3), cy + 5)]; [((k ? canFwd : canBack) ? P_TEXT : P_DIM) setStroke]; [p stroke]; }
	FillRound(NSMakeRect(76, 20, 66, 24), 8, P_CONTROL); FillRound(NSMakeRect(150, 20, 66, 24), 8, P_CONTROL);
	[P_TEXT setFill]; if (mode == 1 || compact) { for (int i = 0; i < 3; i++) NSRectFill(NSMakeRect(92, 27 + i * 4, 10, 1.6)); } else if (mode == 0) { for (int i = 0; i < 4; i++) NSRectFill(NSMakeRect(91 + (i % 2) * 6, 27 + (i / 2) * 6, 4.5, 4.5)); } else for (int i = 0; i < 3; i++) NSRectFill(NSMakeRect(90 + i * 4.5, 27, 3, 10)); for (int i = 0; i < 9; i++) NSRectFill(NSMakeRect(163 + (i % 3) * 4.5, 27 + (i / 3) * 3.6, 2.5, 2.5));
	for (int k = 0; k < 2; k++) { double cx = (k ? 200 : 126); NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.4]; [p moveToPoint: NSMakePoint(cx - 3, 30)]; [p lineToPoint: NSMakePoint(cx, 33.5)]; [p lineToPoint: NSMakePoint(cx + 3, 30)]; [P_TEXT setStroke]; [p stroke]; }
	double px = compact ? 224 : 258, pw = compact ? 198 : 229, sx = compact ? 462 : 529, sw = compact ? 195 : 196;
	NSRect pp = NSMakeRect(px, 20, pw, 24); FillRound(pp, 8, P_CONTROL);                                         /* the path pop-up: a folder, the name, the up / down arrows */
	DrawFolder(NSMakeRect(px + 10, 26, 14, 12)); Text(pathTitle ?: @"", NSMakePoint(px + 29, 32), 13, NO, P_TEXT, YES);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.2]; double cx = NSMaxX(pp) - 14, cy = k ? 35 : 29; [p moveToPoint: NSMakePoint(cx - 3, cy + (k ? -2 : 2))]; [p lineToPoint: NSMakePoint(cx, cy + (k ? 1 : -1))]; [p lineToPoint: NSMakePoint(cx + 3, cy + (k ? -2 : 2))]; [P_TEXT setStroke]; [p stroke]; }
	if (compact) { FillRound(NSMakeRect(430, 20, 22, 24), 8, P_CONTROL); NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.4]; [ch moveToPoint: NSMakePoint(436, 34)]; [ch lineToPoint: NSMakePoint(441, 30)]; [ch lineToPoint: NSMakePoint(446, 34)]; [P_TEXT setStroke]; [ch stroke]; }   /* the button that folds the browser away */
	NSBezierPath *lens = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(sx + 12, 26, 9, 9)]; [lens setLineWidth: 1.3]; [P_DIM setStroke]; [lens stroke]; (void)sw;
	NSBezierPath *hd = [NSBezierPath bezierPath]; [hd setLineWidth: 1.3]; [hd moveToPoint: NSMakePoint(sx + 20, 35)]; [hd lineToPoint: NSMakePoint(sx + 23.5, 38.5)]; [hd stroke];
}
- (void)mouseDown:(NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (NSPointInRect(p, NSMakeRect(20, 20, 25, 24)) && canBack) [target performSelector: @selector(goBack)];
	else if (NSPointInRect(p, NSMakeRect(45, 20, 25, 24)) && canFwd) [target performSelector: @selector(goForward)];
	else if (NSPointInRect(p, NSMakeRect(compact ? 224 : 258, 20, compact ? 198 : 229, 24))) [target performSelector: @selector(showPathMenu:) withObject: [NSValue valueWithPoint: NSMakePoint(compact ? 359 : 393, 44)]];
	else if (compact && NSPointInRect(p, NSMakeRect(430, 20, 22, 24))) [target performSelector: @selector(toggleExpanded)];
	else if (NSPointInRect(p, NSMakeRect(76, 20, 66, 24)) && !compact) [target performSelector: @selector(showViewMenu)];
}
@end

/* ---- the panel's content: the rounded background, the browser, the bottom bar, or the Save form */
/* the three window buttons of the expanded Save panel, over the sidebar */
@interface WsdLights : NSView { @public BOOL show; } @end
@implementation WsdLights
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r { if (!show) return; for (int k = 0; k < 3; k++) { [(k == 0 ? RGB(255, 95, 87) : k == 1 ? RGB(254, 188, 46) : RGB(40, 200, 64)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(8 + k * 24, 11, 13, 13)] fill]; } }
@end

/* the window's rounded corners: the views inside are square, this view on top cuts the corners out */
@interface WsdCorners : NSView { @public double radius; } @end
@implementation WsdCorners
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; double R = radius; NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; [g setCompositingOperation: NSCompositeCopy];
	for (int k = 0; k < 4; k++) {
		double x = (k & 1) ? NSMaxX(b) : 0, y = (k & 2) ? NSMaxY(b) : 0, sx = (k & 1) ? -1 : 1, sy = (k & 2) ? -1 : 1;
		NSBezierPath *p = [NSBezierPath bezierPath]; [p moveToPoint: NSMakePoint(x, y)]; [p lineToPoint: NSMakePoint(x + sx * R, y)];
		for (int a = 0; a <= 16; a++) { double t = a / 16.0 * M_PI / 2; [p lineToPoint: NSMakePoint(x + sx * (R - R * sin(t)), y + sy * (R - R * cos(t)))]; }
		[p closePath]; [[NSColor clearColor] setFill]; [p fill];
	}
	[g restoreGraphicsState];
}
@end

@interface WsdPanelController : NSObject <WsdColumnDelegate> {
	@public NSPanel *win; NSView *root; WsdSidebar *sidebar; WsdToolbar *toolbar; NSMutableArray *cols; NSString *dir; NSMutableArray *history; NSInteger hpos;
	NSView *corners; WsdPreview *preview; int viewMode; NSString *listDir; BOOL expanded; NSString *saveDir, *savedName, *okTitle; NSScrollView *listScroll; WsdColumn *listView; WsdListHeader *listHeader; NSButton *newFolder; NSString *searchText; BOOL isSave, filesOK, dirsOK, multiple; NSArray *types; NSString *chosen; NSButton *ok, *cancel; NSTextField *nameField; NSInteger result; NSString *message, *prompt;
}
@end
@interface WsdRoot : NSView { @public BOOL saveForm, expanded; id owner; NSString *whereTitle; } @end
@implementation WsdRoot
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	[[NSColor clearColor] set]; NSRectFillUsingOperation(r, NSCompositeCopy); FillRound([self bounds], saveForm ? 18 : 22, P_CONTENT);
	if (!saveForm) return;
	if (expanded) {                                                                                                   /* the Save panel with its browser: the window buttons, the title, the labels of the fields */
		Text(@"Save", NSMakePoint(150, 16), 13, YES, P_DIM, YES);
		NSDictionary *la = Attr(13, NO, P_DIM); NSSize s1 = [@"Save As:" sizeWithAttributes: la], s2 = [@"Tags:" sizeWithAttributes: la];
		Text(@"Save As:", NSMakePoint(353 - s1.width, 54), 13, NO, P_DIM, YES); Text(@"Tags:", NSMakePoint(353 - s2.width, 92), 13, NO, P_DIM, YES);
		[P_LINE setFill]; NSRectFill(NSMakeRect(135, 271, [self bounds].size.width - 135, 1));
		return;
	}
	NSRect pp = NSMakeRect(100, 116, 198, 24); FillRound(pp, 8, P_CONTROL); FillRound(NSMakeRect(308, 116, 22, 24), 8, P_CONTROL);   /* Where: the folder pop-up and the button that expands the browser */
	DrawFolder(NSMakeRect(110, 122, 14, 12)); Text(whereTitle ?: @"", NSMakePoint(129, 128), 13, NO, P_TEXT, YES);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.2]; double cx = NSMaxX(pp) - 14, cy = k ? 131 : 125; [p moveToPoint: NSMakePoint(cx - 3, cy + (k ? -2 : 2))]; [p lineToPoint: NSMakePoint(cx, cy + (k ? 1 : -1))]; [p lineToPoint: NSMakePoint(cx + 3, cy + (k ? -2 : 2))]; [P_TEXT setStroke]; [p stroke]; }
	NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.4]; [ch moveToPoint: NSMakePoint(314, 126)]; [ch lineToPoint: NSMakePoint(319, 130)]; [ch lineToPoint: NSMakePoint(324, 126)]; [P_TEXT setStroke]; [ch stroke];
}
- (void)mouseDown:(NSEvent *)ev
{
	if (!saveForm || expanded) return;
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (NSPointInRect(p, NSMakeRect(308, 116, 22, 24))) { [owner performSelector: @selector(toggleExpanded)]; return; }
	if (NSPointInRect(p, NSMakeRect(100, 116, 198, 24))) [owner performSelector: @selector(showPathMenu:) withObject: [NSValue valueWithPoint: p]];
}
@end

@implementation WsdPanelController
- (void)column:(WsdColumn *)c clicked:(WsdEntry *)e doubleClick:(BOOL)dbl
{
	if (!isSave && c == listView) {                                                                                       /* the list or icons of the Open panel */
		chosen = e->path; if (e->dir && dbl) { [self openListGo: e->path push: YES]; return; }
		if (dbl && ((e->dir && dirsOK) || (!e->dir && filesOK))) [self accept: nil]; [self refresh]; return;
	}
	if (isSave) {                                                                                                          /* the list of the expanded Save panel */
		if (e->dir) { if (dbl) [self saveGo: e->path push: YES]; } else { [nameField setStringValue: e->name]; if (dbl) [self accept: nil]; }
		[self refresh]; return;
	}
	NSInteger idx = [cols indexOfObject: c];
	for (WsdColumn *x in cols) x->active = (x == c);
	while ((NSInteger)[cols count] > idx + 1) { NSScrollView *sv = [[cols lastObject] enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; [cols removeLastObject]; }
	chosen = e->path; if (preview) { [preview removeFromSuperview]; preview = nil; }
	if (!e->dir) { preview = [[WsdPreview alloc] initWithFrame: NSMakeRect(0, 0, 400, 300)]; preview->path = e->path; [root addSubview: preview]; [self layoutColumns]; }
	if (e->dir) {
		if (dbl && !dirsOK) { [self navigate: e->path push: YES]; return; }
		[self addColumnFor: e->path];
	}
	if (dbl && ((e->dir && dirsOK) || (!e->dir && filesOK))) [self accept: nil];
	if (isSave && !e->dir) [nameField setStringValue: e->name];
	[self refresh];
}
- (void)focusNextColumnFrom:(WsdColumn *)c
{
	NSInteger i = [cols indexOfObject: c]; if (i + 1 >= (NSInteger)[cols count]) return; WsdColumn *n = cols[i + 1]; if (![n->rows count]) return;
	for (NSInteger k = 0; k < (NSInteger)[n->rows count]; k++) if (![n->rows[k] isKindOfClass: [NSString class]]) { n->selected = k; break; }
	[win makeFirstResponder: n]; for (WsdColumn *x in cols) { x->active = (x == n); [x setNeedsDisplay: YES]; } if (n->selected >= 0) [self column: n clicked: n->rows[n->selected] doubleClick: NO];
}
- (void)focusPreviousColumnFrom:(WsdColumn *)c
{
	NSInteger i = [cols indexOfObject: c]; if (i <= 0) return; WsdColumn *p = cols[i - 1]; [win makeFirstResponder: p]; for (WsdColumn *x in cols) { x->active = (x == p); [x setNeedsDisplay: YES]; }
}
- (void)addColumnFor:(NSString *)path
{
	WsdColumn *c = [[WsdColumn alloc] initWithFrame: NSMakeRect(0, 0, 244, 100)]; c->dir = path; c->types = types; c->filesOK = filesOK || isSave; c->dirsOK = dirsOK; c->delegate = self; c->filter = searchText; [c load];
	[cols addObject: c]; [self layoutColumns];
}
- (void)layoutColumns
{
	WsdRoot *rv = (WsdRoot *)root; double areaW = [rv bounds].size.width - 135, w = 244; NSInteger n = [cols count] + (preview ? 2 : 0), vis = (NSInteger)(areaW / (w + 1)); NSInteger first = n > vis ? n - vis : 0;
	for (NSInteger i = 0; i < (NSInteger)[cols count]; i++) {
		WsdColumn *c = cols[i]; NSScrollView *sv = (NSScrollView *)[c enclosingScrollView];
		if (!sv) { sv = [[NSScrollView alloc] initWithFrame: NSZeroRect]; [sv setHasVerticalScroller: YES]; [sv setBorderType: NSNoBorder]; [sv setAutohidesScrollers: YES]; [sv setDrawsBackground: NO]; [sv setDocumentView: c]; [rv addSubview: sv]; }
		[sv setHidden: i < first]; [sv setFrame: NSMakeRect(135 + (i - first) * w, 64, w, [rv bounds].size.height - 64 - 66)]; [c setFrameSize: NSMakeSize(w, [c frame].size.height)];
	}
	if (preview) { NSInteger at = (NSInteger)[cols count] - first; [preview setFrame: NSMakeRect(135 + at * w, 64, [rv bounds].size.width - (135 + at * w), [rv bounds].size.height - 64 - 66)]; [preview setNeedsDisplay: YES]; }
	[rv setNeedsDisplay: YES];
}
- (void)navigate:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	if (preview) { [preview removeFromSuperview]; preview = nil; }
	for (WsdColumn *c in cols) { NSScrollView *sv = [c enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; } [cols removeAllObjects];
	dir = path; [self addColumnFor: path]; ((WsdColumn *)cols[0])->active = YES; chosen = nil; [self refresh];
}
/* ---- the Save panel: compact (the form) or expanded (the form above a list of the folder) */
- (void)saveGo:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	saveDir = path; [self reloadList]; [self refresh];
}
- (void)reloadList
{
	if (!expanded || !listView) return;
	listView->dir = saveDir; listView->filter = searchText; [listView load]; [listView setNeedsDisplay: YES];
	for (id r in listView->rows) if ([r isKindOfClass: [NSString class]]) { listHeader->group = r; break; } [listHeader setNeedsDisplay: YES];
}
/* ---- the Open panel's view modes: icons (0), list (1), columns (2); gallery (3) shows the columns */
- (void)showViewMenu
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSArray *names = @[ @"as Icons", @"as List", @"as Columns", @"as Gallery" ];
	for (int k = 0; k < 4; k++) { NSMenuItem *it = [m addItemWithTitle: names[k] action: @selector(viewModePicked:) keyEquivalent: @""]; [it setTarget: self]; [it setTag: k]; [it setState: (k == viewMode || (viewMode == 2 && k == 3 && NO)) ? NSOnState : NSOffState]; }
	[m popUpMenuPositioningItem: nil atLocation: NSMakePoint(135 + 76, 64 - 20) inView: root];
}
- (void)viewModePicked:(NSMenuItem *)it { [self setViewMode: (int)[it tag] == 3 ? 2 : (int)[it tag]]; }
- (void)clearBrowser
{
	if (preview) { [preview removeFromSuperview]; preview = nil; }
	for (WsdColumn *c in cols) { NSScrollView *sv = [c enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; } [cols removeAllObjects];
	if (listScroll) { [listScroll setDocumentView: nil]; [listScroll removeFromSuperview]; listScroll = nil; } if (listHeader) { [listHeader removeFromSuperview]; listHeader = nil; } listView = nil;
}
- (void)setViewMode:(int)m
{
	if (isSave || m == viewMode) return;
	NSString *d = [self currentDir]; viewMode = m; [self clearBrowser]; chosen = nil;
	if (m == 2) { [self navigate: d push: NO]; return; }
	listDir = d; double H = [root bounds].size.height, W = [root bounds].size.width - 135, hy = 64;
	if (m == 1) { listHeader = [[WsdListHeader alloc] initWithFrame: NSMakeRect(135, 64, W, 26)]; [root addSubview: listHeader]; hy = 90; }
	listScroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(135, hy, W, H - 66 - hy)]; [listScroll setHasVerticalScroller: YES]; [listScroll setBorderType: NSNoBorder]; [listScroll setDrawsBackground: NO];
	listView = m == 1 ? [[WsdListColumn alloc] initWithFrame: NSMakeRect(0, 0, W - 15, 100)] : [[WsdIconColumn alloc] initWithFrame: NSMakeRect(0, 0, W - 15, 100)];
	listView->types = types; listView->filesOK = filesOK; listView->dirsOK = dirsOK; listView->delegate = self; listView->active = YES; listView->dir = d; listView->filter = searchText; [listView load];
	[listScroll setDocumentView: listView]; [root addSubview: listScroll]; [win makeFirstResponder: listView]; [self refreshListHeader]; [self refresh];
}
- (void)refreshListHeader { if (!listHeader || !listView) return; for (id r in listView->rows) if ([r isKindOfClass: [NSString class]]) { listHeader->group = r; break; } [listHeader setNeedsDisplay: YES]; }
- (void)openListGo:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	listDir = path; listView->dir = path; [listView load]; [listView scrollRectToVisible: NSMakeRect(0, 0, 1, 1)]; [listView setNeedsDisplay: YES]; chosen = nil; [self refreshListHeader]; [self refresh];
}
- (void)toggleExpanded { expanded = !expanded; [self buildSave]; }
- (void)makeNewFolder:(id)sender
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSString *base = [saveDir stringByAppendingPathComponent: @"untitled folder"], *p = base; for (int i = 2; [fm fileExistsAtPath: p]; i++) p = [base stringByAppendingFormat: @" %d", i];
	[fm createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: NULL]; [self reloadList];
}
- (void)buildSave
{
	NSString *name = nameField ? [nameField stringValue] : savedName; savedName = name;
	for (NSView *v in [[root subviews] copy]) [v removeFromSuperview];
	corners = nil; toolbar = nil; sidebar = nil; listView = nil; listScroll = nil; listHeader = nil;
	NSSize size = expanded ? NSMakeSize(812, 333) : NSMakeSize(370, 204); NSRect wf = [win frame]; NSPoint ctr = NSMakePoint(NSMidX(wf), NSMidY(wf));
	[win setFrame: NSMakeRect(round(ctr.x - size.width / 2), round(ctr.y - size.height / 2), size.width, size.height) display: NO];
	[root setFrame: NSMakeRect(0, 0, size.width, size.height)]; ((WsdRoot *)root)->expanded = expanded;
	if (!expanded) {
		NSTextField *t = Field(NSMakeRect(0, 8, 370, 20), @"Save"); [t setAlignment: NSCenterTextAlignment]; [t setTextColor: P_DIM]; [t setEditable: NO]; [root addSubview: t];
		NSArray *labels = @[ @"Save As:", @"Tags:", @"Where:" ]; double ys[3] = { 41, 79, 116 };
		for (int i = 0; i < 3; i++) { NSTextField *l = Field(NSMakeRect(10, ys[i], 84, 20), labels[i]); [l setAlignment: NSRightTextAlignment]; [l setEditable: NO]; [l setTextColor: P_DIM]; [root addSubview: l]; }
		nameField = Field(NSMakeRect(100, 41, 230, 25), name); [nameField setBezeled: YES]; [nameField setDelegate: (id)self]; [root addSubview: nameField];
		NSTextField *tg = Field(NSMakeRect(100, 79, 230, 25), nil); [tg setBezeled: YES]; [root addSubview: tg];
		cancel = Btn(@"Cancel", NSMakeRect(184, 160, 78, 24), self, @selector(cancelIt:), NO); ok = Btn(okTitle, NSMakeRect(271, 160, 79, 24), self, @selector(accept:), YES);
		[root addSubview: cancel]; [root addSubview: ok];
	} else {
		WsdSidebar *sb = [[WsdSidebar alloc] initWithFrame: NSMakeRect(0, 0, 135, 333)]; [sb setup]; sb->target = self; sb->action = @selector(sidebarGo:); sidebar = sb;
		NSScrollView *ssv = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 135, 333)]; [ssv setHasVerticalScroller: YES]; [ssv setAutohidesScrollers: YES]; [ssv setBorderType: NSNoBorder]; [ssv setDrawsBackground: NO]; [ssv setDocumentView: sb]; [root addSubview: ssv]; [[ssv contentView] scrollToPoint: NSMakePoint(0, 32)]; [ssv reflectScrolledClipView: [ssv contentView]];           /* the window buttons cover the top of the sidebar: it starts scrolled (Shared is the first row) */
		nameField = Field(NSMakeRect(358, 41, 232, 26), name); [nameField setBezeled: YES]; [nameField setDelegate: (id)self]; [root addSubview: nameField];
		NSTextField *tg = Field(NSMakeRect(358, 79, 232, 26), nil); [tg setBezeled: YES]; [root addSubview: tg];
		WsdToolbar *tb = [[WsdToolbar alloc] initWithFrame: NSMakeRect(135, 104, 677, 64)]; tb->target = self; tb->compact = YES; toolbar = tb; [root addSubview: tb];
		NSTextField *sf2 = Field(NSMakeRect(135 + 462, 123, 195, 26), nil); [sf2 setBezeled: YES]; [sf2 setDelegate: (id)self]; [[sf2 cell] setPlaceholderAttributedString: [[NSAttributedString alloc] initWithString: @"Search" attributes: Attr(13, NO, P_DIM)]]; [root addSubview: sf2]; tb->search = sf2;
		listHeader = [[WsdListHeader alloc] initWithFrame: NSMakeRect(135, 169, 677, 26)]; [root addSubview: listHeader];
		listScroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(135, 195, 677, 76)]; [listScroll setHasVerticalScroller: YES]; [listScroll setBorderType: NSNoBorder]; [listScroll setDrawsBackground: NO];
		listView = [[WsdListColumn alloc] initWithFrame: NSMakeRect(0, 0, 662, 100)]; listView->types = types; listView->filesOK = YES; listView->dirsOK = NO; listView->delegate = self; listView->active = YES; [listScroll setDocumentView: listView]; [root addSubview: listScroll];
		newFolder = Btn(@"New Folder", NSMakeRect(155, 289, 94, 25), self, @selector(makeNewFolder:), NO); [root addSubview: newFolder];
		cancel = Btn(@"Cancel", NSMakeRect(626, 289, 79, 25), self, @selector(cancelIt:), NO); ok = Btn(okTitle, NSMakeRect(713, 289, 79, 25), self, @selector(accept:), YES); [root addSubview: cancel]; [root addSubview: ok];
		[self reloadList];
	}
	{ WsdLights *lt = [[WsdLights alloc] initWithFrame: [root bounds]]; lt->show = expanded; [root addSubview: lt]; }
	RoundWindow(win, 18); [root setNeedsDisplay: YES]; [self refresh]; [win makeFirstResponder: nameField];
}
- (void)sidebarGo:(NSString *)path { if (isSave) [self saveGo: path push: YES]; else if (viewMode != 2) [self openListGo: path push: YES]; else [self navigate: path push: YES]; }
- (void)goTo:(NSString *)path { if (isSave) [self saveGo: path push: NO]; else if (viewMode != 2) [self openListGo: path push: NO]; else [self navigate: path push: NO]; }
- (void)goBack { if (hpos > 0) { hpos--; [self goTo: history[hpos]]; } }
- (void)goForward { if (hpos + 1 < (NSInteger)[history count]) { hpos++; [self goTo: history[hpos]]; } }
- (NSString *)currentDir { if (isSave) return saveDir ?: dir; if (viewMode != 2 && listDir) return listDir; WsdColumn *c = [cols lastObject]; return c ? c->dir : dir; }
- (void)showPathMenu:(NSValue *)v
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSString *p = [self currentDir]; NSMutableArray *chain = [NSMutableArray array];
	while ([p length] > 1) { [chain addObject: p]; p = [p stringByDeletingLastPathComponent]; } [chain addObject: @"/"];
	for (NSString *q in chain) { NSMenuItem *it = [m addItemWithTitle: [q isEqual: @"/"] ? @"Macintosh HD" : [q lastPathComponent] action: @selector(pathPicked:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: q]; }
	[m popUpMenuPositioningItem: nil atLocation: isSave ? NSMakePoint(100, 140) : NSMakePoint(135 + 258, 64 - 20) inView: root];
}
- (void)pathPicked:(NSMenuItem *)it { [self sidebarGo: [it representedObject]]; }
- (void)refresh
{
	NSString *d = [self currentDir], *title = [d isEqual: @"/"] ? @"Macintosh HD" : [d lastPathComponent]; if (toolbar) { toolbar->pathTitle = title; toolbar->canBack = hpos > 0; toolbar->canFwd = hpos + 1 < (NSInteger)[history count]; }
	BOOL enable = chosen != nil;
	if (chosen) { BOOL isDir = NO; [[NSFileManager defaultManager] fileExistsAtPath: chosen isDirectory: &isDir]; enable = isDir ? dirsOK : filesOK; }
	if (isSave) enable = [[nameField stringValue] length] > 0;
	if (isSave) { ((WsdRoot *)root)->whereTitle = title; [root setNeedsDisplay: YES]; }
	[ok setEnabled: enable]; [toolbar setNeedsDisplay: YES]; [sidebar setNeedsDisplay: YES];
}
- (void)accept:(id)sender
{
	NSMutableArray *res = [NSMutableArray array];
	if (isSave) {
		NSString *n = [nameField stringValue]; if (![n length]) return;
		if (types.count && ![[n pathExtension] length]) n = [n stringByAppendingPathExtension: types[0]];
		[res addObject: [[self currentDir] stringByAppendingPathComponent: n]];
	} else if (chosen) [res addObject: chosen]; else if (dirsOK) [res addObject: [self currentDir]];
	if (![res count]) return;
	objc_setAssociatedObject(self->win, &kResult, res, OBJC_ASSOCIATION_RETAIN); result = 1; [NSApp stopModalWithCode: 1]; [win orderOut: nil];
}
- (void)cancelIt:(id)sender { result = 0; [NSApp stopModalWithCode: 0]; [win orderOut: nil]; }
- (void)controlTextDidChange:(NSNotification *)n
{
	if ([n object] == toolbar->search && toolbar) {                                                                    /* the search field filters the folders shown by name */
		searchText = [toolbar->search stringValue]; for (WsdColumn *c in cols) { c->filter = searchText; [c load]; [c setNeedsDisplay: YES]; }
		if (listView) { listView->filter = searchText; [listView load]; [listView setNeedsDisplay: YES]; [self refreshListHeader]; }
	}
	[self refresh];
}
@end

@interface WsdFilePanelWindow : NSPanel @end
@implementation WsdFilePanelWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (void)cancelOperation:(id)s { [(WsdPanelController *)[self delegate] cancelIt: nil]; }
@end

static NSButton *Btn(NSString *title, NSRect f, id target, SEL action, BOOL def)
{
	NSButton *b = [[NSButton alloc] initWithFrame: f]; [b setTitle: title]; [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: target]; [b setAction: action]; if (def) [b setKeyEquivalent: @"\r"]; else if ([title isEqual: @"Cancel"]) [b setKeyEquivalent: @"\033"];
	return b;
}
static NSTextField *Field(NSRect f, NSString *val)
{
	NSTextField *t = [[NSTextField alloc] initWithFrame: f]; [t setBordered: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO]; [t setStringValue: val ?: @""]; [t setFont: [NSFont systemFontOfSize: 13]]; [t setTextColor: P_TEXT]; [t setFocusRingType: NSFocusRingTypeNone];
	return t;
}

static NSInteger WsdRunPanel(NSSavePanel *sp)
{
	BOOL open = [sp isKindOfClass: [NSOpenPanel class]]; WsdPanelController *pc = [WsdPanelController new]; pc->isSave = !open;
	pc->filesOK = open ? [(NSOpenPanel *)sp canChooseFiles] : YES; pc->dirsOK = open ? [(NSOpenPanel *)sp canChooseDirectories] : NO; pc->multiple = open ? [(NSOpenPanel *)sp allowsMultipleSelection] : NO;
	NSMutableArray *ty = [NSMutableArray array]; for (NSString *t in [sp allowedFileTypes] ?: @[]) if ([t length]) [ty addObject: [t lowercaseString]]; pc->types = ty;
	NSString *nm = objc_getAssociatedObject(sp, "wsdname"); NSString *d = [sp directory]; if (![d length] || ![[NSFileManager defaultManager] fileExistsAtPath: d]) d = NSHomeDirectory();
	pc->cols = [NSMutableArray array]; pc->history = [NSMutableArray array];
	NSRect frame = open ? NSMakeRect(0, 0, 880, 448) : NSMakeRect(0, 0, 370, 204);
	NSScreen *sc = [NSScreen mainScreen]; NSRect sf = [sc frame]; frame.origin = NSMakePoint(floor((sf.size.width - frame.size.width) / 2), floor((sf.size.height - frame.size.height) / 2 + 30));
	WsdFilePanelWindow *w = [[WsdFilePanelWindow alloc] initWithContentRect: frame styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setDelegate: (id)pc]; [w setReleasedWhenClosed: NO]; pc->win = w;
	WsdRoot *root = [[WsdRoot alloc] initWithFrame: NSMakeRect(0, 0, frame.size.width, frame.size.height)]; pc->root = root; root->owner = pc; root->saveForm = !open; [w setContentView: root];
	if (open) {
		WsdSidebar *sb = [[WsdSidebar alloc] initWithFrame: NSMakeRect(0, 0, 135, 448)]; [sb setup]; sb->target = pc; sb->action = @selector(sidebarGo:); pc->sidebar = sb;
		NSScrollView *ssv = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 135, 448)]; [ssv setHasVerticalScroller: YES]; [ssv setAutohidesScrollers: YES]; [ssv setBorderType: NSNoBorder]; [ssv setDrawsBackground: NO]; [ssv setDocumentView: sb]; [root addSubview: ssv];
		WsdToolbar *tb = [[WsdToolbar alloc] initWithFrame: NSMakeRect(135, 0, 745, 64)]; tb->target = pc; pc->toolbar = tb; [root addSubview: tb];
		NSTextField *sf2 = Field(NSMakeRect(135 + 529, 19, 196, 26), nil); [sf2 setBezeled: YES]; [sf2 setDelegate: (id)pc]; [[sf2 cell] setPlaceholderAttributedString: [[NSAttributedString alloc] initWithString: @"Search" attributes: Attr(13, NO, P_DIM)]]; [root addSubview: sf2]; tb->search = sf2;
		pc->cancel = Btn(@"Cancel", NSMakeRect(695, 448 - 43, 77, 22), pc, @selector(cancelIt:), NO); pc->ok = Btn(([sp prompt].length && ![[sp prompt] isEqual: @"Name:"]) ? [sp prompt] : @"Open", NSMakeRect(781, 448 - 43, 79, 22), pc, @selector(accept:), YES);
		[root addSubview: pc->cancel]; [root addSubview: pc->ok]; [pc->ok setEnabled: NO];
		pc->viewMode = 2; [pc navigate: d push: YES]; if (getenv("WSD_PANEL_VIEW")) [pc setViewMode: atoi(getenv("WSD_PANEL_VIEW"))]; for (NSInteger i = 0; i < (NSInteger)[sb->items count]; i++) if ([sb->items[i][@"p"] isEqual: d]) sb->selected = i;
	} else {
		pc->okTitle = ([sp prompt].length && ![[sp prompt] isEqual: @"Name:"]) ? [sp prompt] : @"Save"; pc->savedName = nm ?: ([sp nameFieldStringValue] ?: @""); pc->saveDir = d; pc->dir = d;
		[pc->history addObject: d]; pc->hpos = 0; [pc buildSave];
		objc_setAssociatedObject(w, "dirpath", d, OBJC_ASSOCIATION_RETAIN);
	}
	[w makeKeyAndOrderFront: nil]; RoundWindow(w, open ? 22 : 18);
	if (open && [pc->cols count]) [w makeFirstResponder: pc->cols[0]];
	if (!open) [w makeFirstResponder: pc->nameField];
	NSInteger r = ((NSInteger (*)(id, SEL, NSWindow *))origRunModal)(NSApp, @selector(runModalForWindow:), w);
	NSArray *res = objc_getAssociatedObject(w, &kResult);
	objc_setAssociatedObject(sp, &kResult, r == 1 ? res : nil, OBJC_ASSOCIATION_RETAIN);
	[w orderOut: nil];
	return r == 1 ? NSOKButton : NSCancelButton;
}
/* the Save form draws its own fields (they are not NSControls with bezels): the Where pop-up and the expand button */
@interface WsdSaveFormDrawing : NSObject @end

static NSInteger wsdRunModalForWindow(id self, SEL _cmd, NSWindow *w)
{
	if ([w isKindOfClass: [NSSavePanel class]] && !getenv("WSD_NO_MACFILEPANEL")) return WsdRunPanel((NSSavePanel *)w);
	return ((NSInteger (*)(id, SEL, NSWindow *))origRunModal)(self, _cmd, w);
}
static NSInteger wsdRunModalRel(id self, SEL _cmd, NSWindow *w, NSWindow *rel)
{
	if ([w isKindOfClass: [NSSavePanel class]] && !getenv("WSD_NO_MACFILEPANEL")) return WsdRunPanel((NSSavePanel *)w);
	return ((NSInteger (*)(id, SEL, NSWindow *, NSWindow *))origRunModalRel)(self, _cmd, w, rel);
}
static void wsdBeginCompletion(id self, SEL _cmd, void (^handler)(NSInteger))
{
	if (getenv("WSD_NO_MACFILEPANEL")) { ((void (*)(id, SEL, id))origBeginCompletion)(self, _cmd, handler); return; }
	NSInteger r = WsdRunPanel((NSSavePanel *)self); if (handler) handler(r);
}
static NSString *wsdSaveFilename(id self, SEL _cmd)
{
	NSArray *r = objc_getAssociatedObject(self, &kResult); if ([r count]) return r[0];
	return ((NSString *(*)(id, SEL))origSaveFilename)(self, _cmd);
}
static NSArray *wsdOpenFilenames(id self, SEL _cmd)
{
	NSArray *r = objc_getAssociatedObject(self, &kResult); if (r) return r;
	return ((NSArray *(*)(id, SEL))origOpenFilenames)(self, _cmd);
}

static void wsdSetName(id self, SEL _cmd, NSString *v) { objc_setAssociatedObject(self, "wsdname", v, OBJC_ASSOCIATION_COPY); ((void (*)(id, SEL, id))origSetName)(self, _cmd, v); }
void WsdInstallFilePanel(void)
{
	if (origRunModal) return;
	Method m1 = class_getInstanceMethod([NSApplication class], @selector(runModalForWindow:)); if (m1) origRunModal = method_setImplementation(m1, (IMP)wsdRunModalForWindow);
	Method m2 = class_getInstanceMethod([NSApplication class], @selector(runModalForWindow:relativeToWindow:)); if (m2) origRunModalRel = method_setImplementation(m2, (IMP)wsdRunModalRel);
	Method m3 = class_getInstanceMethod([NSSavePanel class], @selector(beginWithCompletionHandler:)); if (m3) origBeginCompletion = method_setImplementation(m3, (IMP)wsdBeginCompletion);
	Method m6 = class_getInstanceMethod([NSSavePanel class], @selector(setNameFieldStringValue:)); if (m6) origSetName = method_setImplementation(m6, (IMP)wsdSetName);
	Method m4 = class_getInstanceMethod([NSSavePanel class], @selector(filename)); if (m4) origSaveFilename = method_setImplementation(m4, (IMP)wsdSaveFilename);
	Method m5 = class_getInstanceMethod([NSOpenPanel class], @selector(filenames)); if (m5) origOpenFilenames = method_setImplementation(m5, (IMP)wsdOpenFilenames);
}
