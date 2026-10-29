#import "TFinderViews.h"
#include <sys/stat.h>
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TFDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface NSObject (WsdFinderSupport)
+ (void)roundWindow:(NSWindow *)w radius:(int)r;
+ (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c;
+ (void)drawIconOfName:(NSString *)name directory:(BOOL)dir inRect:(NSRect)r;
+ (NSArray *)pathsTagged:(NSString *)tag;
+ (void)popupInView:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d checks:(NSIndexSet *)c at:(NSPoint)p pick:(void (^)(NSInteger))b;
+ (BOOL)dropFiles:(NSArray *)paths atScreenPoint:(NSPoint)p;
+ (void)popupInView:(NSView *)root rows:(NSArray *)rows at:(NSPoint)p pick:(void (^)(NSInteger))b;
@end

/* the order of names in the Finder: case and accents ignored, runs of digits compared by value */
@implementation NSString (TFNameOrder)
- (NSComparisonResult)tfNameCompare:(NSString *)other
{
	NSString *a = [[self decomposedStringWithCanonicalMapping] lowercaseString], *b = [[other decomposedStringWithCanonicalMapping] lowercaseString]; NSUInteger i = 0, j = 0, na = [a length], nb = [b length];
	while (i < na && j < nb) {
		unichar x = [a characterAtIndex: i], y = [b characterAtIndex: j]; BOOL dx = x >= '0' && x <= '9', dy = y >= '0' && y <= '9';
		if (dx && dy) { NSUInteger si = i, sj = j; while (i < na && [a characterAtIndex: i] >= '0' && [a characterAtIndex: i] <= '9') i++; while (j < nb && [b characterAtIndex: j] >= '0' && [b characterAtIndex: j] <= '9') j++;
			NSString *da = [a substringWithRange: NSMakeRange(si, i - si)], *db = [b substringWithRange: NSMakeRange(sj, j - sj)]; while ([da length] > 1 && [da hasPrefix: @"0"]) da = [da substringFromIndex: 1]; while ([db length] > 1 && [db hasPrefix: @"0"]) db = [db substringFromIndex: 1];
			if ([da length] != [db length]) return [da length] < [db length] ? NSOrderedAscending : NSOrderedDescending; NSComparisonResult c = [da compare: db options: NSLiteralSearch]; if (c != NSOrderedSame) return c; continue; }
		if (x != y) { if ([[NSCharacterSet letterCharacterSet] characterIsMember: x] != [[NSCharacterSet letterCharacterSet] characterIsMember: y]) { BOOL lx = [[NSCharacterSet letterCharacterSet] characterIsMember: x]; BOOL ly = [[NSCharacterSet letterCharacterSet] characterIsMember: y]; if (!lx && ly) return NSOrderedAscending; if (lx && !ly) return NSOrderedDescending; } return x < y ? NSOrderedAscending : NSOrderedDescending; }
		i++; j++;
	}
	if (na - i != nb - j) return (na - i) < (nb - j) ? NSOrderedAscending : NSOrderedDescending; return [self compare: other options: NSLiteralSearch];
}
@end
NSString *TFSizeString(unsigned long long b)                                              /* as the Finder writes it: bytes below 1000, then KB / MB / GB with decimal units */
{
	if (b == 0) return @"Zero bytes"; if (b < 1000) return [NSString stringWithFormat: @"%llu byte%s", b, b == 1 ? "" : "s"];
	double v = b / 1000.0; if (v < 1000) return [NSString stringWithFormat: @"%.0f KB", v];
	const char *u[] = { "MB", "GB", "TB" }; int k = 0; v /= 1000; while (v >= 1000 && k < 2) { v /= 1000; k++; }
	NSString *n = [NSString stringWithFormat: @"%.1f", v]; if ([n hasSuffix: @".0"]) n = [n substringToIndex: [n length] - 2]; return [NSString stringWithFormat: @"%@ %s", n, u[k]];
}
NSString *TFDateString(NSDate *d)
{
	if (!d) return @""; NSCalendar *cal = [NSCalendar currentCalendar]; NSDateFormatter *tf = [[NSDateFormatter alloc] init]; [tf setDateFormat: @"HH:mm"]; NSString *t = [tf stringFromDate: d];
	if ([cal isDateInToday: d]) return [@"Today at " stringByAppendingString: t]; if ([cal isDateInYesterday: d]) return [@"Yesterday at " stringByAppendingString: t];
	NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"d MMM yyyy 'at' HH:mm"]; return [df stringFromDate: d];
}
NSString *TFKindString(NSString *path, BOOL dir)
{
	if (dir) return TFIsPackage(path) ? @"Application" : @"Folder";
	NSString *ext = [path pathExtension]; NSString *u = [ext length] ? (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL) : nil;
	NSString *d = u && ![u hasPrefix: @"dyn."] ? (__bridge_transfer NSString *)UTTypeCopyDescription((__bridge CFStringRef)u) : nil; if ([d isKindOfClass: [NSString class]] && [d length]) return [[[d substringToIndex: 1] uppercaseString] stringByAppendingString: [d substringFromIndex: 1]];
	return [ext length] ? [NSString stringWithFormat: @"%@ document", [ext uppercaseString]] : @"Document";
}
NSArray *TFTagsOf(NSString *path) { Class k = NSClassFromString(@"WsdFinderSupport"); return k ? [k tagsOfPath: path] : @[]; }
void TFSetTags(NSArray *names, NSString *path) { Class k = NSClassFromString(@"WsdFinderSupport"); if (k) [k setTags: names ofPath: path]; }
NSArray *TFRecentPaths(void)                                                                  /* the files of the home folder changed in the last 14 days, newest first (the Mac lists what was opened; the modification time stands in) */
{
	NSMutableArray *res = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *stack = [NSMutableArray arrayWithObject: NSHomeDirectory()]; NSDate *since = [NSDate dateWithTimeIntervalSinceNow: -14 * 86400], *end = [NSDate dateWithTimeIntervalSinceNow: 2.5];
	while ([stack count] && [res count] < 600) { NSString *dir = [stack lastObject]; [stack removeLastObject];
		for (NSString *nm in [fm contentsOfDirectoryAtPath: dir error: NULL]) { if ([nm hasPrefix: @"."]) continue; NSString *full = [dir stringByAppendingPathComponent: nm]; NSDictionary *at = [fm attributesOfItemAtPath: full error: NULL]; BOOL d = [at[NSFileType] isEqual: NSFileTypeDirectory];
			if (d) { if (!TFIsPackage(full) && !([dir isEqual: NSHomeDirectory()] && [nm isEqual: @"Library"])) [stack addObject: full]; } else if ([at[NSFileModificationDate] compare: since] == NSOrderedDescending) [res addObject: @{ @"p": full, @"d": at[NSFileModificationDate] }]; }
		if ([end timeIntervalSinceNow] < 0) break; }
	[res sortUsingComparator: ^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [b[@"d"] compare: a[@"d"]]; }]; NSMutableArray *out = [NSMutableArray array]; for (NSDictionary *d in res) [out addObject: d[@"p"]]; return out;
}
NSArray *TFPathsTagged(NSString *tag) { Class k = NSClassFromString(@"WsdFinderSupport"); return k ? [k pathsTagged: tag] : @[]; }
BOOL TFSymbolW(NSString *name, NSRect cell, CGFloat pt, int weight, NSColor *tint)
{
	Class k = NSClassFromString(@"WsdFinderSupport"); if (!k) return NO; return [k drawSymbol: name inRect: cell size: pt weight: weight color: tint];
}
BOOL TFSymbol(NSString *name, NSRect cell, CGFloat pt, NSColor *tint) { return TFSymbolW(name, cell, pt, 4, tint); }
/* the name as shown: a smart folder (.savedSearch) has no extension on the Mac's screen */
NSString *TFShownName(NSString *n) { return [[n pathExtension] caseInsensitiveCompare: @"savedSearch"] == NSOrderedSame ? [n stringByDeletingPathExtension] : n; }
NSImage *TFIcon(NSString *path)
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary]; NSString *ext = [[path pathExtension] lowercaseString]; BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d];
	NSString *key = d || ![ext length] ? path : [@"." stringByAppendingString: ext]; NSImage *i = cache[key]; if (!i) { i = [[NSWorkspace sharedWorkspace] iconForFile: path]; if (i) cache[key] = i; } return i;
}
extern "C" NSImage *WsbsdCoreTypesIcon(NSString *file, CGFloat pt);
static NSString *VolumeKind(NSString *path)                                                  /* internal / external / optical for a mount point, nil otherwise (the list is read once a second) */
{
	static NSArray *vols; static time_t at; time_t now = time(NULL); if (!vols || now != at) { vols = TFVolumes(); at = now; } for (NSDictionary *v in vols) if ([v[@"path"] isEqual: path]) return v[@"kind"]; return nil;
}
static void DrawUpright(NSImage *im, NSRect r)       /* an icon of CoreTypes drawn in the (flipped) icon view: turned over so that it stands upright */
{
	[NSGraphicsContext saveGraphicsState]; NSAffineTransform *t = [NSAffineTransform transform]; [t translateXBy: 0 yBy: NSMidY(r) * 2]; [t scaleXBy: 1 yBy: -1]; [t concat];
	[im drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [NSGraphicsContext restoreGraphicsState];
}
static void DrawAliasBadge(NSRect r)       /* the alias badge of the Mac: a white disc with a curved black arrow at the bottom left of the icon */
{
	CGFloat d = MAX(12, r.size.width * 0.30); NSRect b = NSMakeRect(r.origin.x + r.size.width * 0.04, r.origin.y + r.size.height * 0.04, d, d);       /* the view is flipped or not: the corner is the lower left either way for icons drawn in an upright rectangle */
	[NSGraphicsContext saveGraphicsState]; NSShadow *sh = [[NSShadow alloc] init]; [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.35]]; [sh setShadowOffset: NSMakeSize(0, -1)]; [sh setShadowBlurRadius: 2]; [sh set];
	[[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithOvalInRect: b] fill]; [NSGraphicsContext restoreGraphicsState];
	NSBezierPath *a = [NSBezierPath bezierPath]; [a setLineWidth: MAX(1.4, d * 0.12)]; [a setLineCapStyle: NSRoundLineCapStyle]; [a setLineJoinStyle: NSRoundLineJoinStyle];
	NSPoint c = NSMakePoint(NSMidX(b), NSMidY(b)); CGFloat u = d / 2;
	[a moveToPoint: NSMakePoint(c.x - u * 0.45, c.y - u * 0.35)]; [a curveToPoint: NSMakePoint(c.x + u * 0.45, c.y + u * 0.10) controlPoint1: NSMakePoint(c.x - u * 0.45, c.y + u * 0.35) controlPoint2: NSMakePoint(c.x + u * 0.05, c.y + u * 0.40)];
	[[NSColor colorWithCalibratedWhite: 0.1 alpha: 1] setStroke]; [a stroke];
	NSBezierPath *h = [NSBezierPath bezierPath]; [h setLineWidth: MAX(1.4, d * 0.12)]; [h setLineCapStyle: NSRoundLineCapStyle]; [h setLineJoinStyle: NSRoundLineJoinStyle];
	[h moveToPoint: NSMakePoint(c.x + u * 0.12, c.y + u * 0.42)]; [h lineToPoint: NSMakePoint(c.x + u * 0.50, c.y + u * 0.10)]; [h lineToPoint: NSMakePoint(c.x + u * 0.12, c.y - u * 0.16)]; [h stroke];
}
void TFDrawIcon(NSString *path, NSRect r)
{
	struct stat lst; BOOL link = lstat([path fileSystemRepresentation], &lst) == 0 && S_ISLNK(lst.st_mode); NSString *ct = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/";
	NSString *tgt = link ? [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: path error: NULL] : path;       /* the Applications folder has its own icon, a link to it too */
	if ([tgt isEqual: @"/Applications"]) { NSImage *ai = WsbsdCoreTypesIcon([ct stringByAppendingString: @"ApplicationsFolderIcon.icns"], r.size.width); if (ai) DrawUpright(ai, r); else TFDrawIconBase(path, r); }
	else TFDrawIconBase(path, r);
	if (link) { NSImage *ab = WsbsdCoreTypesIcon([ct stringByAppendingString: @"AliasBadgeIcon.icns"], r.size.width); if (ab) DrawUpright(ab, r); else DrawAliasBadge(r); }
}
void TFDrawIconBase(NSString *path, NSRect r)                                                    /* the icon as the Mac draws it (the panel's recipes: folder bitmap, document page with symbol and label), the volume and the apps from the system icons */
{
	NSFileManager *fm = [NSFileManager defaultManager]; BOOL d = NO; [fm fileExistsAtPath: path isDirectory: &d]; Class k = NSClassFromString(@"WsdFinderSupport");
	NSString *vk = d ? VolumeKind(path) : nil;
	if (!d && [[[path pathExtension] lowercaseString] isEqual: @"savedsearch"]) { NSImage *sf = WsbsdCoreTypesIcon(@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SmartFolderIcon.icns", r.size.width); if (sf) { [sf drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; return; } }
	if (vk) { const char *e = getenv("WSBSD_IOSTORAGE"); NSString *dir = e ? @(e) : @"/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources"; NSImage *vi = WsbsdCoreTypesIcon([dir stringByAppendingPathComponent: [vk isEqual: @"internal"] ? @"Internal.icns" : [vk isEqual: @"optical"] ? @"Removable.icns" : @"External.icns"], MAX(r.size.width, r.size.height)); if (vi) { [vi drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; return; } }
	if (k && ![path isEqual: @"/"] && !TFIsPackage(path)) { [k drawIconOfName: [path lastPathComponent] directory: d inRect: r]; return; }
	NSImage *i = TFIcon(path); if (i) [i drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
}
@interface TMenuFit : NSObject { NSMenu *menu; int n; } - (id)initFor:(NSMenu *)m; @end
@implementation TMenuFit
- (id)initFor:(NSMenu *)m { if ((self = [super init])) { menu = m; [self performSelector: @selector(fit) withObject: nil afterDelay: 0.03 inModes: @[ NSEventTrackingRunLoopMode, NSDefaultRunLoopMode, NSModalPanelRunLoopMode ]]; } return self; }
- (void)fit { NSWindow *mw = [[menu menuRepresentation] window]; if (!mw || ![mw isVisible]) { if (++n < 10) [self performSelector: @selector(fit) withObject: nil afterDelay: 0.03 inModes: @[ NSEventTrackingRunLoopMode, NSDefaultRunLoopMode ]]; return; } NSRect f = [mw frame]; if (getenv("FINDER_DEBUG")) NSLog(@"menu fit window %@", NSStringFromRect(f)); NSRect sc = [[NSScreen mainScreen] frame]; BOOL mv = NO; if (f.origin.y < 8) { f.origin.y = 8; mv = YES; } if (NSMaxX(f) > NSMaxX(sc) - 2) { f.origin.x = [NSEvent mouseLocation].x - NSWidth(f) + 1; mv = YES; } if (mv) [mw setFrameOrigin: f.origin]; }       /* at the right edge the menu opens to the left of the pointer, as on the Mac */
@end
@interface TTagDots : NSView { @public NSArray *names; NSArray *cols; id target; SEL action; __weak NSMenu *menu; } @end
@implementation TTagDots
- (void)drawRect:(NSRect)r { CGFloat x = 14; for (NSUInteger i = 0; i < [cols count]; i++) { NSRect d = NSMakeRect(x, (NSHeight([self bounds]) - 14) / 2, 14, 14); [cols[i] setFill]; [[NSBezierPath bezierPathWithOvalInRect: d] fill]; x += 20; } }
- (void)_applyAt:(NSPoint)p { NSInteger i = (NSInteger)((p.x - 10) / 20); if (i < 0 || i >= (NSInteger)[names count]) return; NSMenuItem *tmp = [[NSMenuItem alloc] initWithTitle: @"" action: action keyEquivalent: @""]; [tmp setRepresentedObject: names[i]]; [tmp setTarget: target]; [NSApp sendAction: action to: target from: tmp]; }
- (void)mouseDown:(NSEvent *)e { [menu cancelTracking]; [self _applyAt: [self convertPoint: [e locationInWindow] fromView: nil]]; }
/* the menu's own tracking takes the mouse before the view sees it (the whole row was chosen): the row is an item with this action, and the dot is found from where the pointer is when it is chosen */
- (void)rowChosen:(id)sender { NSEvent *ce = [NSApp currentEvent]; if (!ce) return; [self _applyAt: NSMakePoint([ce locationInWindow].x - [self frame].origin.x, 12)]; }       /* the menu's own tracking takes the mouse before the view sees it: the item is chosen, and the dot is found from the point of the choosing event in the pop-up's window (the view's own window is a copy that is never shown; the view's x in the pop-up is its x here) */
@end
void TFPopupMenu(NSView *view, NSPoint p, NSMenu *menu)                                       /* an NSMenu shown as the panel's own pop-up (GNUstep's pop-up windows come out far too big under this window server): separators, symbols (tool tip "sym:name"), a row of tag colours (tag 2), sub menus, disabled rows in grey */
{
	if (!getenv("FINDER_PANEL_MENU")) {                                                         /* the real NSMenu pop-up: the theme draws it as measured on the Mac (rows 24, separators 11, glass) */
		NSWindow *w = [view window]; if (!w) return; NSPoint q = [view convertPoint: p toView: nil]; Class fs = NSClassFromString(@"WsdFinderSupport");
		for (NSMenuItem *it in [menu itemArray]) {
			id t = [it target]; BOOL ok = YES; if ([t respondsToSelector: @selector(validateMenuItem:)] && [it action]) ok = [t validateMenuItem: it]; if ([[it title] isEqual: @"Put Back"] || [[it title] isEqual: @"Open With"]) [it setHidden: !ok || [it isHidden]];     /* the Mac leaves these out when they do not apply */
			if ([it tag] == 2 && ![it view]) { TTagDots *dv = [[TTagDots alloc] initWithFrame: NSMakeRect(0, 0, 160, 24)]; NSMutableArray *cs = [NSMutableArray array]; for (NSString *n in [it representedObject]) [cs addObject: [fs colorOfTag: n]]; dv->names = [it representedObject]; dv->cols = cs; dv->target = [it target]; dv->action = [it action]; dv->menu = menu; [it setTitle: @""]; [it setView: dv]; [it setTarget: dv]; [it setAction: @selector(rowChosen:)]; }
		}
		NSEvent *ev = [NSEvent mouseEventWithType: NSRightMouseDown location: q modifierFlags: 0 timestamp: [[NSProcessInfo processInfo] systemUptime] windowNumber: [w windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1];
		__block BOOL chose = NO; id ob = [[NSNotificationCenter defaultCenter] addObserverForName: NSMenuDidSendActionNotification object: nil queue: nil usingBlock: ^(NSNotification *n) { chose = YES; }];
		[[TMenuFit alloc] initFor: menu];       /* a menu that does not fit below the pointer is moved up, as on the Mac: the server places it at the pointer, so it is moved once it is on screen */
		NSDate *t0 = [NSDate date]; [NSMenu popUpContextMenu: menu withEvent: ev forView: view];
		if (!chose && -[t0 timeIntervalSinceNow] < 0.5) { [[TMenuFit alloc] initFor: menu]; [NSMenu popUpContextMenu: menu withEvent: ev forView: view]; }       /* a quick click: the Mac keeps the menu open until the next click (GNUstep ends the tracking at the first release) */
		[[NSNotificationCenter defaultCenter] removeObserver: ob]; return; }
	Class sp = NSClassFromString(@"WsdFinderSupport"); NSMutableArray *items = [NSMutableArray array], *rows = [NSMutableArray array];
	for (NSMenuItem *it in [menu itemArray]) {
		if ([it isSeparatorItem]) { if ([rows count] && ![[rows lastObject][@"sep"] boolValue]) { [items addObject: [NSNull null]]; [rows addObject: @{ @"sep": @YES }]; } continue; }
		id t = [it target]; BOOL ok = YES; if ([t respondsToSelector: @selector(validateMenuItem:)] && [it action]) ok = [t validateMenuItem: it]; if (!ok && ([[it title] isEqual: @"Put Back"] || [[it title] isEqual: @"Open With"])) continue; if ([it isHidden]) continue;
		if ([it tag] == 2) { NSMutableArray *cols = [NSMutableArray array]; for (NSString *n in [it representedObject]) [cols addObject: [sp colorOfTag: n]]; [items addObject: it]; [rows addObject: @{ @"dots": cols }]; continue; }
		NSMutableDictionary *r = [@{ @"t": [it title] } mutableCopy]; NSString *tip = [it toolTip]; if ([tip hasPrefix: @"sym:"]) r[@"sym"] = [tip substringFromIndex: 4]; if ([it submenu]) r[@"sub"] = @YES; if ([it state] == NSOnState) r[@"check"] = @YES; if (!ok) r[@"dim"] = @YES; [items addObject: it]; [rows addObject: r];
	}
	while ([rows count] && [[rows lastObject][@"sep"] boolValue]) { [rows removeLastObject]; [items removeLastObject]; }
	if (![rows count] || !sp) return; NSView *root = [[view window] contentView]; NSPoint q = [root convertPoint: p fromView: view];
	[sp popupInView: root rows: rows at: q pick: ^(NSInteger k) {
		if (k >= 1000) { NSMenuItem *di = nil; for (id x in items) if (x != [NSNull null] && [x tag] == 2) di = x; if (!di) return; NSMenuItem *tmp = [[NSMenuItem alloc] initWithTitle: @"" action: [di action] keyEquivalent: @""]; [tmp setRepresentedObject: [di representedObject][k - 1000]]; [tmp setTarget: [di target]]; [NSApp sendAction: [di action] to: [di target] from: tmp]; return; }
		if (k < 0 || k >= (NSInteger)[items count] || items[k] == [NSNull null]) return; NSMenuItem *it = items[k]; if ([it submenu]) TFPopupMenu(view, NSMakePoint(p.x + 40, p.y), [it submenu]); else if ([it action]) [NSApp sendAction: [it action] to: [it target] from: it]; }];
}
static NSImage *Thumb(NSString *path)                                                       /* the picture itself for image files, scaled once */
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary]; NSString *ext = [[path pathExtension] lowercaseString]; if (![@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"tif", @"bmp" ] containsObject: ext]) return nil;
	id hit = cache[path]; if (hit) return hit == [NSNull null] ? nil : hit; NSDictionary *at = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: NULL]; NSImage *src = [at[NSFileSize] unsignedLongLongValue] < 24000000 ? [[NSImage alloc] initWithContentsOfFile: path] : nil;
	if (!src || [src size].width < 1) { cache[path] = [NSNull null]; return nil; } NSSize z = [src size]; CGFloat k = 128.0 / MAX(z.width, z.height); NSSize t = NSMakeSize(MAX(1, round(z.width * k)), MAX(1, round(z.height * k)));
	NSImage *out = [[NSImage alloc] initWithSize: t]; [out lockFocus]; [src drawInRect: NSMakeRect(0, 0, t.width, t.height) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [out unlockFocus]; cache[path] = out; return out;
}
/* Names that do not fit, the way the Mac cuts them (measured on the Mac with CoreText, kCTLineTruncationMiddle: tools/ellipsis_probe, 523 of 529 cases identical, the other six differ by one letter):
 * the room left by the ellipsis is shared in two halves, the head keeps the most characters whose width is within the first half, the tail the most within the second; a space at either cut is dropped. */
static double TextW(NSString *s, NSDictionary *at) { return [s length] ? [s sizeWithAttributes: at].width : 0; }
static NSUInteger FitPrefix(NSString *s, NSDictionary *at, double w)                          /* the most characters from the start whose width is within w */
{
	NSUInteger lo = 0, hi = [s length]; while (lo < hi) { NSUInteger mid = (lo + hi + 1) / 2; if (TextW([s substringToIndex: mid], at) <= w) lo = mid; else hi = mid - 1; } return lo;
}
static NSUInteger FitSuffix(NSString *s, NSDictionary *at, double w)
{
	NSUInteger n = [s length], lo = 0, hi = n; while (lo < hi) { NSUInteger mid = (lo + hi + 1) / 2; if (TextW([s substringFromIndex: n - mid], at) <= w) lo = mid; else hi = mid - 1; } return lo;
}
static NSString *Truncated(NSString *s, NSDictionary *at, CGFloat w)
{
	if (TextW(s, at) <= w) return s; double half = (w - TextW(@"…", at)) / 2; if (half <= 0) return @"…"; NSUInteger n = [s length], h = FitPrefix(s, at, half), t = FitSuffix(s, at, half);
	if (h < n) { NSRange r = [s rangeOfComposedCharacterSequenceAtIndex: h]; if (r.location < h) h = r.location; }
	if (t > 0 && t < n) { NSUInteger st = n - t; NSRange r = [s rangeOfComposedCharacterSequenceAtIndex: st]; if (r.location < st) t = n - (r.location + r.length); }
	while (h > 0 && [s characterAtIndex: h - 1] == ' ') h--; while (t > 0 && [s characterAtIndex: n - t] == ' ') t--;
	return [NSString stringWithFormat: @"%@…%@", [s substringToIndex: h], [s substringFromIndex: n - t]];
}
/* a name on at most `maxLines` lines: lines break after a space, after a hyphen (not before a digit) and after a slash; a word wider than the line breaks where it fills it; the last line is cut in the middle */
static NSArray *WrapLabel(NSString *s, NSDictionary *at, CGFloat w, int maxLines)
{
	NSMutableArray *lines = [NSMutableArray array]; NSString *rest = s;
	while ([rest length] && (int)[lines count] < maxLines - 1) {
		if (TextW(rest, at) <= w) break; NSUInteger n = [rest length], best = 0;
		for (NSUInteger p = 1; p < n; p++) {                                                                  /* p characters on this line */
			unichar c = [rest characterAtIndex: p - 1], nx = [rest characterAtIndex: p]; BOOL opp = c == ' ' || c == '/' || (c == '-' && p >= 2 && [[NSCharacterSet alphanumericCharacterSet] characterIsMember: [rest characterAtIndex: p - 2]] && ![[NSCharacterSet decimalDigitCharacterSet] characterIsMember: nx] && nx != ' ');
			if (!opp) continue; NSString *line = [[rest substringToIndex: p] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]; if (TextW(line, at) <= w) best = p; else break;
		}
		if (!best) { best = FitPrefix(rest, at, w); if (best < 1) best = 1; if (best < n) { NSRange r = [rest rangeOfComposedCharacterSequenceAtIndex: best]; if (r.location < best) best = r.location ?: 1; } }
		[lines addObject: [[rest substringToIndex: best] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]]; rest = [[rest substringFromIndex: best] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	}
	if ([rest length]) [lines addObject: Truncated(rest, at, w)]; return lines;
}
static void GlassPill(NSRect r, NSRect pressed)                                  /* a toolbar pill as measured on the Mac (dark theme): 36 high, fill 60 lit to 68 at the top and bottom edges, a dark ring (11) at the sides, a bright hairline (98) along the straight top and bottom edges */
{
	CGFloat rad = r.size.height / 2; NSGraphicsContext *g = [NSGraphicsContext currentContext]; BOOL dk = TFDark(); NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad];
	[g saveGraphicsState]; [body addClip];
	NSGradient *gr = [[NSGradient alloc] initWithColorsAndLocations: (dk ? TFRGB(68, 68, 68) : TFRGB(255, 255, 255)), 0.0, (dk ? TFRGB(60, 60, 60) : TFRGB(246, 246, 247)), 0.2, (dk ? TFRGB(60, 60, 60) : TFRGB(246, 246, 247)), 0.8, (dk ? TFRGB(68, 68, 68) : TFRGB(255, 255, 255)), 1.0, nil]; [gr drawInRect: r angle: 90];
	if (!NSIsEmptyRect(pressed) && NSIntersectsRect(pressed, r)) { [(dk ? TFRGBA(255, 255, 255, 0.12) : TFRGBA(0, 0, 0, 0.10)) setFill]; NSRect pc = NSInsetRect(NSIntersectionRect(pressed, r), 0, 2); [[NSBezierPath bezierPathWithRoundedRect: pc xRadius: MIN(pc.size.height, pc.size.width) / 2 yRadius: MIN(pc.size.height, pc.size.width) / 2] fill]; }       /* a capsule, as the lit circle of the view buttons: the box ran into the rim (its shape is not measured) */
	[g restoreGraphicsState];
	NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.5, 0.5) xRadius: rad - 0.5 yRadius: rad - 0.5]; [ring setLineWidth: 1]; [(dk ? TFRGBA(0, 0, 0, 0.70) : TFRGBA(0, 0, 0, 0.14)) setStroke]; [ring stroke];
	[g saveGraphicsState]; [[NSBezierPath bezierPathWithRect: NSMakeRect(r.origin.x + rad, r.origin.y, r.size.width - rad * 2, r.size.height)] addClip]; [ring setLineWidth: 1]; NSBezierPath *tb = [NSBezierPath bezierPath]; [tb moveToPoint: NSMakePoint(r.origin.x + rad, r.origin.y + 0.5)]; [tb lineToPoint: NSMakePoint(NSMaxX(r) - rad, r.origin.y + 0.5)]; [tb moveToPoint: NSMakePoint(r.origin.x + rad, NSMaxY(r) - 0.5)]; [tb lineToPoint: NSMakePoint(NSMaxX(r) - rad, NSMaxY(r) - 0.5)]; [tb setLineWidth: 1]; [(dk ? TFRGBA(255, 255, 255, 0.20) : TFRGBA(255, 255, 255, 0.9)) setStroke]; [tb stroke]; [g restoreGraphicsState];
}
static void FillRound(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }
static BOOL KeyWin(NSView *v) { BOOL k = [[v window] isKeyWindow], a = [NSApp isActive]; if (getenv("FINDER_DEBUG_KEY")) { static int last = -1; int now = k * 2 + a; if (now != last) { last = now; NSLog(@"KeyWin: key %d active %d", k, a); } } return k && a; }
static NSDictionary *Font(CGFloat sz, BOOL bold, NSColor *c) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: sz] : [NSFont systemFontOfSize: sz], NSForegroundColorAttributeName: c }; }
static void TextAt(NSString *s, CGFloat x, CGFloat cy, NSDictionary *at) { NSSize z = [s sizeWithAttributes: at]; [s drawAtPoint: NSMakePoint(x, cy - z.height / 2) withAttributes: at]; }

/* in-place renaming: a field over the name, the name selected without its extension; Return or a click elsewhere keeps the new name, Escape leaves the old one */
@interface TRenameField : NSTextField { @public void (^commit)(NSString *); BOOL done; }
@end
@implementation TRenameField
- (void)finish:(BOOL)keep { if (done) return; done = YES; NSString *v = [self stringValue]; void (^c)(NSString *) = commit; commit = nil; [self removeFromSuperview]; if (keep && c) c(v); }
- (void)cancelOperation:(id)s { [self finish: NO]; }
- (BOOL)textView:(NSTextView *)tv doCommandBySelector:(SEL)sel { if (sel == @selector(insertNewline:)) { [self finish: YES]; return YES; } if (sel == @selector(cancelOperation:)) { [self finish: NO]; return YES; } return NO; }
- (void)textDidEndEditing:(NSNotification *)n { [self finish: YES]; }
@end
void TFBeginRename(NSView *host, NSRect frame, NSString *name, BOOL centered, NSColor *bg, void (^commit)(NSString *))
{
	TRenameField *f = [[TRenameField alloc] initWithFrame: frame]; [f setBordered: NO]; [f setBezeled: NO]; [f setDrawsBackground: YES]; [f setBackgroundColor: bg ?: TFRGB(255, 255, 255)]; [f setTextColor: TFRGB(0, 0, 0)]; [f setFont: [NSFont systemFontOfSize: 12]]; [f setStringValue: name]; [f setFocusRingType: NSFocusRingTypeNone]; if (centered) [[f cell] setAlignment: NSTextAlignmentCenter]; f->commit = commit; [f setDelegate: (id)f];
	[host addSubview: f]; [[host window] makeFirstResponder: f]; NSTextView *fe = (NSTextView *)[f currentEditor]; NSString *ext = [name pathExtension]; NSRange r = NSMakeRange(0, [ext length] && [name length] > [ext length] + 1 ? [name length] - [ext length] - 1 : [name length]); [fe setSelectedRange: r]; [fe setInsertionPointColor: TFRGB(0, 0, 0)];
}
/* ---------- the scrolling base ---------- */
@implementation TScrollBase
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstResponder { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (CGFloat)contentHeight { return 0; }
- (void)drawBackground { [TF_CONTENT setFill]; NSRectFill([self bounds]); }
- (void)drawContent:(NSRect)dirty {}
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e {}
- (CGFloat)viewport { return [self bounds].size.height - topInset; }
- (CGFloat)maxOff { return MAX(0, [self contentHeight] - [self viewport]); }
- (void)scrollTo:(CGFloat)y { y = MAX(0, MIN(y, [self maxOff])); if (y != off) { off = y; [self setNeedsDisplay: YES]; } }
- (void)reveal:(NSRect)r { CGFloat vh = [self viewport]; if (r.origin.y < off) [self scrollTo: r.origin.y - 4]; else if (NSMaxY(r) > off + vh) [self scrollTo: NSMaxY(r) - vh + 4]; }
- (void)setFrameSize:(NSSize)s { [super setFrameSize: s]; [self scrollTo: off]; }
- (void)scrollWheel:(NSEvent *)e { [self scrollTo: off - [e deltaY] * 24]; }
- (NSRect)thumbRect
{
	CGFloat ch = [self contentHeight], vh = [self viewport]; if (ch <= vh + 0.5) return NSZeroRect; NSRect b = [self bounds]; CGFloat track = vh - 8, th = MAX(30, vh / ch * track), mo = [self maxOff];
	return NSMakeRect(b.size.width - 14, topInset + 4 + (mo > 0 ? off / mo * (track - th) : 0), 10, th);
}
- (void)drawRect:(NSRect)rect
{
	NSRect b = [self bounds]; [self drawBackground]; NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState];
	NSRectClip(NSMakeRect(0, topInset, b.size.width, b.size.height - topInset)); NSAffineTransform *t = [NSAffineTransform transform]; [t translateXBy: 0 yBy: topInset - off]; [t concat];
	@try { [self drawContent: NSMakeRect(0, off, b.size.width, [self viewport])]; } @catch (NSException *x) { NSLog(@"Finder: %@ drawContent: %@", [self class], x); }
	[g restoreGraphicsState];
	NSRect th = [self thumbRect]; if (!NSIsEmptyRect(th)) FillRound(th, 5, TFDark() ? TFRGB(159, 159, 159) : TFRGBA(0, 0, 0, 0.35));
}
- (void)mouseDown:(NSEvent *)e
{
	[[self window] makeFirstResponder: self]; NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSRect th = [self thumbRect];
	if (!NSIsEmptyRect(th) && p.x > th.origin.x - 4) {
		if (!NSPointInRect(p, th)) { [self scrollTo: off + (p.y < th.origin.y ? -1 : 1) * [self viewport]]; return; }
		CGFloat grab = p.y - th.origin.y; NSEvent *ev = e;
		while ([ev type] != NSLeftMouseUp) {
			ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
			NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; NSRect t2 = [self thumbRect]; CGFloat track = [self viewport] - 8 - t2.size.height;
			if (track > 0) [self scrollTo: (q.y - grab - topInset - 4) / track * [self maxOff]];
		}
		return;
	}
	[self contentMouseDown: NSMakePoint(p.x, p.y - topInset + off) event: e];
}
@end

/* ---------- the icon view ---------- */
/* the desktop's view options live in the preferences (com.apple.finder DesktopViewSettings > IconViewSettings), not in a .DS_Store */
static NSDictionary *TFDeskSettings(void) { const char *tv = getenv("FINDER_DESKTOP_VP"); if (tv) { int a = 64, b = 54, c = 12, e = 1; sscanf(tv, "%d,%d,%d,%d", &a, &b, &c, &e); return @{ @"iconSize": @(a), @"gridSpacing": @(b), @"textSize": @(c), @"labelOnBottom": @(e != 0) }; }       /* a test aid: size,spacing,text,labelBelow */
	id d = TFPref(@"DesktopViewSettings", nil); return [d isKindOfClass: [NSDictionary class]] ? d[@"IconViewSettings"] : nil; }
static void TFDeskSettingsSet(NSDictionary *vp) { id d = TFPref(@"DesktopViewSettings", nil); NSMutableDictionary *m = [d isKindOfClass: [NSDictionary class]] ? [d mutableCopy] : [NSMutableDictionary dictionaryWithObject: @"None" forKey: @"GroupBy"]; NSMutableDictionary *iv = [m[@"IconViewSettings"] mutableCopy] ?: [NSMutableDictionary dictionary]; [iv addEntriesFromDictionary: vp]; m[@"IconViewSettings"] = iv; TFSetPref(@"DesktopViewSettings", m); }
/* the selected label on the desktop: (0, 89, 209) on the Mac with the blue accent (0, 122, 255): the accent times (.8, .73, .82) */
static NSColor *DesktopPillColor(void) { NSColor *a = [TF_ACCENT colorUsingColorSpaceName: NSCalibratedRGBColorSpace]; if (!a) return TF_ACCENT; return [NSColor colorWithCalibratedRed: [a redComponent] * 0.8 green: [a greenComponent] * 0.73 blue: [a blueComponent] * 0.82 alpha: 1]; }
static const CGFloat kCW = 112, kCH = 126, kPad = 10, kIcon = 64;
/* grouping (View > Group By): the title and the order of the group an item falls in */
static NSString *GroupTitle(NSDictionary *it, NSString *key, int *order)
{
	NSString *t = nil; *order = 0;
	if ([key isEqual: @"name"]) { NSString *n = it[@"name"]; unichar c = [n length] ? [[n uppercaseString] characterAtIndex: 0] : '#'; t = [[NSCharacterSet letterCharacterSet] characterIsMember: c] ? [NSString stringWithCharacters: &c length: 1] : @"#"; *order = [t isEqual: @"#"] ? 1 : 0; }
	else if ([key isEqual: @"kind"]) t = TFKindString(it[@"path"], [it[@"dir"] boolValue]);
	else if ([key isEqual: @"application"]) { NSArray *ap = [it[@"dir"] boolValue] ? nil : TFAppsForFile(it[@"path"]); t = [ap count] ? ap[0][@"name"] : @"None"; *order = [ap count] ? 0 : 1; }
	else if ([key hasPrefix: @"date"]) { NSDate *d = [key isEqual: @"dateModified"] ? it[@"mod"] : [key isEqual: @"dateAdded"] ? (it[@"add"] ?: it[@"cre"]) : [key isEqual: @"dateLastOpened"] ? (it[@"acc"] ?: it[@"mod"]) : it[@"cre"]; NSTimeInterval age = -[d timeIntervalSinceNow]; NSCalendar *cal = [NSCalendar currentCalendar];
		if ([cal isDateInToday: d]) { t = @"Today"; *order = 0; } else if ([cal isDateInYesterday: d]) { t = @"Yesterday"; *order = 1; } else if (age < 7 * 86400) { t = @"Previous 7 Days"; *order = 2; } else if (age < 30 * 86400) { t = @"Previous 30 Days"; *order = 3; }
		else { NSDateFormatter *f = [[NSDateFormatter alloc] init]; [f setDateFormat: age < 365 * 86400 ? @"MMMM" : @"yyyy"]; t = [f stringFromDate: d]; *order = 4 + (int)(age / 86400 / 30); } }
	else if ([key isEqual: @"size"]) { unsigned long long z = [it[@"size"] unsignedLongLongValue]; BOOL dir = [it[@"dir"] boolValue]; NSArray *b = @[ @"Zero bytes", @"Less than 10 KB", @"10 KB – 100 KB", @"100 KB – 1 MB", @"1 MB – 10 MB", @"10 MB – 100 MB", @"100 MB – 1 GB", @"More than 1 GB" ]; int k = dir ? 0 : z == 0 ? 0 : z < 10000 ? 1 : z < 100000 ? 2 : z < 1000000 ? 3 : z < 10000000 ? 4 : z < 100000000 ? 5 : z < 1000000000ULL ? 6 : 7; t = dir ? @"Folders" : b[k]; *order = 8 - k; }
	else if ([key isEqual: @"tags"]) { NSArray *tg = it[@"tags"]; t = [tg count] ? tg[0] : @"No Tags"; *order = [tg count] ? 0 : 1; }
	return t ?: @"";
}
@implementation TIconView
- (void)reloadKeepingSelectionOrFolder:(NSString *)folder { NSArray *keep = [self selectedPaths]; CGFloat o = off; [self setFolder: folder]; for (NSUInteger i = 0; i < [_items count]; i++) if ([keep containsObject: _items[i][@"path"]]) [_sel addIndex: i]; off = o; [self setNeedsDisplay: YES]; }
/* the desktop's grid as the Finder lays it out, measured on the Mac (new files placed by the Finder at every combination of icon size 16..128, gridSpacing 33..100, text size 10..16, label below / right; AX positions of the icons): with the label below the columns are max(b(text) + (spacing - 33) * 10 / 7, 1.125 * size + 10) apart (b: 82 84 94 94 102 112 112 for text 10..16) and the rows 40 + 1.125 * size + d(text) (d: -6 -4 0 2 4 6 6); with the label right the columns are 1.125 * size + 96 + e(text) + (spacing - 33) * 10 / 7 (e: -20 -10 0 0 8 18 18) and the rows 1.125 * size + 6 */
static CGFloat TFDeskTab(const CGFloat *t, CGFloat text) { int i = (int)lround(text) - 10; return t[MAX(0, MIN(6, i))]; }
- (CGFloat)cw
{
	if (!desktop) return MAX(_isz + 40, _isz + _grid - 6);
	static const CGFloat b[7] = { 82, 84, 94, 94, 102, 112, 112 }, e[7] = { -20, -10, 0, 0, 8, 18, 18 };
	CGFloat sp = (_grid - 33) * 10.0 / 7.0; return round(_labelRight ? 1.125 * _isz + 96 + TFDeskTab(e, _textSize) + sp : MAX(TFDeskTab(b, _textSize) + sp, 1.125 * _isz + 10));
}
- (CGFloat)ch
{
	if (!desktop) return [self cw] + (_showInfo ? 14 : 0);
	static const CGFloat d[7] = { -6, -4, 0, 2, 4, 6, 6 };
	return round(_labelRight ? 1.125 * _isz + 6 : 40 + 1.125 * _isz + TFDeskTab(d, _textSize));
}
- (void)applyOptions { for (NSMutableDictionary *it in _items) [it removeObjectForKey: @"lines"]; [self scrollTo: off]; [self _save]; [self setNeedsDisplay: YES]; }
- (void)setIconSize:(CGFloat)z { z = MAX(16, MIN(256, z)); if (z == _isz) return; _isz = z; for (NSMutableDictionary *it in _items) [it removeObjectForKey: @"lines"]; [self scrollTo: off]; [self _save]; [self setNeedsDisplay: YES]; }
- (CGFloat)iconSize { return _isz; }
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _isz = 64; _grid = 54; _textSize = 12; _showInfo = NO; _showPreview = YES; _items = [NSMutableArray array]; _sel = [NSMutableIndexSet indexSet]; _anchor = -1; _dropTarget = -1; } return self; }/* the settings of a folder (the arrangement and the places of the icons), kept in ~/Library/Application Support/Finder/ViewSettings.plist until .DS_Store is read and written the way the Finder does */
- (void)drawBackground { if (desktop) { if (!TFWallpaperImage()) { [[NSColor clearColor] set]; NSRectFillUsingOperation([self bounds], NSCompositeCopy); } } else [super drawBackground]; }      /* on the desktop the picture under the view stays */
- (BOOL)isOpaque { return !desktop; }
- (void)setFolder:(NSString *)folder
{
	NSMutableArray *paths = [NSMutableArray array]; for (NSString *n in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: folder error: NULL] sortedArrayUsingSelector: @selector(tfNameCompare:)]) [paths addObject: [folder stringByAppendingPathComponent: n]];
	_folder = [folder copy]; if (desktop) { NSMutableArray *vp = [NSMutableArray array]; for (NSDictionary *v in TFVolumes()) { BOOL root = [v[@"path"] isEqual: @"/"]; if (root ? TFPrefBool(@"ShowHardDrivesOnDesktop", NO) : [v[@"kind"] isEqual: @"external"] ? TFPrefBool(@"ShowExternalHardDrivesOnDesktop", YES) : [v[@"kind"] isEqual: @"optical"] ? TFPrefBool(@"ShowRemovableMediaOnDesktop", YES) : TFPrefBool(@"ShowMountedServersOnDesktop", NO)) [vp addObject: v[@"path"]]; } _prefix = vp; [paths insertObjects: vp atIndexes: [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [vp count])]]; } [self setPaths: paths];
}
- (void)setPaths:(NSArray *)paths
{
	NSDate *t0 = [NSDate date]; [_items removeAllObjects]; [_sel removeAllIndexes]; NSFileManager *fm = [NSFileManager defaultManager]; TDSStore *ds = _folder ? [TDSStore storeForFolder: _folder] : nil; NSDictionary *vp = desktop ? TFDeskSettings() : [ds plistForName: @"." sid: @"icvp"]; if (vp) { _isz = [vp[@"iconSize"] doubleValue] >= 16 ? [vp[@"iconSize"] doubleValue] : 64; NSString *ab = vp[@"arrangeBy"]; _snap = [vp[@"arrangeBy"] isEqual: @"grid"]; NSDictionary *m = @{ @"name": @"name", @"kind": @"kind", @"dateModified": @"modified", @"dateCreated": @"created", @"size": @"size", @"label": @"tags" }; _arrange = m[ab]; } else { _isz = _isz ?: 64; }
	if (vp) { _grid = [vp[@"gridSpacing"] doubleValue] >= 20 ? [vp[@"gridSpacing"] doubleValue] : 54; _textSize = [vp[@"textSize"] doubleValue] >= 8 ? [vp[@"textSize"] doubleValue] : 12; _showInfo = [vp[@"showItemInfo"] boolValue]; _showPreview = vp[@"showIconPreview"] ? [vp[@"showIconPreview"] boolValue] : YES; _labelRight = vp[@"labelOnBottom"] && ![vp[@"labelOnBottom"] boolValue]; }
	for (NSString *p in paths) {
		NSString *n = TFDisplayName(p); if ([[p lastPathComponent] hasPrefix: @"."] || ([filter length] && [n rangeOfString: filter options: NSCaseInsensitiveSearch].location == NSNotFound)) continue; BOOL isVol = [_prefix containsObject: p];
		NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && !TFIsPackage(p); if (!dir && [at[NSFileType] isEqual: NSFileTypeSymbolicLink]) { BOOL sd = NO; if ([fm fileExistsAtPath: p isDirectory: &sd] && sd && !TFIsPackage(p)) dir = YES; }       /* a link to a folder is a folder for the Finder (the Applications link of a disk image takes the dropped app) */
		NSString *info = @"";
		if (isVol) info = @""; else if (dir) { NSUInteger c = 0; for (NSString *s in [fm contentsOfDirectoryAtPath: p error: NULL]) if (![s hasPrefix: @"."]) c++; info = [NSString stringWithFormat: @"%lu item%s", (unsigned long)c, c == 1 ? "" : "s"]; }
		else if (!TFIsPackage(p)) info = TFSizeString([at[NSFileSize] unsignedLongLongValue]);
		NSMutableDictionary *it = [@{ @"name": TFShownName(n), @"path": p, @"info": info, @"tags": TFTagsOf(p), @"dir": @(dir), @"mod": at[NSFileModificationDate] ?: [NSDate distantPast], @"acc": at[@"NSFileAccessDate"] ?: at[NSFileModificationDate] ?: [NSDate distantPast], @"cre": at[NSFileCreationDate] ?: [NSDate distantPast], @"size": at[NSFileSize] ?: @0 } mutableCopy];
		int ix, iy; if ([ds iconLocationOfName: [p lastPathComponent] x: &ix y: &iy]) it[@"pos"] = [NSValue valueWithPoint: NSMakePoint(ix - [self cw] / 2, iy - 4 - _isz / 2)];
		[_items addObject: it];
	}
	if ([_arrange length]) [self _sortItems]; [self _regroup]; off = 0; [self setNeedsDisplay: YES]; [self _notify]; if (getenv("FINDER_DEBUG")) NSLog(@"Finder: icon view loaded %lu items in %.0f ms", (unsigned long)[_items count], -[t0 timeIntervalSinceNow] * 1000);
}
- (void)_save                                                                                  /* the places of the icons and the view options go to .DS_Store, where the Finder keeps them */
{
	if (!_folder) return; TDSStore *ds = [TDSStore storeForFolder: _folder]; if (_isz < 16) _isz = 64;
	for (NSDictionary *it in _items) { NSString *n = [it[@"path"] lastPathComponent]; if (it[@"pos"]) { NSPoint q = [it[@"pos"] pointValue]; [ds setIconLocation: NSMakePoint(q.x + [self cw] / 2, q.y + 4 + _isz / 2) ofName: n]; } else [ds removeName: n sid: @"Iloc"]; }
	NSMutableDictionary *vp = [ds plistForName: @"." sid: @"icvp"] ?: [@{ @"backgroundType": @0, @"backgroundColorRed": @1.0, @"backgroundColorGreen": @1.0, @"backgroundColorBlue": @1.0, @"gridOffsetX": @0.0, @"gridOffsetY": @0.0, @"gridSpacing": @54.0, @"labelOnBottom": @YES, @"scrollPositionX": @0.0, @"scrollPositionY": @0.0, @"showIconPreview": @YES, @"showItemInfo": @NO, @"textSize": @12.0, @"viewOptionsVersion": @1 } mutableCopy];
	NSDictionary *m = @{ @"name": @"name", @"kind": @"kind", @"modified": @"dateModified", @"created": @"dateCreated", @"size": @"size", @"tags": @"label" }; vp[@"iconSize"] = @(_isz); vp[@"gridSpacing"] = @(_grid); vp[@"textSize"] = @(_textSize); vp[@"showItemInfo"] = @(_showInfo); vp[@"showIconPreview"] = @(_showPreview); vp[@"arrangeBy"] = m[_arrange ?: @""] ?: (_snap ? @"grid" : @"none");
	if (desktop) { TFDeskSettingsSet(@{ @"iconSize": @((int)_isz), @"gridSpacing": @((int)_grid), @"textSize": @((int)_textSize), @"labelOnBottom": @(!_labelRight), @"showItemInfo": @(_showInfo), @"showIconPreview": @(_showPreview), @"arrangeBy": vp[@"arrangeBy"] ?: @"none" }); [ds write]; return; }       /* the Desktop: the options go to the preferences, only the places of the icons to ~/Desktop/.DS_Store */
	[ds setPlist: vp forName: @"." sid: @"icvp"]; if (![ds valueForName: @"." sid: @"vSrn"]) [ds setValue: @1 type: @"long" forName: @"." sid: @"vSrn"]; [ds write];
}
- (void)reloadKeepingSelection { NSArray *keep = [self selectedPaths]; if (![_items count]) return; NSMutableArray *ps = [NSMutableArray array]; for (NSDictionary *d in _items) [ps addObject: d[@"path"]]; CGFloat o = off; [self setPaths: ps]; for (NSUInteger i = 0; i < [_items count]; i++) if ([keep containsObject: _items[i][@"path"]]) [_sel addIndex: i]; off = o; [self setNeedsDisplay: YES]; }
- (NSInteger)_cols { return MAX(1, (NSInteger)floor(([self bounds].size.width - 2 * kPad) / [self cw])); }
- (NSPoint)_slot:(NSInteger)i { if (_group && i < (NSInteger)[_gpos count]) return [_gpos[i] pointValue]; if (desktop) { CGFloat H = [self bounds].size.height, W = [self bounds].size.width; NSInteger per = MAX(1, (NSInteger)floor((H - 38) / [self ch])); return NSMakePoint(W - 4 - (i / per + 1) * [self cw], 30 + (_labelRight ? 3 : 0) + _isz / 16 + (i % per) * [self ch]); }       /* the first icon's top is 34 + size / 16 (37 + size / 16 with the label right) */       /* the first icon's top is 8 under the menu bar (30), its cell's right edge 4 from the screen's edge; the cells are centred on their icons */ NSInteger c = [self _cols]; return NSMakePoint(kPad + (i % c) * [self cw], kPad + (i / c) * [self ch]); }
- (NSPoint)_target:(NSInteger)i { NSValue *v = _group ? nil : _items[i][@"pos"]; return v ? [v pointValue] : [self _slot: i]; }
- (void)_regroup
{
	if (!_group) { _gpos = nil; _heads = nil; return; } NSMutableDictionary *ord = [NSMutableDictionary dictionary]; NSMutableArray *keys = [NSMutableArray array];
	for (NSMutableDictionary *it in _items) { int o; NSString *t = GroupTitle(it, _group, &o); it[@"gt"] = t; it[@"go"] = @(o); if (!ord[t]) { ord[t] = @(o); [keys addObject: t]; } }
	[keys sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) { NSComparisonResult r = [ord[a] compare: ord[b]]; return r != NSOrderedSame ? r : [a tfNameCompare: b]; }];
	NSMutableArray *sorted = [NSMutableArray array]; for (NSString *k in keys) for (NSMutableDictionary *it in _items) if ([it[@"gt"] isEqual: k]) [sorted addObject: it]; [_items setArray: sorted];
	NSInteger cols = [self _cols]; CGFloat y = kPad; NSMutableArray *pos = [NSMutableArray array], *heads = [NSMutableArray array]; NSUInteger idx = 0;
	for (NSString *k in keys) { NSUInteger n = 0; for (NSDictionary *it in _items) if ([it[@"gt"] isEqual: k]) n++; [heads addObject: @{ @"t": k, @"y": @(y), @"n": @(n) }]; y += 34; for (NSUInteger j = 0; j < n; j++, idx++) [pos addObject: [NSValue valueWithPoint: NSMakePoint(kPad + (j % cols) * [self cw], y + (j / cols) * [self ch])]]; y += ceil((double)n / cols) * [self ch] + 10; }
	_gpos = pos; _heads = heads; _groupBottom = y;
}
- (void)setGroup:(NSString *)g { _group = [g length] ? [g copy] : nil; [self _regroup]; [self setNeedsDisplay: YES]; }
- (void)setFrameSize:(NSSize)s { [super setFrameSize: s]; if (_group) [self _regroup]; }
- (CGFloat)contentHeight { if (_group && _gpos) return _groupBottom + kPad; NSInteger c = [self _cols]; CGFloat h = 2 * kPad + ceil((double)[_items count] / c) * [self ch]; for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) h = MAX(h, [self _target: i].y + [self ch] + kPad); return h; }
- (NSRect)_cell:(NSInteger)i
{
	NSPoint t = [self _target: i]; NSValue *from = _items[i][@"from"];
	if (from && _animStart) { double k = ([NSDate timeIntervalSinceReferenceDate] - _animStart) / 0.28; if (k >= 1) k = 1; double e = 1 - pow(1 - k, 3); NSPoint f = [from pointValue]; t = NSMakePoint(f.x + (t.x - f.x) * e, f.y + (t.y - f.y) * e); }
	return NSMakeRect(t.x, t.y, [self cw], [self ch]);
}
- (NSInteger)_indexBelowDragged:(NSPoint)p { for (NSInteger i = (NSInteger)[_items count] - 1; i >= 0; i--) { if ([_sel containsIndex: i]) continue; NSRect c = [self _cell: i]; if (NSPointInRect(p, NSMakeRect(c.origin.x + 12, c.origin.y, c.size.width - 24, _isz + 36))) return i; } return -1; }       /* the item under the pointer that is not one of the dragged ones (they follow the pointer and lie on top) */
- (NSInteger)_index:(NSPoint)p { for (NSInteger i = (NSInteger)[_items count] - 1; i >= 0; i--) { NSRect c = [self _cell: i]; if (NSPointInRect(p, NSMakeRect(c.origin.x + 12, c.origin.y, c.size.width - 24, _isz + 36))) return i; } return -1; }
- (void)_animateFrom:(NSArray *)old                                                       /* the icons glide from where they were to where they now belong */
{
	for (NSInteger i = 0; i < (NSInteger)[_items count] && i < (NSInteger)[old count]; i++) if (old[i] != [NSNull null]) _items[i][@"from"] = old[i];
	_animStart = [NSDate timeIntervalSinceReferenceDate]; [_animTimer invalidate]; _animTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(_tick:) userInfo: nil repeats: YES]; [self setNeedsDisplay: YES];
}
- (void)_tick:(NSTimer *)t { [self setNeedsDisplay: YES]; if ([NSDate timeIntervalSinceReferenceDate] - _animStart > 0.3) { [t invalidate]; _animTimer = nil; _animStart = 0; for (NSMutableDictionary *it in _items) [it removeObjectForKey: @"from"]; } }
- (NSArray *)_origins { NSMutableArray *o = [NSMutableArray array]; for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) [o addObject: [NSValue valueWithPoint: [self _cell: i].origin]]; return o; }
- (void)_sortItems
{
	NSString *k = _arrange; if (![k length]) return;
	[_items sortUsingComparator: ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		NSComparisonResult r;
		if ([k isEqual: @"kind"]) { r = [(a[@"dir"] ? TFKindString(a[@"path"], [a[@"dir"] boolValue]) : @"") tfNameCompare: (b[@"dir"] ? TFKindString(b[@"path"], [b[@"dir"] boolValue]) : @"")]; }
		else if ([k isEqual: @"modified"]) r = [b[@"mod"] compare: a[@"mod"]]; else if ([k isEqual: @"opened"]) r = [b[@"acc"] ?: b[@"mod"] compare: a[@"acc"] ?: a[@"mod"]]; else if ([k isEqual: @"created"]) r = [b[@"cre"] compare: a[@"cre"]];
		else if ([k isEqual: @"size"]) r = [b[@"size"] compare: a[@"size"]]; else if ([k isEqual: @"tags"]) r = (NSComparisonResult)((int)[b[@"tags"] count] - (int)[a[@"tags"] count]);
		else { if (TFPrefBool(@"_FXSortFoldersFirst", YES) && [a[@"dir"] boolValue] != [b[@"dir"] boolValue]) return [a[@"dir"] boolValue] ? NSOrderedAscending : NSOrderedDescending; r = [a[@"name"] tfNameCompare: b[@"name"]]; }
		return r == NSOrderedSame ? [a[@"name"] tfNameCompare: b[@"name"]] : r;
	}];
	[_sel removeAllIndexes];
}
/* Sort By > Snap to Grid: the icons keep their order of placing but sit on the cells of the grid (the key of the view settings is arrangeBy = grid) */
- (void)setSnapToGrid:(BOOL)on { _snap = on; if (on) { _arrange = nil; for (NSMutableDictionary *it in _items) { NSValue *v = it[@"pos"]; if (!v) continue; NSPoint np = [v pointValue]; np.x = MAX(0, kPad + round((np.x - kPad) / [self cw]) * [self cw]); np.y = MAX(0, kPad + round((np.y - kPad) / [self ch]) * [self ch]); it[@"pos"] = [NSValue valueWithPoint: np]; } } [self _save]; [self setNeedsDisplay: YES]; }
- (void)arrangeBy:(NSString *)key                                                          /* Sort By: nil is None (the icons stay where they are put) */
{
	NSArray *old = [self _origins]; NSArray *names = nil; NSMutableArray *sel = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { [sel addObject: self->_items[i][@"path"]]; }]; (void)names;
	NSMutableArray *oldPaths = [NSMutableArray array]; for (NSDictionary *d in _items) [oldPaths addObject: d[@"path"]];
	_arrange = [key copy]; if (key) { for (NSMutableDictionary *it in _items) [it removeObjectForKey: @"pos"]; [self _sortItems]; }
	NSMutableArray *remap = [NSMutableArray array]; for (NSDictionary *d in _items) { NSUInteger k = [oldPaths indexOfObject: d[@"path"]]; [remap addObject: k < [old count] ? old[k] : (id)[NSNull null]]; }
	for (NSUInteger i = 0; i < [_items count]; i++) if ([sel containsObject: _items[i][@"path"]]) [_sel addIndex: i];
	[self _regroup]; [self _save]; [self _animateFrom: remap]; [self _notify];
}
- (void)cleanUp:(BOOL)selectionOnly
{
	NSArray *old = [self _origins]; NSMutableArray *oldPaths = [NSMutableArray array]; for (NSDictionary *d in _items) [oldPaths addObject: d[@"path"]];
	NSMutableArray *sel = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { [sel addObject: self->_items[i][@"path"]]; }];
	for (NSMutableDictionary *it in _items) if (!selectionOnly || [sel containsObject: it[@"path"]]) [it removeObjectForKey: @"pos"];
	if (!selectionOnly && [_arrange length]) [self _sortItems]; else if (!selectionOnly) { [_items sortUsingComparator: ^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"name"] tfNameCompare: b[@"name"]]; }]; }
	NSMutableArray *remap = [NSMutableArray array]; for (NSDictionary *d in _items) { NSUInteger k = [oldPaths indexOfObject: d[@"path"]]; [remap addObject: k < [old count] ? old[k] : (id)[NSNull null]]; }
	[_sel removeAllIndexes]; for (NSUInteger i = 0; i < [_items count]; i++) if ([sel containsObject: _items[i][@"path"]]) [_sel addIndex: i];
	[self _save]; [self _animateFrom: remap];
}
- (void)drawContent:(NSRect)v
{
	NSDictionary *lab = Font(_textSize, NO, desktop ? TFRGB(255, 255, 255) : TF_TEXT); NSDictionary *labSel = Font(_textSize, NO, TFRGB(255, 255, 255)); NSDictionary *inf = Font(MAX(9, _textSize - 1.5), NO, TFDark() ? TFRGB(66, 140, 235) : TFRGB(0, 100, 220)); BOOL key = KeyWin(self);
	for (NSDictionary *hd in _heads) { CGFloat hy = [hd[@"y"] doubleValue]; if (hy + 34 < v.origin.y || hy > NSMaxY(v)) continue; [hd[@"t"] drawAtPoint: NSMakePoint(kPad + 4, hy + 2) withAttributes: Font(15, YES, desktop ? TFRGB(255, 255, 255) : TF_TEXT)]; [TF_LINE setFill]; NSRectFill(NSMakeRect(kPad, hy + 28, [self bounds].size.width - 2 * kPad - 14, 1)); }
	for (NSInteger pass = 0; pass < 2; pass++) for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) {                                                                    /* the dragged icons last, on top */
		BOOL moving = _dragging && [_sel containsIndex: i]; if ((pass == 1) != moving) continue;
		NSRect c = [self _cell: i]; if (NSMaxY(c) < v.origin.y || c.origin.y > NSMaxY(v)) continue; NSMutableDictionary *it = _items[i]; BOOL sel = [_sel containsIndex: i];
		NSRect ir = NSMakeRect(c.origin.x + (desktop && _labelRight ? _isz / 16.0 : ([self cw] - _isz) / 2), c.origin.y + 4, _isz, _isz);
		if (_dropTarget == i) FillRound(NSInsetRect(ir, -6, -6), 8, key ? TFRGBA(0, 98, 225, 0.55) : TFRGBA(120, 120, 120, 0.4));
		if (sel && desktop) { NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(ir, -3, -3) xRadius: 8 yRadius: 8]; [ring setLineWidth: 2]; [TFRGB(77, 77, 84) setStroke]; [ring stroke]; }       /* the desktop: a 2 pt ring 72 x 72 round the 64 pt icon, no fill (Mac AX + pixels) */
		else if (sel) FillRound(NSInsetRect(ir, -4, -4), 6, TFDark() ? (key ? TFRGBA(255, 255, 255, 0.14) : TFRGB(52, 52, 52)) : TFRGBA(0, 0, 0, 0.09));
		NSImage *thumb = _showPreview ? Thumb(it[@"path"]) : nil;
		if (thumb) { NSSize z = [thumb size]; CGFloat k = MIN(_isz / z.width, _isz / z.height); NSRect tr = NSMakeRect(NSMidX(ir) - z.width * k / 2, NSMidY(ir) - z.height * k / 2, z.width * k, z.height * k); [TFRGBA(0, 0, 0, 0.35) setFill]; NSRectFill(NSOffsetRect(tr, 0, 1)); [thumb drawInRect: tr fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
		else TFDrawIcon(it[@"path"], ir);
		NSArray *lines = it[@"lines"]; if (!lines) { lines = WrapLabel(it[@"name"], lab, [self cw] - 6.5, 2); it[@"lines"] = lines; }
		CGFloat y = c.origin.y + (desktop ? 4 + _isz + 6 + _isz / 16.0 + 0.375 * _textSize : 17 + _isz); CGFloat lh = 16;      /* the desktop's first line: its ascenders start 6 + size / 16 under the icon (Mac, size 16..128), centre 0.375 of the text size lower */
		if (desktop && _labelRight) { NSString *ln = [WrapLabel(it[@"name"], lab, [self cw] - _isz - 22, 1) firstObject] ?: @""; NSSize z = [ln sizeWithAttributes: lab]; CGFloat tx = ir.origin.x + _isz + 7 + _isz / 16.0, ty = NSMidY(ir) - 1; if (sel) FillRound(NSMakeRect(tx - 4.5, ty - 8.5, z.width + 9, 17), 7, key ? DesktopPillColor() : TFRGB(208, 208, 208)); if ([it[@"tags"] count]) [NSClassFromString(@"WsdFinderSupport") drawTagDots: it[@"tags"] rightEdge: tx - 8 centerY: ty]; [ln drawAtPoint: NSMakePoint(tx, ty - z.height / 2) withAttributes: sel ? (key ? labSel : Font(_textSize, NO, TFRGB(102, 102, 102))) : lab]; continue; }       /* the label right of the icon: 7 + size / 16 from it, centred 1 above its middle */      /* the desktop's first line is 79 under the icon's top (Mac), 2 lower than in a window */
		if (sel && desktop) { CGFloat mw = 0; for (NSString *ln in lines) mw = MAX(mw, [ln sizeWithAttributes: lab].width); FillRound(NSMakeRect(NSMidX(c) - mw / 2 - 4.5, y - 9, mw + 9, lh * ([lines count] - 1) + 17), 7, key ? DesktopPillColor() : TFRGB(208, 208, 208)); }       /* another application in front: a light grey pill (208) with grey text (102) */       /* one pill for both lines: 93 x 33 for two lines of 84 pt text (Mac) */
		for (NSString *ln in lines) {
			NSSize z = [ln sizeWithAttributes: lab]; if (ln == [lines firstObject] && [it[@"tags"] count]) [NSClassFromString(@"WsdFinderSupport") drawTagDots: it[@"tags"] rightEdge: NSMidX(c) - z.width / 2 - 9 centerY: y];
			if (sel && !desktop) FillRound(NSMakeRect(NSMidX(c) - z.width / 2 - 5, y - 9, z.width + 10, 18), 5, key ? TF_ACCENT : TFDark() ? TFRGB(90, 90, 90) : TFRGB(190, 190, 194));
			[ln drawAtPoint: NSMakePoint(NSMidX(c) - z.width / 2, y - z.height / 2) withAttributes: sel ? (desktop && !key ? Font(_textSize, NO, TFRGB(102, 102, 102)) : labSel) : lab]; y += lh;
		}
		if (!desktop && _showInfo && [it[@"info"] length]) { NSSize z = [it[@"info"] sizeWithAttributes: inf]; [it[@"info"] drawAtPoint: NSMakePoint(NSMidX(c) - z.width / 2, y - z.height / 2 - 1) withAttributes: inf]; }
	}
	if (![_items count] && [emptyMessage length]) { NSDictionary *a = Font(13, NO, TF_DIM); NSSize z = [emptyMessage sizeWithAttributes: a]; [emptyMessage drawAtPoint: NSMakePoint([self bounds].size.width / 2 - z.width / 2, [self bounds].size.height / 2 - z.height / 2 - 20) withAttributes: a]; }
	if (!NSIsEmptyRect(_band)) { [TFRGBA(120, 160, 255, 0.18) setFill]; NSRectFill(_band); [TFRGBA(120, 160, 255, 0.6) setStroke]; NSFrameRect(_band); }
}
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (NSArray *)selectedPaths { NSMutableArray *a = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { [a addObject: self->_items[i][@"path"]]; }]; return a; }
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e
{
	NSInteger i = [self _index: p]; NSUInteger fl = [e modifierFlags]; BOOL multi = (fl & NSCommandKeyMask) != 0; if (getenv("FINDER_DEBUG_KEY")) NSLog(@"content mouse down at %@: item %ld desktop %d", NSStringFromPoint(p), (long)i, (int)desktop);
	if (i < 0) {                                                                                                                                  /* a rubber band over the background */
		NSIndexSet *base = multi ? [_sel copy] : [NSIndexSet indexSet]; NSPoint a = p; NSEvent *ev = e; [_sel removeAllIndexes]; [_sel addIndexes: base];
		while ([ev type] != NSLeftMouseUp) {
			ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
			NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; q.y = q.y - topInset + off; _band = NSMakeRect(MIN(a.x, q.x), MIN(a.y, q.y), fabs(q.x - a.x), fabs(q.y - a.y));
			[_sel removeAllIndexes]; [_sel addIndexes: base]; for (NSInteger k = 0; k < (NSInteger)[_items count]; k++) { NSRect c = [self _cell: k]; if (NSIntersectsRect(_band, NSMakeRect(c.origin.x + ([self cw] - _isz) / 2, c.origin.y + 4, _isz, _isz + 40))) [_sel addIndex: k]; }
			[self setNeedsDisplay: YES];
		}
		_band = NSZeroRect; [self setNeedsDisplay: YES]; [self _notify]; return;
	}
	BOOL wasSel = [_sel containsIndex: i];
	if (fl & NSShiftKeyMask && _anchor >= 0) { [_sel removeAllIndexes]; [_sel addIndexesInRange: NSMakeRange(MIN(_anchor, i), labs(i - _anchor) + 1)]; }
	else if (multi) { if (wasSel) [_sel removeIndex: i]; else [_sel addIndex: i]; _anchor = i; }
	else { if (!wasSel) { [_sel removeAllIndexes]; [_sel addIndex: i]; } _anchor = i; }
	[self setNeedsDisplay: YES]; [self _notify];
	if ([e clickCount] == 2 && [delegate respondsToSelector: @selector(iconViewOpenItem:)]) { [delegate iconViewOpenItem: _items[i][@"path"]]; return; }
	[self _dragFrom: p event: e];
}
- (void)_dragFrom:(NSPoint)start event:(NSEvent *)e                                              /* the selected icons follow the pointer; dropped on a folder they move into it, on the sidebar or another window the controller decides, elsewhere they stay where they are put */
{
	NSMutableArray *idx = [NSMutableArray array], *orig = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger k, BOOL *s) { [idx addObject: @(k)]; [orig addObject: [NSValue valueWithPoint: [self _target: (NSInteger)k]]]; }];
	NSEvent *ev = e; BOOL moved = NO; NSArray *paths = [self selectedPaths]; if (getenv("FINDER_DEBUG_KEY")) NSLog(@"drag from: desktop %d, %lu icons", (int)desktop, (unsigned long)[idx count]);
	while ([ev type] != NSLeftMouseUp) {
		ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; q.y = q.y - topInset + off; if (!moved && hypot(q.x - start.x, q.y - start.y) < 4) continue;
		moved = YES; _dragging = YES; _dropTarget = -1;
		for (NSUInteger k = 0; k < [idx count]; k++) { NSPoint o = [orig[k] pointValue]; _items[[idx[k] integerValue]][@"pos"] = [NSValue valueWithPoint: NSMakePoint(o.x + q.x - start.x, o.y + q.y - start.y)]; }
		NSInteger over = [self _indexBelowDragged: q]; if (over >= 0 && [_items[over][@"dir"] boolValue] && ![_sel containsIndex: over]) _dropTarget = over;
		[self setNeedsDisplay: YES]; [self reveal: NSMakeRect(q.x - 20, q.y - 20, 40, 40)];
	}
	_dragging = NO; if (!moved) return;
	NSPoint wp = [ev locationInWindow]; BOOL copy = ([ev modifierFlags] & NSAlternateKeyMask) != 0; NSInteger target = _dropTarget; _dropTarget = -1; if (getenv("FINDER_DEBUG_KEY")) NSLog(@"drag ended: desktop %d target %ld moved %d at %@", (int)desktop, (long)target, (int)moved, NSStringFromPoint(wp));
	NSString *into = target >= 0 ? _items[target][@"path"] : nil;
	if (desktop && !into && [delegate respondsToSelector: @selector(iconViewDropOtherWindow:atWindowPoint:copy:)] && [(id)delegate iconViewDropOtherWindow: paths atWindowPoint: wp copy: copy]) { for (NSUInteger k = 0; k < [idx count]; k++) _items[[idx[k] integerValue]][@"pos"] = orig[k]; [self setNeedsDisplay: YES]; return; }       /* put down on a Finder window above the desktop */
	BOOL inside = NSPointInRect([self convertPoint: wp fromView: nil], [self bounds]);
	for (NSUInteger k = 0; k < [idx count]; k++) _items[[idx[k] integerValue]][@"pos"] = orig[k];                                                                                       /* back to where they were, then: */
	if (into || !inside) { if ([delegate respondsToSelector: @selector(iconViewDropPaths:intoFolder:atWindowPoint:copy:)] && [(id)delegate iconViewDropPaths: paths intoFolder: into atWindowPoint: wp copy: copy]) { [self setNeedsDisplay: YES]; return; } }
	else {                                                                                                                                                                                        /* put down on the background: the icons take the new places */
		_arrange = nil; for (NSUInteger k = 0; k < [idx count]; k++) { NSPoint o = [orig[k] pointValue]; NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; q.y = q.y - topInset + off; NSPoint np = NSMakePoint(o.x + q.x - start.x, o.y + q.y - start.y); np.x = MAX(0, np.x); np.y = MAX(0, np.y); if (_snap) { np.x = kPad + round((np.x - kPad) / [self cw]) * [self cw]; np.y = kPad + round((np.y - kPad) / [self ch]) * [self ch]; } _items[[idx[k] integerValue]][@"pos"] = [NSValue valueWithPoint: np]; }
		[self _save];
	}
	[self setNeedsDisplay: YES];
}
- (NSMenu *)menuForEvent:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSInteger i = [self _index: NSMakePoint(p.x, p.y - topInset + off)];
	if (i >= 0 && ![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; [self setNeedsDisplay: YES]; [self _notify]; } else if (i < 0) { [_sel removeAllIndexes]; [self setNeedsDisplay: YES]; [self _notify]; }
	if (i < 0 && !desktop && [delegate respondsToSelector: @selector(backgroundContextMenu)]) { NSMenu *bg = [(id)delegate backgroundContextMenu]; if (bg) { TFPopupMenu(self, p, bg); return nil; } }
	if (desktop && i >= 0 && [delegate respondsToSelector: @selector(itemContextMenu)]) { TFPopupMenu(self, p, [(id)delegate itemContextMenu]); return nil; }       /* an item of the desktop: its own menu; the background has [self menu] */
	if ([delegate respondsToSelector: @selector(prepareContextMenu:)]) [(id)delegate prepareContextMenu: [self menu]]; TFPopupMenu(self, p, [self menu]); return nil;
}
- (BOOL)beginRename:(NSString *)path
{
	for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) if ([_items[i][@"path"] isEqual: path]) { NSRect c = [self _cell: i]; [self reveal: c]; c = [self _cell: i]; NSRect lr = NSMakeRect(c.origin.x + 4, c.origin.y + 4 + _isz + 4, [self cw] - 8, 18); lr.origin.y = lr.origin.y - off + topInset; __weak TIconView *me = self; NSString *old = path;
		TFBeginRename(self, lr, [path lastPathComponent], YES, nil, ^(NSString *nn) { TIconView *s = me; if (s && [s->delegate respondsToSelector: @selector(iconViewRename:to:)]) [(id)s->delegate iconViewRename: old to: nn]; }); return YES; }
	return NO;
}
- (void)selectAll:(id)s { [_sel addIndexesInRange: NSMakeRange(0, [_items count])]; [self setNeedsDisplay: YES]; [self _notify]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0]; NSInteger cur = [_sel count] ? (NSInteger)[_sel lastIndex] : -1, n = (NSInteger)[_items count], cols = [self _cols], t = cur; NSUInteger fl = [e modifierFlags];
	if (c == NSLeftArrowFunctionKey) t = MAX(0, cur - 1); else if (c == NSRightArrowFunctionKey) t = cur < 0 ? 0 : MIN(n - 1, cur + 1);
	else if (c == NSUpArrowFunctionKey && !(fl & NSCommandKeyMask)) t = cur < 0 ? 0 : MAX(0, cur - cols); else if (c == NSDownArrowFunctionKey && !(fl & NSCommandKeyMask)) t = cur < 0 ? 0 : MIN(n - 1, cur + cols);
	else if (c == '\r' && cur >= 0 && !desktop) { [NSApp sendAction: @selector(cmdRename:) to: nil from: self]; return; }
	else if ((c == '\r' || (c == NSDownArrowFunctionKey && (fl & NSCommandKeyMask))) && cur >= 0) { [delegate iconViewOpenItem: _items[cur][@"path"]]; return; }
	else if (c == NSUpArrowFunctionKey && (fl & NSCommandKeyMask)) { [NSApp sendAction: @selector(cmdOpenParent:) to: nil from: self]; return; }
	else if (c == ' ') { if ([(id)delegate respondsToSelector: @selector(cmdQuickLook:)]) [(id)delegate performSelector: @selector(cmdQuickLook:) withObject: self]; else [NSApp sendAction: @selector(cmdQuickLook:) to: nil from: self]; return; }       /* the desktop's view is not in the responder chain of its icons */
	else if (isalnum(c) && !(fl & (NSCommandKeyMask | NSControlKeyMask))) {                                                                           /* type to select */
		static NSString *buf; static NSDate *last; if (!last || [[NSDate date] timeIntervalSinceDate: last] > 1) buf = @""; buf = [buf stringByAppendingString: [k lowercaseString]]; last = [NSDate date];
		for (NSInteger i = 0; i < n; i++) if ([[_items[i][@"name"] lowercaseString] hasPrefix: buf]) { t = i; break; }
	}
	else { [super keyDown: e]; return; }
	if (n) { [_sel removeAllIndexes]; [_sel addIndex: MAX(0, t)]; _anchor = MAX(0, t); [self reveal: [self _cell: MAX(0, t)]]; [self setNeedsDisplay: YES]; [self _notify]; }
}
@end

/* ---------- the list view ---------- */
static const CGFloat kHead = 28;       /* the list's rows: 20 pt with 16 pt icons and 13 pt text, 36 with 32 pt icons, 21 / 22 / 23 with 14 / 15 / 16 pt text (Mac AX) */
@implementation TListView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _items = [NSMutableArray array]; _sel = [NSMutableIndexSet indexSet]; _sortKey = @"name"; _rowH = 20; _listText = 13; _asc = YES; topInset = kHead; _anchor = -1; _exp = [NSMutableSet set]; _kids = [NSMutableDictionary dictionary]; _roots = [NSMutableArray array]; [self _defaultColumns]; } return self; }
- (void)setFolder:(NSString *)folder
{
	_folder = [folder copy]; [self _defaultColumns]; _colKey = nil; _sortKey = @"name"; _asc = YES; [self _loadColumns];
	NSMutableArray *paths = [NSMutableArray array]; for (NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: folder error: NULL]) [paths addObject: [folder stringByAppendingPathComponent: n]]; [self setPaths: paths];
}
- (NSMutableDictionary *)_makeItem:(NSString *)p fm:(NSFileManager *)fm depth:(int)depth
{
	NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && !TFIsPackage(p);
	return [@{ @"name": TFShownName([p lastPathComponent]), @"path": p, @"dir": @(dir), @"date": at[NSFileModificationDate] ?: [NSDate distantPast], @"mod": at[NSFileModificationDate] ?: [NSDate distantPast], @"size": dir ? @(-1) : at[NSFileSize] ?: @0, @"kind": TFKindString(p, dir), @"tags": TFTagsOf(p), @"depth": @(depth), @"cre": at[NSFileCreationDate] ?: [NSDate distantPast], @"acc": at[@"NSFileAccessDate"] ?: at[NSFileModificationDate] ?: [NSDate distantPast], @"tagsort": [TFTagsOf(p) componentsJoinedByString: @","] } mutableCopy];
}
- (void)setPaths:(NSArray *)paths
{
	[_roots removeAllObjects]; [_kids removeAllObjects]; [_exp removeAllObjects]; [_sel removeAllIndexes]; NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *p in paths) @try { NSString *n = [p lastPathComponent]; if ([n hasPrefix: @"."] || ([filter length] && [n rangeOfString: filter options: NSCaseInsensitiveSearch].location == NSNotFound)) continue; [_roots addObject: [self _makeItem: p fm: fm depth: 0]]; } @catch (NSException *x) { NSLog(@"TListView %@: %@", p, x); }
	[self _sort]; off = 0; [self setNeedsDisplay: YES]; [self _notify];
}
- (void)sortByColumn:(NSString *)col { _colKey = col; _sortKey = SortFieldFor(col); _asc = YES; [self _sort]; [self setNeedsDisplay: YES]; [self _saveColumns]; }
- (NSComparisonResult)_cmp:(NSDictionary *)a with:(NSDictionary *)b { NSString *k = _sortKey; BOOL asc = _asc; if ([k isEqual: @"name"] && TFPrefBool(@"_FXSortFoldersFirst", YES) && [a[@"dir"] boolValue] != [b[@"dir"] boolValue]) return (asc == ([a[@"dir"] boolValue])) ? NSOrderedAscending : NSOrderedDescending; NSComparisonResult r = [k isEqual: @"name"] || [k isEqual: @"kind"] ? [a[k] tfNameCompare: b[k]] : [a[k] compare: b[k]]; return asc ? r : (NSComparisonResult)(-r); }
- (void)_sort
{
	__weak TListView *me = self; NSComparisonResult (^cmp)(id, id) = ^NSComparisonResult(id a, id b) { return [me _cmp: a with: b]; };
	[_roots sortUsingComparator: cmp]; for (NSString *k in [_kids allKeys]) [_kids[k] sortUsingComparator: cmp]; [self _rebuild];
}
- (void)_rebuild
{
	NSArray *keep = [self selectedPaths]; [_items removeAllObjects]; __block __weak void (^addLevel)(NSArray *) = nil; void (^add)(NSArray *) = ^(NSArray *level) { for (NSMutableDictionary *it in level) { [_items addObject: it]; if ([_exp containsObject: it[@"path"]] && _kids[it[@"path"]]) addLevel(_kids[it[@"path"]]); } }; addLevel = add;
	if (!_group) add(_roots);
	else {                                                                                                                    /* Use Groups: a header row, then the items of the group in the sort order */
		NSMutableDictionary *byTitle = [NSMutableDictionary dictionary], *order = [NSMutableDictionary dictionary]; NSMutableArray *titles = [NSMutableArray array];
		for (NSMutableDictionary *it in _roots) { int o; NSString *t = GroupTitle(it, _group, &o); if (!byTitle[t]) { byTitle[t] = [NSMutableArray array]; order[t] = @(o); [titles addObject: t]; } [byTitle[t] addObject: it]; }
		[titles sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) { NSComparisonResult r = [order[a] compare: order[b]]; return r != NSOrderedSame ? r : [a tfNameCompare: b]; }];
		for (NSString *t in titles) { [_items addObject: [@{ @"header": @YES, @"name": t, @"path": @"", @"dir": @NO, @"depth": @0, @"count": @([byTitle[t] count]) } mutableCopy]]; add(byTitle[t]); }
	}
	[_sel removeAllIndexes]; for (NSUInteger i = 0; i < [_items count]; i++) if ([keep containsObject: _items[i][@"path"]]) [_sel addIndex: i]; [self setNeedsDisplay: YES];
}
- (void)_toggleRow:(NSInteger)row
{
	NSMutableDictionary *it = _items[row]; if (![it[@"dir"] boolValue]) return; NSString *p = it[@"path"];
	if ([_exp containsObject: p]) [_exp removeObject: p]; else { if (!_kids[p]) { NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *k = [NSMutableArray array]; for (NSString *n in [fm contentsOfDirectoryAtPath: p error: NULL]) if (![n hasPrefix: @"."]) [k addObject: [self _makeItem: [p stringByAppendingPathComponent: n] fm: fm depth: [it[@"depth"] intValue] + 1]]; __weak TListView *me = self; [k sortUsingComparator: ^NSComparisonResult(id a, id b) { return [me _cmp: a with: b]; }]; _kids[p] = k; } [_exp addObject: p]; }
	[self _rebuild];
}
- (CGFloat)contentHeight { return [_items count] * _rowH + 8; }
/* the columns: identifier, title, width, visible (the names of the Finder's lsvp: name, dateModified, dateCreated, dateLastOpened, dateAdded, size, kind, label) */
- (void)_defaultColumns
{
	NSMutableArray *d = [NSMutableArray array]; for (NSArray *c in @[ @[ @"name", @"Name", @300, @YES ], @[ @"dateModified", @"Date Modified", @169, @YES ], @[ @"dateCreated", @"Date Created", @169, @NO ], @[ @"dateLastOpened", @"Date Last Opened", @169, @NO ], @[ @"dateAdded", @"Date Added", @169, @NO ], @[ @"size", @"Size", @97, @YES ], @[ @"kind", @"Kind", @121, @YES ], @[ @"label", @"Tags", @120, @NO ] ]) [d addObject: [@{ @"id": c[0], @"title": c[1], @"w": c[2], @"vis": c[3] } mutableCopy]]; _colDefs = d;
}
- (NSArray *)_cols
{
	CGFloat w = [self bounds].size.width - 20, fixed = 0; for (NSDictionary *c in _colDefs) if ([c[@"vis"] boolValue] && ![c[@"id"] isEqual: @"name"]) fixed += [c[@"w"] doubleValue]; CGFloat nameW = MAX(208, w - fixed), x = 10;       /* Mac: 10 in on each side, the name column takes the rest (at least 208), Date Modified 169, Size 97, Kind 121 */ NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *c in _colDefs) { if (![c[@"vis"] boolValue]) continue; CGFloat cw = [c[@"id"] isEqual: @"name"] ? nameW : [c[@"w"] doubleValue]; [out addObject: @[ c[@"id"], c[@"title"], @(x), @(cw) ]]; x += cw; }
	return out;
}
static NSString *SortFieldFor(NSString *col) { NSDictionary *m = @{ @"name": @"name", @"dateModified": @"date", @"dateCreated": @"cre", @"dateAdded": @"cre", @"dateLastOpened": @"acc", @"size": @"size", @"kind": @"kind", @"label": @"tagsort" }; return m[col] ?: @"name"; }
- (void)loadOptions
{
	NSDictionary *ls = _folder ? [[TDSStore storeForFolder: _folder] plistForName: @"." sid: @"lsvp"] : nil; double t = [ls[@"textSize"] doubleValue]; _listText = t >= 8 ? t : 13; _bigIcons = [ls[@"iconSize"] doubleValue] > 16;
	_rowH = _bigIcons ? 36 : _listText <= 13 ? 20 : _listText <= 14 ? 21 : _listText <= 15 ? 22 : 23;
}
- (void)_loadColumns
{
	[self loadOptions]; if (!_folder) return; NSDictionary *ls = [[TDSStore storeForFolder: _folder] plistForName: @"." sid: @"lsvp"]; NSDictionary *cs = ls[@"columns"]; if (!cs) return; NSArray *order = [_colDefs sortedArrayUsingComparator: ^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [cs[a[@"id"]][@"index"] ?: @99 compare: cs[b[@"id"]][@"index"] ?: @99]; }];
	for (NSMutableDictionary *c in _colDefs) { NSDictionary *d = cs[c[@"id"]]; if (!d) continue; if (d[@"width"] && ![c[@"id"] isEqual: @"name"]) c[@"w"] = d[@"width"]; if (d[@"visible"]) c[@"vis"] = d[@"visible"]; } (void)order;
	NSString *sc = ls[@"sortColumn"]; if ([sc length] && cs[sc]) { _colKey = sc; _sortKey = SortFieldFor(sc); _asc = [cs[sc][@"ascending"] boolValue] || !cs[sc][@"ascending"]; }
}
- (void)_saveColumns
{
	if (!_folder) return; TDSStore *ds = [TDSStore storeForFolder: _folder]; NSMutableDictionary *ls = [ds plistForName: @"." sid: @"lsvp"] ?: [@{ @"calculateAllSizes": @NO, @"iconSize": @16.0, @"showIconPreview": @YES, @"textSize": @13.0, @"useRelativeDates": @YES, @"viewOptionsVersion": @1, @"scrollPositionX": @0.0, @"scrollPositionY": @0.0 } mutableCopy];
	NSMutableDictionary *cs = [NSMutableDictionary dictionary]; int ix = 0; for (NSDictionary *c in _colDefs) { cs[c[@"id"]] = @{ @"width": c[@"w"], @"visible": c[@"vis"], @"index": @(ix++), @"identifier": c[@"id"], @"ascending": @([c[@"id"] isEqual: _colKey ?: @"name"] ? _asc : YES) }; }
	ls[@"columns"] = cs; ls[@"sortColumn"] = _colKey ?: @"name"; [ds setPlist: ls forName: @"." sid: @"lsvp"]; if (![ds valueForName: @"." sid: @"vSrn"]) [ds setValue: @1 type: @"long" forName: @"." sid: @"vSrn"]; [ds write];
}
- (void)drawContent:(NSRect)v
{
	BOOL key = KeyWin(self); NSArray *cols = [self _cols]; CGFloat w = [self bounds].size.width;
	for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) {
		CGFloat y = 5 + i * _rowH; if (y + _rowH < v.origin.y || y > NSMaxY(v)) continue; NSDictionary *it = _items[i]; BOOL sel = [_sel containsIndex: i]; CGFloat cy = y + _rowH / 2;
		if ([it[@"header"] boolValue]) { NSDictionary *hf = Font(13, YES, TF_TEXT); TextAt(it[@"name"], 16, cy, hf); NSString *cn = [NSString stringWithFormat: @"%@", it[@"count"]]; TextAt(cn, 16 + [it[@"name"] sizeWithAttributes: hf].width + 8, cy, Font(12, NO, TF_DIM)); [TF_LINE setFill]; NSRectFill(NSMakeRect(16, y + _rowH - 1, w - 32 - 10, 1)); continue; }
		if (i == _dropRow) { FillRound(NSMakeRect(11, y, w - 23, _rowH), 6, TFRGBA(0, 98, 225, 0.45)); }
		if (sel) FillRound(NSMakeRect(11, y, w - 23, _rowH), 6, key ? DesktopPillColor() : (TFDark() ? TFRGB(70, 70, 70) : TFRGB(200, 200, 204))); else if (i % 2) FillRound(NSMakeRect(11, y, w - 23, _rowH), 6, TFDark() ? TFRGBA(255, 255, 255, 0.04) : TFRGBA(0, 0, 0, 0.04));
		NSColor *tc = sel ? TFRGB(255, 255, 255) : TF_TEXT, *dc = sel ? TFRGBA(255, 255, 255, 0.8) : TF_DIM; CGFloat ind = [it[@"depth"] intValue] * 18; if ([it[@"dir"] boolValue]) TFSymbolW([_exp containsObject: it[@"path"]] ? @"chevron.down" : @"chevron.right", NSMakeRect(8 + ind, y, 14, _rowH), 9, 6, sel ? TFRGB(255, 255, 255) : TF_DIM); { NSImage *tm = Thumb(it[@"path"]); if (tm) { NSSize z = [tm size]; CGFloat ip = _bigIcons ? 32 : 16, k = MIN(ip / z.width, ip / z.height); [tm drawInRect: NSMakeRect(26 + ip / 2 + ind - z.width * k / 2, cy - z.height * k / 2, z.width * k, z.height * k) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else TFDrawIcon(it[@"path"], NSMakeRect(26 + ind, cy - (_bigIcons ? 16 : 8), _bigIcons ? 32 : 16, _bigIcons ? 32 : 16)); }
		for (NSArray *c in cols) {
			NSString *k = c[0], *s; CGFloat x = [c[2] doubleValue] + ([k isEqual: @"name"] ? (_bigIcons ? 54 : 36) + ind : 6), cw = [c[3] doubleValue] - ([k isEqual: @"name"] ? (_bigIcons ? 62 : 44) + ind : 12); NSDictionary *at = Font(_listText, NO, [k isEqual: @"name"] ? tc : dc);
			if ([k isEqual: @"name"]) s = it[@"name"]; else if ([k isEqual: @"dateModified"]) s = TFDateString(it[@"date"]); else if ([k isEqual: @"dateCreated"] || [k isEqual: @"dateAdded"]) s = TFDateString(it[@"cre"]); else if ([k isEqual: @"dateLastOpened"]) s = TFDateString(it[@"acc"]); else if ([k isEqual: @"size"]) s = [it[@"size"] longLongValue] < 0 ? @"--" : TFSizeString([it[@"size"] unsignedLongLongValue]); else if ([k isEqual: @"label"]) s = [it[@"tags"] componentsJoinedByString: @", "]; else s = it[@"kind"];
			s = Truncated(s, at, cw); if ([k isEqual: @"size"]) x += cw - [s sizeWithAttributes: at].width; TextAt(s, x, cy, at);
			if ([k isEqual: @"name"] && [it[@"tags"] count]) { Class sp = NSClassFromString(@"WsdFinderSupport"); double w = [sp tagDotsWidth: it[@"tags"]]; [sp drawTagDots: it[@"tags"] rightEdge: x + [s sizeWithAttributes: at].width + 8 + w centerY: cy]; }
		}
	}
}
- (void)drawRect:(NSRect)r
{
	[super drawRect: r]; NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(NSMakeRect(0, 0, b.size.width, kHead)); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, kHead - 1, b.size.width, 1));
	for (NSArray *c in [self _cols]) {
		NSString *k = c[0]; NSDictionary *at = Font(12, YES, TF_DIM); CGFloat x = [c[2] doubleValue] + ([k isEqual: @"name"] ? 32 : 8); TextAt(c[1], x, kHead / 2, at);
		if ([k isEqual: _colKey ?: @"name"]) TFSymbol(_asc ? @"chevron.up" : @"chevron.down", NSMakeRect(x + [c[1] sizeWithAttributes: at].width + 6, 0, 10, kHead), 9, TF_DIM);
		if (![k isEqual: [[[self _cols] firstObject] firstObject]]) { [TF_LINE setFill]; NSRectFill(NSMakeRect([c[2] doubleValue], 6, 1, kHead - 12)); }
	}
	NSRect th = [self thumbRect]; if (!NSIsEmptyRect(th)) FillRound(th, 5, TFDark() ? TFRGB(159, 159, 159) : TFRGBA(0, 0, 0, 0.35));
}
- (NSInteger)_row:(NSPoint)p { NSInteger i = (NSInteger)floor((p.y - 4) / _rowH); return i >= 0 && i < (NSInteger)[_items count] ? i : -1; }
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (NSArray *)selectedPaths { NSMutableArray *a = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { if (![self->_items[i][@"header"] boolValue]) [a addObject: self->_items[i][@"path"]]; }]; return a; }
- (void)setGroup:(NSString *)g { _group = [g length] ? [g copy] : nil; [self _rebuild]; off = 0; [self setNeedsDisplay: YES]; [self _notify]; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	if (p.y < kHead) {
		NSArray *cols = [self _cols];
		for (NSUInteger q = 0; q + 1 < [cols count] + 1; q++) { if (q >= [cols count]) break; NSArray *c = cols[q]; CGFloat right = [c[2] doubleValue] + [c[3] doubleValue]; if (fabs(p.x - right) < 5 && ![c[0] isEqual: @"name"] ? YES : (fabs(p.x - right) < 5 && q + 1 < [cols count])) {   /* the edge of a column: drag it */
			NSString *rid = [c[0] isEqual: @"name"] ? cols[q + 1][0] : c[0]; NSMutableDictionary *def = nil; for (NSMutableDictionary *d in _colDefs) if ([d[@"id"] isEqual: rid]) def = d; if (!def) break; BOOL left = [c[0] isEqual: @"name"]; CGFloat w0 = [def[@"w"] doubleValue]; NSEvent *ev = e; CGFloat x0 = p.x;
			while ([ev type] != NSLeftMouseUp) { ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES]; CGFloat dx = [self convertPoint: [ev locationInWindow] fromView: nil].x - x0; def[@"w"] = @(MAX(50, w0 + (left ? -dx : dx))); [self setNeedsDisplay: YES]; }
			[self _saveColumns]; return; } }
		for (NSArray *c in cols) if (p.x >= [c[2] doubleValue] && p.x < [c[2] doubleValue] + [c[3] doubleValue]) { if ([_colKey ?: @"name" isEqual: c[0]]) _asc = !_asc; else { _colKey = c[0]; _sortKey = SortFieldFor(c[0]); _asc = YES; } [self _sort]; [self setNeedsDisplay: YES]; [self _saveColumns]; }
		return; }
	[super mouseDown: e];
}
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e
{
	NSInteger i = [self _row: p]; NSUInteger fl = [e modifierFlags]; if (i < 0) { [_sel removeAllIndexes]; [self setNeedsDisplay: YES]; [self _notify]; return; }
	if ([_items[i][@"header"] boolValue]) { [_sel removeAllIndexes]; for (NSInteger k = i + 1; k < (NSInteger)[_items count] && ![_items[k][@"header"] boolValue]; k++) [_sel addIndex: k]; _anchor = i + 1; [self setNeedsDisplay: YES]; [self _notify]; return; }
	if ([_items[i][@"dir"] boolValue] && p.x >= 6 + [_items[i][@"depth"] intValue] * 18 && p.x < 24 + [_items[i][@"depth"] intValue] * 18) { [self _toggleRow: i]; return; }
	if (fl & NSShiftKeyMask && _anchor >= 0) { [_sel removeAllIndexes]; [_sel addIndexesInRange: NSMakeRange(MIN(_anchor, i), labs(i - _anchor) + 1)]; }
	else if (fl & NSCommandKeyMask) { if ([_sel containsIndex: i]) [_sel removeIndex: i]; else [_sel addIndex: i]; _anchor = i; }
	else { if (![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; } _anchor = i; }
	[self setNeedsDisplay: YES]; [self _notify]; if ([e clickCount] == 2) { [delegate iconViewOpenItem: _items[i][@"path"]]; return; } [self _dragFrom: p event: e];
}
- (void)_toggleCol:(NSMenuItem *)it { for (NSMutableDictionary *d in _colDefs) if ([d[@"id"] isEqual: [it representedObject]]) d[@"vis"] = @(![d[@"vis"] boolValue]); [self setNeedsDisplay: YES]; [self _saveColumns]; }
- (void)_dragFrom:(NSPoint)start event:(NSEvent *)e                                          /* rows dragged onto a folder row, the sidebar or another window */
{
	NSEvent *ev = e; BOOL moved = NO; NSArray *paths = [self selectedPaths]; if (![paths count]) return; _dropRow = -1;
	while ([ev type] != NSLeftMouseUp) { ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES]; NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; q.y = q.y - topInset + off; if (!moved && hypot(q.x - start.x, q.y - start.y) < 4) continue; moved = YES;
		NSInteger r = [self _row: q]; NSInteger nr = (r >= 0 && [_items[r][@"dir"] boolValue] && ![_sel containsIndex: r]) ? r : -1; if (nr != _dropRow) { _dropRow = nr; [self setNeedsDisplay: YES]; } }
	NSInteger target = _dropRow; _dropRow = -1; [self setNeedsDisplay: YES]; if (!moved) return; NSPoint wp = [ev locationInWindow]; BOOL copy = ([ev modifierFlags] & NSAlternateKeyMask) != 0; BOOL inside = NSPointInRect([self convertPoint: wp fromView: nil], [self bounds]);
	if ((target >= 0 || !inside) && [delegate respondsToSelector: @selector(iconViewDropPaths:intoFolder:atWindowPoint:copy:)]) [(id)delegate iconViewDropPaths: paths intoFolder: target >= 0 ? _items[target][@"path"] : nil atWindowPoint: wp copy: copy];
}
- (NSMenu *)menuForEvent:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; if (p.y < kHead) { NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (NSDictionary *d in _colDefs) { if ([d[@"id"] isEqual: @"name"]) continue; NSMenuItem *it = [m addItemWithTitle: d[@"title"] action: @selector(_toggleCol:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: d[@"id"]]; [it setState: [d[@"vis"] boolValue] ? NSOnState : NSOffState]; } TFPopupMenu(self, p, m); return nil; } NSInteger i = [self _row: NSMakePoint(p.x, p.y - topInset + off)]; if (i >= 0 && ![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; [self setNeedsDisplay: YES]; [self _notify]; } if (i < 0 && [delegate respondsToSelector: @selector(backgroundContextMenu)]) { NSMenu *bg = [(id)delegate backgroundContextMenu]; if (bg) { TFPopupMenu(self, p, bg); return nil; } } if ([delegate respondsToSelector: @selector(prepareContextMenu:)]) [(id)delegate prepareContextMenu: [self menu]]; TFPopupMenu(self, p, [self menu]); return nil; }
- (BOOL)beginRename:(NSString *)path
{
	for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) if ([_items[i][@"path"] isEqual: path]) { [self reveal: NSMakeRect(0, 5 + i * _rowH, 10, _rowH)]; CGFloat ind = [_items[i][@"depth"] intValue] * 18; NSRect lr = NSMakeRect(46 + ind, 5 + i * _rowH - off + topInset + 2, 280, _rowH - 4); __weak TListView *me = self; NSString *old = path; TFBeginRename(self, lr, [path lastPathComponent], NO, nil, ^(NSString *nn) { TListView *s = me; if (s && [s->delegate respondsToSelector: @selector(iconViewRename:to:)]) [(id)s->delegate iconViewRename: old to: nn]; }); return YES; }
	return NO;
}
- (void)selectAll:(id)s { [_sel addIndexesInRange: NSMakeRange(0, [_items count])]; [self setNeedsDisplay: YES]; [self _notify]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0]; NSInteger cur = [_sel count] ? (NSInteger)[_sel lastIndex] : -1, n = (NSInteger)[_items count], t = cur;
	if (c == ' ') { [NSApp sendAction: @selector(cmdQuickLook:) to: nil from: self]; return; } else if (c == NSUpArrowFunctionKey) t = cur < 0 ? 0 : MAX(0, cur - 1); else if (c == NSDownArrowFunctionKey) t = cur < 0 ? 0 : MIN(n - 1, cur + 1); else if (c == NSRightArrowFunctionKey && cur >= 0 && [_items[cur][@"dir"] boolValue] && ![_exp containsObject: _items[cur][@"path"]]) { [self _toggleRow: cur]; return; } else if (c == NSLeftArrowFunctionKey && cur >= 0 && [_exp containsObject: _items[cur][@"path"]]) { [self _toggleRow: cur]; return; } else if (c == '\r' && cur >= 0) { [NSApp sendAction: @selector(cmdRename:) to: nil from: self]; return; } else { [super keyDown: e]; return; }
	if (n) { NSInteger dirn = (c == NSUpArrowFunctionKey) ? -1 : 1; while (t >= 0 && t < n && [_items[t][@"header"] boolValue]) t += dirn; if (t < 0 || t >= n) { t = cur >= 0 && cur < n ? cur : 0; while (t < n && [_items[t][@"header"] boolValue]) t++; if (t >= n) return; } [_sel removeAllIndexes]; [_sel addIndex: t]; _anchor = t; [self reveal: NSMakeRect(0, 4 + t * _rowH, 10, _rowH)]; [self setNeedsDisplay: YES]; [self _notify]; }
}
@end

static NSString *ShortDate(NSDate *d) { if (!d) return @""; NSCalendar *cal = [NSCalendar currentCalendar]; NSDateFormatter *tf = [[NSDateFormatter alloc] init]; [tf setDateFormat: @"HH:mm"]; if ([cal isDateInToday: d]) return [@"Today, " stringByAppendingString: [tf stringFromDate: d]]; if ([cal isDateInYesterday: d]) return [@"Yesterday, " stringByAppendingString: [tf stringFromDate: d]]; NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"d MMM yyyy, HH:mm"]; return [df stringFromDate: d]; }
/* ---------- the gallery view ---------- */
static const CGFloat kStripH = 80, kGThumb = 52, kGCell = 59, kPane = 260;
@implementation TGalleryView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstResponder { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)setFolder:(NSString *)folder { NSMutableArray *ps = [NSMutableArray array]; for (NSString *n in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: folder error: NULL] sortedArrayUsingSelector: @selector(tfNameCompare:)]) [ps addObject: [folder stringByAppendingPathComponent: n]]; [self setPaths: ps]; }
- (void)setPaths:(NSArray *)paths { _paths = [NSMutableArray array]; for (NSString *p in paths) { NSString *n = [p lastPathComponent]; if (![n hasPrefix: @"."] && (![filter length] || [n rangeOfString: filter options: NSCaseInsensitiveSearch].location != NSNotFound)) [_paths addObject: p]; } _sel = [_paths count] ? 0 : -1; _hoff = 0; [self setNeedsDisplay: YES]; [self _notify]; }
- (NSArray *)selectedPaths { return _sel >= 0 && _sel < (NSInteger)[_paths count] ? @[ _paths[_sel] ] : @[]; }
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (NSRect)_cell:(NSInteger)i { return NSMakeRect(14 + i * kGCell - _hoff, [self bounds].size.height - kStripH + 12, kGThumb + 4, kStripH - 24); }
- (void)_reveal { CGFloat w = [self bounds].size.width - kPane, x = 14 + _sel * kGCell; if (x < _hoff) _hoff = x - 14; else if (x + kGCell > _hoff + w) _hoff = x + kGCell - w + 14; _hoff = MAX(0, _hoff); }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(b); BOOL key = KeyWin(self); CGFloat W = b.size.width - kPane, top = b.size.height - kStripH;
	if (_sel >= 0) {
		NSString *p = _paths[_sel]; NSImage *th = Thumb(p); if (th) { if (![_bigPath isEqual: p]) { _bigPath = p; _big = [[NSImage alloc] initWithContentsOfFile: p]; } if (_big && [_big size].width > 0) th = _big; } NSRect pr = NSMakeRect(24, 22, W - 48, top - 40); NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && !TFIsPackage(p);
		if (th) { NSSize z = [th size]; CGFloat k = MIN(pr.size.width / z.width, pr.size.height / z.height); NSRect tr = NSMakeRect(NSMidX(pr) - z.width * k / 2, NSMidY(pr) - z.height * k / 2, z.width * k, z.height * k); NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; [[NSBezierPath bezierPathWithRoundedRect: tr xRadius: 8 yRadius: 8] addClip]; [th drawInRect: tr fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [g restoreGraphicsState]; }
		else { CGFloat s = MIN(MIN(pr.size.width, pr.size.height), 256); TFDrawIcon(p, NSMakeRect(NSMidX(pr) - s / 2, NSMidY(pr) - s / 2, s, s)); }
		/* the inspector */
		[TF_SIDEBAR setFill]; NSRectFill(NSMakeRect(W, 0, kPane, top)); CGFloat x = W + 14, y = 24; { NSImage *ti = Thumb(p); if (ti) { NSSize z = [ti size]; CGFloat k = MIN(42 / z.width, 42 / z.height); [ti drawInRect: NSMakeRect(x + 21 - z.width * k / 2, y + 21 - z.height * k / 2, z.width * k, z.height * k) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else TFDrawIcon(p, NSMakeRect(x, y, 42, 42)); } NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
		[[p lastPathComponent] drawInRect: NSMakeRect(x + 54, y + 2, kPane - 80, 20) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 15], NSForegroundColorAttributeName: TF_TEXT, NSParagraphStyleAttributeName: ps }];
		[[NSString stringWithFormat: @"%@ - %@", TFKindString(p, dir), dir ? @"--" : TFSizeString([at[NSFileSize] unsignedLongLongValue])] drawAtPoint: NSMakePoint(x + 54, y + 24) withAttributes: Font(13, NO, TF_DIM)]; y += 72;
		[@"Information" drawAtPoint: NSMakePoint(x, y) withAttributes: Font(14, YES, TF_TEXT)]; NSString *sm = _more ? @"Show Less" : @"Show More"; NSSize ss = [sm sizeWithAttributes: Font(13, NO, TF_ACCENT)]; [sm drawAtPoint: NSMakePoint(W + kPane - 14 - ss.width, y + 1) withAttributes: Font(13, NO, TF_ACCENT)]; _moreRect = NSMakeRect(W + kPane - 24 - ss.width, y - 2, ss.width + 20, 22); y += 28;
		NSMutableArray *rows = [NSMutableArray arrayWithObjects: @[ @"Created", ShortDate(at[NSFileCreationDate]) ], @[ @"Modified", ShortDate(at[NSFileModificationDate]) ], @[ @"Last opened", ShortDate(at[@"NSFileAccessDate"] ?: at[NSFileModificationDate]) ], nil];
		if (_more) { NSImage *im = [[NSImage alloc] initWithContentsOfFile: p]; if (im && [im size].width > 0) [rows insertObject: @[ @"Dimensions", [NSString stringWithFormat: @"%d × %d", (int)[im size].width, (int)[im size].height] ] atIndex: 0]; [rows addObject: @[ @"Where", [p stringByDeletingLastPathComponent] ]]; }
		for (NSArray *row in rows) { [row[0] drawAtPoint: NSMakePoint(x, y) withAttributes: Font(12, NO, TF_DIM)]; NSSize vs = [row[1] sizeWithAttributes: Font(12, YES, TF_TEXT)]; [row[1] drawInRect: NSMakeRect(MAX(x + 80, W + kPane - 14 - vs.width), y, MIN(vs.width, kPane - 100), 16) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 12], NSForegroundColorAttributeName: TF_TEXT, NSParagraphStyleAttributeName: ps }]; [TF_LINE setFill]; NSRectFill(NSMakeRect(x, y + 19, kPane - 28, 1)); y += 24; }
		y += 14; [@"Tags" drawAtPoint: NSMakePoint(x, y) withAttributes: Font(14, YES, TF_TEXT)]; y += 26; NSArray *tags = TFTagsOf(p); NSRect tb = NSMakeRect(x, y, kPane - 28, 40); FillRound(tb, 4, TFDark() ? TFRGBA(255, 255, 255, 0.05) : TFRGBA(0, 0, 0, 0.04)); if ([tags count]) [[tags componentsJoinedByString: @", "] drawAtPoint: NSMakePoint(x + 4, y + 4) withAttributes: Font(12, NO, TF_TEXT)]; else [@"Add Tags…" drawAtPoint: NSMakePoint(x + 4, y + 4) withAttributes: Font(12, NO, TF_DIM)];
		/* the quick actions at the bottom of the inspector */
		NSArray *qa = @[ @[ @"Rotate Left", @"rotate.left" ], @[ @"Markup", @"pencil.tip.crop.circle" ], @[ @"More…", @"ellipsis.circle" ] ]; CGFloat qw = (kPane - 28) / 3; for (NSUInteger k = 0; k < 3; k++) { CGFloat qx = x + k * qw; TFSymbol(qa[k][1], NSMakeRect(qx, top - 56, qw, 28), 18, TF_DIM); NSSize z = [qa[k][0] sizeWithAttributes: Font(11, NO, TF_DIM)]; [qa[k][0] drawAtPoint: NSMakePoint(qx + qw / 2 - z.width / 2, top - 24) withAttributes: Font(11, NO, TF_DIM)]; }
	}
	[TF_CONTENT setFill]; NSRectFill(NSMakeRect(0, top, W, kStripH)); NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; NSRectClip(NSMakeRect(0, top, W, kStripH));
	for (NSInteger i = 0; i < (NSInteger)[_paths count]; i++) {
		NSRect c = [self _cell: i]; if (NSMaxX(c) < 0 || c.origin.x > W) continue; BOOL sel = i == _sel; NSRect ir = NSInsetRect(c, 2, 2);
		if (sel) FillRound(NSInsetRect(c, -1, -2), 7, key ? TFRGBA(255, 255, 255, 0.16) : TFRGB(60, 60, 60));
		NSImage *th = Thumb(_paths[i]); if (th) { NSSize z = [th size]; CGFloat k = MIN(kGThumb / z.width, kGThumb / z.height); [th drawInRect: NSMakeRect(NSMidX(ir) - z.width * k / 2, NSMidY(ir) - z.height * k / 2, z.width * k, z.height * k) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else TFDrawIcon(_paths[i], NSMakeRect(NSMidX(ir) - 24, NSMidY(ir) - 24, 48, 48));
	}
	[g restoreGraphicsState];
}
- (void)mouseDown:(NSEvent *)e
{
	[[self window] makeFirstResponder: self]; NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	if (NSPointInRect(p, _moreRect)) { _more = !_more; [self setNeedsDisplay: YES]; return; }
	for (NSInteger i = 0; i < (NSInteger)[_paths count]; i++) if (NSPointInRect(p, [self _cell: i])) { _sel = i; [self setNeedsDisplay: YES]; [self _notify]; if ([e clickCount] == 2) [delegate iconViewOpenItem: _paths[i]]; return; }
}
- (void)scrollWheel:(NSEvent *)e { CGFloat d = fabs([e deltaX]) > fabs([e deltaY]) ? [e deltaX] : [e deltaY]; _hoff = MAX(0, MIN(_hoff - d * 24, MAX(0, 24 + [_paths count] * kGCell - ([self bounds].size.width - kPane)))); [self setNeedsDisplay: YES]; }
- (NSMenu *)menuForEvent:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSInteger i = 0; i < (NSInteger)[_paths count]; i++) if (NSPointInRect(p, [self _cell: i])) { _sel = i; [self setNeedsDisplay: YES]; [self _notify]; } if ([delegate respondsToSelector: @selector(prepareContextMenu:)]) [(id)delegate prepareContextMenu: [self menu]]; TFPopupMenu(self, p, [self menu]); return nil; }
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0]; NSInteger n = (NSInteger)[_paths count];
	if (c == ' ') { [NSApp sendAction: @selector(cmdQuickLook:) to: nil from: self]; return; } if (c == NSLeftArrowFunctionKey || c == NSUpArrowFunctionKey) _sel = MAX(0, _sel - 1); else if (c == NSRightArrowFunctionKey || c == NSDownArrowFunctionKey) _sel = MIN(n - 1, _sel + 1); else if (c == '\r' && _sel >= 0) { [delegate iconViewOpenItem: _paths[_sel]]; return; } else { [super keyDown: e]; return; }
	[self _reveal]; [self setNeedsDisplay: YES]; [self _notify];
}
- (void)selectAll:(id)s {}
@end

/* ---------- the column view ---------- */
static const CGFloat kColW = 247, kColRow = 22;
@implementation TColumnView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstResponder { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSMutableDictionary *)_load:(NSString *)dir
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *items = [NSMutableArray array];
	for (NSString *n in [[fm contentsOfDirectoryAtPath: dir error: NULL] sortedArrayUsingSelector: @selector(tfNameCompare:)]) {
		if ([n hasPrefix: @"."]) continue; NSString *p = [dir stringByAppendingPathComponent: n]; BOOL d = NO; [fm fileExistsAtPath: p isDirectory: &d]; if (d && TFIsPackage(p)) d = NO;
		[items addObject: @{ @"name": n, @"path": p, @"dir": @(d) }];
	}
	return [@{ @"dir": dir, @"items": items, @"sel": @(-1), @"off": @0.0 } mutableCopy];
}
- (void)setFolder:(NSString *)folder { _cols = [NSMutableArray arrayWithObject: [self _load: folder]]; _hoff = 0; [self setNeedsDisplay: YES]; [self _notify]; }
- (NSString *)_selPath { NSMutableDictionary *c = [_cols lastObject]; NSInteger s = [c[@"sel"] integerValue]; if (s < 0) { if ([_cols count] > 1) { NSMutableDictionary *p = _cols[[_cols count] - 2]; return p[@"items"][[p[@"sel"] integerValue]][@"path"]; } return nil; } return c[@"items"][s][@"path"]; }
- (NSArray *)selectedPaths { NSString *p = [self _selPath]; return p ? @[ p ] : @[]; }
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (CGFloat)_previewW { return kColW; }
- (CGFloat)_totalW { NSMutableDictionary *c = [_cols lastObject]; BOOL pre = [c[@"sel"] integerValue] >= 0 && ![c[@"items"][[c[@"sel"] integerValue]][@"dir"] boolValue]; return ([_cols count] + (pre ? 1 : 0)) * kColW; }
- (void)_fit { CGFloat w = [self bounds].size.width, t = [self _totalW]; _hoff = MAX(0, t - w); }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(b); BOOL key = KeyWin(self); NSDictionary *tx = Font(13, NO, TF_TEXT);
	for (NSUInteger ci = 0; ci < [_cols count]; ci++) {
		CGFloat x = ci * kColW - _hoff; if (x + kColW < 0 || x > b.size.width) continue; NSMutableDictionary *c = _cols[ci]; NSArray *items = c[@"items"]; CGFloat off = [c[@"off"] doubleValue]; NSInteger sel = [c[@"sel"] integerValue];
		NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; NSRectClip(NSMakeRect(x, 0, kColW, b.size.height));
		for (NSInteger i = 0; i < (NSInteger)[items count]; i++) {
			CGFloat y = 6 + i * kColRow - off; if (y + kColRow < 0 || y > b.size.height) continue; NSDictionary *it = items[i]; BOOL isSel = i == sel, active = ci == [_cols count] - 1 || ![it[@"dir"] boolValue];
			if (isSel) FillRound(NSMakeRect(x + 10, y, kColW - 33, kColRow), 7, key && ci + 1 >= [_cols count] ? TF_ACCENT : (TFDark() ? TFRGB(70, 70, 70) : TFRGB(200, 200, 204))); (void)active;
			{ NSImage *tm = Thumb(it[@"path"]); if (tm) { NSSize z = [tm size]; CGFloat k = MIN(16 / z.width, 16 / z.height); [tm drawInRect: NSMakeRect(x + 26 - z.width * k / 2, y + 11 - z.height * k / 2, z.width * k, z.height * k) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else TFDrawIcon(it[@"path"], NSMakeRect(x + 18, y + 3, 16, 16)); }
			NSDictionary *at = isSel ? Font(13, NO, TFRGB(255, 255, 255)) : tx; TextAt(Truncated(it[@"name"], at, kColW - 92), x + 42, y + kColRow / 2, at);
			if ([it[@"dir"] boolValue]) TFSymbol(@"chevron.right", NSMakeRect(x + kColW - 34, y, 12, kColRow), 9, isSel ? TFRGB(255, 255, 255) : TF_DIM);
		}
		[g restoreGraphicsState]; [TF_LINE setFill]; NSRectFill(NSMakeRect(x + kColW - 1, 0, 1, b.size.height));
	}
	NSMutableDictionary *last = [_cols lastObject]; NSInteger ls = [last[@"sel"] integerValue];
	if (ls >= 0 && ![last[@"items"][ls][@"dir"] boolValue]) {                                                                                                    /* the preview of a file: its picture or icon, name, kind, size, dates and tags */
		NSString *p = last[@"items"][ls][@"path"]; CGFloat x = [_cols count] * kColW - _hoff + 16, w = kColW + 40; NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; NSImage *th = Thumb(p);
		NSRect pr = NSMakeRect(x, 20, w - 32, 150); if (th) { NSSize z = [th size]; CGFloat k = MIN(MIN(pr.size.width / z.width, pr.size.height / z.height), 2); NSRect tr = NSMakeRect(NSMidX(pr) - z.width * k / 2, NSMidY(pr) - z.height * k / 2, z.width * k, z.height * k); [th drawInRect: tr fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else TFDrawIcon(p, NSMakeRect(NSMidX(pr) - 64, 28, 128, 128));
		NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setAlignment: NSTextAlignmentCenter]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
		[[p lastPathComponent] drawInRect: NSMakeRect(x, 180, w - 32, 18) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 14], NSForegroundColorAttributeName: TF_TEXT, NSParagraphStyleAttributeName: ps }];
		[[NSString stringWithFormat: @"%@ - %@", TFKindString(p, NO), TFSizeString([at[NSFileSize] unsignedLongLongValue])] drawInRect: NSMakeRect(x, 200, w - 32, 16) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: TF_DIM, NSParagraphStyleAttributeName: ps }];
		CGFloat y = 236; [@"Information" drawAtPoint: NSMakePoint(x, y) withAttributes: Font(13, YES, TF_TEXT)]; y += 26;
		for (NSArray *row in @[ @[ @"Created", ShortDate(at[NSFileCreationDate]) ], @[ @"Modified", ShortDate(at[NSFileModificationDate]) ], @[ @"Last opened", ShortDate(at[@"NSFileAccessDate"] ?: at[NSFileModificationDate]) ] ]) { [row[0] drawAtPoint: NSMakePoint(x, y) withAttributes: Font(12, NO, TF_DIM)]; NSSize vs = [row[1] sizeWithAttributes: Font(12, YES, TF_TEXT)]; [row[1] drawAtPoint: NSMakePoint(x + w - 32 - vs.width, y) withAttributes: Font(12, YES, TF_TEXT)]; [TF_LINE setFill]; NSRectFill(NSMakeRect(x, y + 19, w - 32, 1)); y += 24; }
		y += 12; [@"Tags" drawAtPoint: NSMakePoint(x, y) withAttributes: Font(13, YES, TF_TEXT)]; y += 24; NSArray *tg = TFTagsOf(p); FillRound(NSMakeRect(x, y, w - 32, 34), 4, TFDark() ? TFRGBA(255, 255, 255, 0.05) : TFRGBA(0, 0, 0, 0.04)); [[tg count] ? [tg componentsJoinedByString: @", "] : @"Add Tags…" drawAtPoint: NSMakePoint(x + 4, y + 3) withAttributes: Font(12, NO, [tg count] ? TF_TEXT : TF_DIM)];
	}
}
- (void)_select:(NSInteger)row inColumn:(NSUInteger)ci
{
	NSMutableDictionary *c = _cols[ci]; c[@"sel"] = @(row); while ([_cols count] > ci + 1) [_cols removeLastObject];
	if (row >= 0) { NSDictionary *it = c[@"items"][row]; if ([it[@"dir"] boolValue]) [_cols addObject: [self _load: it[@"path"]]]; }
	[self _fit]; [self setNeedsDisplay: YES]; [self _notify];
}
- (void)mouseDown:(NSEvent *)e
{
	[[self window] makeFirstResponder: self]; NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSUInteger ci = (NSUInteger)floor((p.x + _hoff) / kColW); if (ci >= [_cols count]) return;
	NSMutableDictionary *c = _cols[ci]; NSInteger row = (NSInteger)floor((p.y - 6 + [c[@"off"] doubleValue]) / kColRow); NSArray *items = c[@"items"]; if (row < 0 || row >= (NSInteger)[items count]) { [self _select: -1 inColumn: ci]; return; }
	[self _select: row inColumn: ci]; if ([e clickCount] == 2) [delegate iconViewOpenItem: items[row][@"path"]];
}
- (void)scrollWheel:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSUInteger ci = (NSUInteger)floor((p.x + _hoff) / kColW);
	if (fabs([e deltaX]) > fabs([e deltaY])) { _hoff = MAX(0, MIN(_hoff - [e deltaX] * 24, MAX(0, [self _totalW] - [self bounds].size.width))); [self setNeedsDisplay: YES]; return; }
	if (ci >= [_cols count]) return; NSMutableDictionary *c = _cols[ci]; CGFloat mx = MAX(0, 12 + [c[@"items"] count] * kColRow - [self bounds].size.height); c[@"off"] = @(MAX(0, MIN([c[@"off"] doubleValue] - [e deltaY] * 24, mx))); [self setNeedsDisplay: YES];
}
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0];
	NSUInteger ci = [_cols count] - 1; NSMutableDictionary *col = _cols[ci]; if ([col[@"sel"] integerValue] < 0 && ci > 0) { ci--; col = _cols[ci]; } NSInteger sel = [col[@"sel"] integerValue], n = (NSInteger)[col[@"items"] count];
	if (c == ' ') { [NSApp sendAction: @selector(cmdQuickLook:) to: nil from: self]; return; } if (c == NSDownArrowFunctionKey) [self _select: MIN(n - 1, sel + 1) inColumn: ci]; else if (c == NSUpArrowFunctionKey) [self _select: MAX(0, sel < 0 ? 0 : sel - 1) inColumn: ci];
	else if (c == NSLeftArrowFunctionKey && ci > 0) { [self _select: -1 inColumn: ci]; [_cols removeObjectAtIndex: ci]; [self _fit]; [self setNeedsDisplay: YES]; [self _notify]; }
	else if (c == NSRightArrowFunctionKey && sel >= 0 && [col[@"items"][sel][@"dir"] boolValue] && [_cols count] > ci + 1) { NSMutableDictionary *nx = _cols[ci + 1]; if ([nx[@"items"] count]) [self _select: 0 inColumn: ci + 1]; }
	else if (c == '\r' && sel >= 0) [delegate iconViewOpenItem: col[@"items"][sel][@"path"]]; else { [super keyDown: e]; return; }
	CGFloat vis = [self bounds].size.height; NSMutableDictionary *cc = _cols[MIN(ci, [_cols count] - 1)]; NSInteger s2 = [cc[@"sel"] integerValue]; if (s2 >= 0) { CGFloat y = 6 + s2 * kColRow, off = [cc[@"off"] doubleValue]; if (y < off) cc[@"off"] = @(y - 6); else if (y + kColRow > off + vis) cc[@"off"] = @(y + kColRow - vis + 6); }
}
@end

/* ---------- the sidebar ---------- */
@implementation TSidebarView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _sig = [self _volSig]; [self _build]; [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(_prefs:) name: @"TFPrefsChanged" object: nil]; [NSTimer scheduledTimerWithTimeInterval: 2 target: self selector: @selector(_poll:) userInfo: nil repeats: YES]; } return self; }
- (void)_prefs:(NSNotification *)n { [self _build]; [self setNeedsDisplay: YES]; }
- (NSString *)_volSig { NSMutableString *s = [NSMutableString string]; for (NSDictionary *v in TFVolumes()) [s appendFormat: @"%@;", v[@"path"]]; return s; }
- (void)_poll:(NSTimer *)t { NSString *sig = [self _volSig]; if (![sig isEqual: _sig]) { _sig = sig; [self _build]; [self setNeedsDisplay: YES]; } }
- (void)_build
{
	{
		NSString *home = NSHomeDirectory(); NSMutableArray *r = [NSMutableArray array];
		void (^item)(NSString *, NSString *, NSString *) = ^(NSString *t, NSString *sym, NSString *p) { NSDictionary *keys = @{ @"Recents": @"SidebarShowRecents", @"Shared": @"SidebarShowShared", @"Applications": @"SidebarShowApplications", @"Desktop": @"SidebarShowDesktop", @"Documents": @"SidebarShowDocuments", @"Downloads": @"SidebarShowDownloads", @"iCloud Drive": @"SidebarShowICloud", @"Macintosh HD": @"SidebarShowHardDisks", @"AirDrop": @"SidebarShowAirDrop", @"Trash": @"SidebarShowTrash" }; NSString *k = keys[t]; if (!k && [p isEqual: NSHomeDirectory()]) k = @"SidebarShowHome"; if (k && !TFPrefBool(k, YES)) return; [r addObject: @{ @"k": @"item", @"t": t, @"s": sym, @"p": p ?: @"" }]; };
		void (^head)(NSString *) = ^(NSString *t) { [r addObject: @{ @"k": @"head", @"t": t }]; };
		item(@"Recents", @"clock", @"recents://"); item(@"Shared", @"person.2", @"shared://");
		head(@"Favorites"); item(@"Applications", @"a.square", @"/Applications"); item(@"Desktop", @"menubar.dock.rectangle", [home stringByAppendingPathComponent: @"Desktop"]); item(@"Documents", @"doc", [home stringByAppendingPathComponent: @"Documents"]); item(@"Downloads", @"arrow.down.circle", [home stringByAppendingPathComponent: @"Downloads"]); for (NSString *fp in TFPref(@"SidebarFavorites", @[])) if ([[NSFileManager defaultManager] fileExistsAtPath: fp]) [r addObject: @{ @"k": @"item", @"t": TFDisplayName(fp), @"s": @"folder", @"p": fp, @"custom": @YES }];
		head(@"Locations"); item(@"iCloud Drive", @"icloud", [home stringByAppendingPathComponent: @"Library/Mobile Documents/com~apple~CloudDocs"]); item(NSUserName(), @"house", home); item(@"Macintosh HD", @"internaldrive", @"/"); for (NSDictionary *v in TFVolumes()) if (![v[@"path"] isEqual: @"/"]) [r addObject: @{ @"k": @"item", @"t": v[@"name"], @"s": [v[@"kind"] isEqual: @"optical"] ? @"opticaldisc" : [v[@"kind"] isEqual: @"server"] ? @"server.rack" : @"externaldrive", @"p": v[@"path"], @"eject": @YES }]; item(@"AirDrop", @"airdrop", @"airdrop://"); item(@"Trash", @"trash", [home stringByAppendingPathComponent: @".Trash"]);
		head(@"Tags"); for (NSString *t in @[ @"Red", @"Orange", @"Yellow", @"Green", @"Blue", @"Purple", @"Gray" ]) if (TFPrefBool([@"SidebarTag" stringByAppendingString: t], YES)) [r addObject: @{ @"k": @"tag", @"t": t, @"p": [@"tag://" stringByAppendingString: t] }];
		item(@"All Tags…", @"", @"tags://"); _rows = r;
	}
}
- (void)drawBackground { [TF_SIDEBAR setFill]; NSRectFill([self bounds]); }
- (BOOL)_collapsedRow:(NSInteger)i { NSArray *c = TFPref(@"SidebarCollapsed", @[]); for (NSInteger k = i; k >= 0; k--) if ([_rows[k][@"k"] isEqual: @"head"]) return [c containsObject: _rows[k][@"t"]] && k != i; return NO; }
- (NSRect)_rect:(NSInteger)i                                          /* rows 32 apart from y 52, a section header 19 high with 13 above it; the rows of a folded section take no room */
{
	CGFloat y = 52; for (NSInteger k = 0; k <= i; k++) { BOOL head = [_rows[k][@"k"] isEqual: @"head"]; if (head) { y += 13; if (k == i) return NSMakeRect(15, y, [self bounds].size.width - 30, 19); y += 19; } else { if ([self _collapsedRow: k]) { if (k == i) return NSZeroRect; continue; } if (k == i) return NSMakeRect(10, y, [self bounds].size.width - 37, 32); y += 32; } }
	return NSZeroRect;
}
- (CGFloat)contentHeight { for (NSInteger i = (NSInteger)[_rows count] - 1; i >= 0; i--) { NSRect r = [self _rect: i]; if (!NSIsEmptyRect(r)) return NSMaxY(r) + 12; } return 120; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 52; }
static NSColor *TagColorFor(NSString *n) { NSDictionary *c = @{ @"Red": TFRGB(255, 69, 58), @"Orange": TFRGB(255, 159, 10), @"Yellow": TFRGB(255, 214, 10), @"Green": TFRGB(48, 209, 88), @"Blue": TFRGB(10, 132, 255), @"Purple": TFRGB(191, 90, 242), @"Gray": TFRGB(152, 152, 157) }; return c[n]; }
- (void)drawContent:(NSRect)v
{
	BOOL key = KeyWin(self); NSColor *tint = key ? TF_BLUE : TFRGB(150, 150, 150);
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) {
		NSDictionary *it = _rows[i]; NSRect r = [self _rect: i]; if (NSIsEmptyRect(r) || NSMaxY(r) < v.origin.y || r.origin.y > NSMaxY(v)) continue; NSString *k = it[@"k"];
		if ([k isEqual: @"head"]) { TextAt(it[@"t"], r.origin.x, NSMidY(r), Font(11, YES, TFDark() ? TFRGBA(255, 255, 255, 0.40) : TFRGBA(0, 0, 0, 0.45))); if (_hoverHead == i) { NSString *lab = [TFPref(@"SidebarCollapsed", @[]) containsObject: it[@"t"]] ? @"Show" : @"Hide"; NSSize z = [lab sizeWithAttributes: Font(11, NO, TF_DIM)]; TextAt(lab, NSMaxX(r) - z.width - 8, NSMidY(r), Font(11, NO, TF_DIM)); } continue; }
		BOOL cur = [it[@"p"] length] && [current isEqual: it[@"p"]]; if (cur) FillRound(r, 11, TFDark() ? (key ? TFRGBA(255, 255, 255, 0.13) : TFRGB(51, 51, 51)) : TFRGBA(0, 0, 0, key ? 0.10 : 0.07));
		NSRect ic = NSMakeRect(18, NSMidY(r) - 11, 22, 22);
		if ([k isEqual: @"tag"]) { [TagColorFor(it[@"t"]) setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(22, NSMidY(r) - 6, 13, 13)] fill]; }
		else if ([it[@"t"] isEqual: @"All Tags…"]) { [[NSColor colorWithCalibratedWhite: 0.6 alpha: 1] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(21, NSMidY(r) - 5, 10, 10)] fill]; [[NSColor colorWithCalibratedWhite: 0.45 alpha: 1] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(27, NSMidY(r) - 5, 10, 10)] fill]; }
		else if ([it[@"s"] isEqual: @"airdrop"]) { NSPoint c = NSMakePoint(29, NSMidY(r) + 2); [tint setStroke]; [tint setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(c.x - 1.6, c.y - 1.6, 3.2, 3.2)] fill]; for (int k = 1; k <= 3; k++) { NSBezierPath *a = [NSBezierPath bezierPath]; [a appendBezierPathWithArcWithCenter: c radius: 2.7 * k + 0.6 startAngle: -45 endAngle: 225 clockwise: NO]; [a setLineWidth: 1.5]; [a setLineCapStyle: NSRoundLineCapStyle]; [a stroke]; } }
		else if (![it[@"s"] length]) { }
		else { NSString *sy = it[@"s"]; if ([sy isEqual: @"trash"]) { static time_t at; static BOOL full; time_t now = time(NULL); if (now != at) { at = now; full = NO; for (NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"] error: NULL]) if (![n hasPrefix: @"."]) { full = YES; break; } } if (full) sy = @"trash.fill"; } TFSymbol(sy, ic, 15, tint); }
		BOOL ej = [it[@"eject"] boolValue]; TextAt(Truncated(it[@"t"], Font(13, NO, TF_TEXT), r.size.width - (ej ? 70 : 52)), 45, NSMidY(r), Font(13, NO, TF_TEXT));
		if (ej) TFSymbol(@"eject.fill", NSMakeRect(NSMaxX(r) - 30, NSMidY(r) - 8, 16, 16), 10, TF_DIM);
	}
}
- (NSString *)dropPathAtWindowPoint:(NSPoint)wp
{
	NSPoint p = [self convertPoint: wp fromView: nil]; if (p.x < 0 || p.x > [self bounds].size.width || p.y < 0 || p.y > [self bounds].size.height) return nil; p.y += off;
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if (![_rows[i][@"k"] isEqual: @"head"] && NSPointInRect(p, [self _rect: i])) { NSString *path = _rows[i][@"p"]; return [path hasPrefix: @"/"] ? path : nil; }
	return nil;
}
- (NSMenu *)menuForEvent:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; p.y = p.y - topInset + off;
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if (![_rows[i][@"k"] isEqual: @"head"] && NSPointInRect(p, [self _rect: i]) && [_rows[i][@"custom"] boolValue]) {
		NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSMenuItem *it = [m addItemWithTitle: @"Remove from Sidebar" action: @selector(_removeFav:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: _rows[i][@"p"]]; TFPopupMenu(self, NSMakePoint(p.x, p.y - off + topInset), m); return nil; }
	return nil;
}
- (void)_removeFav:(NSMenuItem *)it { NSMutableArray *f = [TFPref(@"SidebarFavorites", @[]) mutableCopy]; [f removeObject: [it representedObject]]; TFSetPref(@"SidebarFavorites", f); }
- (void)mouseMoved:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; p.y = p.y - topInset + off; NSInteger h = -1; for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if ([_rows[i][@"k"] isEqual: @"head"] && NSPointInRect(NSMakePoint(p.x, p.y), NSInsetRect([self _rect: i], -10, 4))) h = i; if (h != _hoverHead) { _hoverHead = h; [self setNeedsDisplay: YES]; } }
- (void)mouseExited:(NSEvent *)e { if (_hoverHead != -1) { _hoverHead = -1; [self setNeedsDisplay: YES]; } }
- (void)updateTrackingAreas { [super updateTrackingAreas]; for (NSTrackingArea *t in [self trackingAreas]) [self removeTrackingArea: t]; [self addTrackingArea: [[NSTrackingArea alloc] initWithRect: [self bounds] options: NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner: self userInfo: nil]]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [[self window] setAcceptsMouseMovedEvents: YES]; [self updateTrackingAreas]; }
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e
{
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if ([_rows[i][@"k"] isEqual: @"head"] && NSPointInRect(p, NSInsetRect([self _rect: i], -10, 4)) && p.x > NSMaxX([self _rect: i]) - 60) { NSMutableArray *c = [TFPref(@"SidebarCollapsed", @[]) mutableCopy]; NSString *t = _rows[i][@"t"]; if ([c containsObject: t]) [c removeObject: t]; else [c addObject: t]; TFSetPref(@"SidebarCollapsed", c); [self setNeedsDisplay: YES]; return; }
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if (![_rows[i][@"k"] isEqual: @"head"] && NSPointInRect(p, [self _rect: i])) { NSString *path = _rows[i][@"p"]; if ([_rows[i][@"eject"] boolValue] && p.x > NSMaxX([self _rect: i]) - 40) { if (TFEject(path)) { _sig = nil; [self _poll: nil]; } else NSBeep(); return; } if ([path hasPrefix: @"/"] || [path hasPrefix: @"tag://"] || [path isEqual: @"recents://"] || [path isEqual: @"airdrop://"]) [delegate sidebarGoTo: path]; return; }
}
@end

/* ---------- the tab bar ---------- */
@implementation TTabBar
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (CGFloat)_tabW { return MIN(220, ([self bounds].size.width - 40) / MAX(1, [titles count])); }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [(KeyWin(self) ? TF_CONTENT : TF_SIDEBAR) setFill]; NSRectFill(b); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, b.size.height - 1, b.size.width, 1)); CGFloat w = [self _tabW];
	for (NSUInteger i = 0; i < [titles count]; i++) { NSRect t = NSMakeRect(8 + i * w, 3, w - 4, b.size.height - 7); BOOL sel = (NSInteger)i == selected; if (sel) FillRound(t, 7, TFDark() ? TFRGBA(255, 255, 255, 0.13) : TFRGBA(0, 0, 0, 0.09));
		NSDictionary *at = Font(12, NO, sel ? TF_TEXT : TF_DIM); NSString *s = Truncated(titles[i], at, t.size.width - 40); NSSize z = [s sizeWithAttributes: at]; [s drawAtPoint: NSMakePoint(NSMidX(t) - z.width / 2, NSMidY(t) - z.height / 2) withAttributes: at];
		if ([titles count] > 1) TFSymbolW(@"xmark", NSMakeRect(t.origin.x + 4, t.origin.y, 20, t.size.height), 8, 6, sel ? TF_DIM : TFRGBA(255, 255, 255, 0.0)); }
	TFSymbolW(@"plus", NSMakeRect(b.size.width - 30, 0, 22, b.size.height), 11, 5, TF_DIM);
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; if (p.x > [self bounds].size.width - 34) { [target performSelector: @selector(cmdNewTab:) withObject: nil]; return; }
	CGFloat w = [self _tabW]; NSInteger i = (NSInteger)floor((p.x - 8) / w); if (i < 0 || i >= (NSInteger)[titles count]) return; CGFloat x0 = 8 + i * w;
	if ([titles count] > 1 && p.x < x0 + 24) [target performSelector: @selector(closeTabAt:) withObject: @(i)]; else [target performSelector: @selector(selectTabAt:) withObject: @(i)];
}
@end

/* ---------- the search bar ---------- */
@implementation TSearchBar
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSRect)_tok:(int)k { NSDictionary *a = Font(12, NO, TF_TEXT); CGFloat x = 74; NSString *t0 = @"This Mac", *t1 = folderName ?: @"Folder"; CGFloat w0 = [t0 sizeWithAttributes: a].width + 22, w1 = [t1 sizeWithAttributes: a].width + 22; return k == 0 ? NSMakeRect(x, 6, w0, 22) : NSMakeRect(x + w0 + 6, 6, w1, 22); }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(b); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, b.size.height - 1, b.size.width, 1)); TextAt(@"Search:", 16, 17, Font(12, NO, TF_DIM));
	for (int k = 0; k < 2; k++) { NSRect t = [self _tok: k]; if (k == scope) FillRound(t, 6, TFDark() ? TFRGBA(255, 255, 255, 0.14) : TFRGBA(0, 0, 0, 0.10)); NSString *s = k == 0 ? @"This Mac" : (folderName ?: @"Folder"); TextAt(s, t.origin.x + 11, 17, Font(12, NO, k == scope ? TF_TEXT : TF_DIM)); }
	NSRect kr = [self _kindRect]; FillRound(kr, 6, kind ? (TFDark() ? TFRGBA(255, 255, 255, 0.14) : TFRGBA(0, 0, 0, 0.10)) : TFRGBA(0, 0, 0, 0)); [[NSString stringWithFormat: @"Kind: %@ ▾", kind ?: @"Any"] drawAtPoint: NSMakePoint(kr.origin.x + 8, 9) withAttributes: Font(12, NO, kind ? TF_TEXT : TF_DIM)];
	NSRect sr = [self _saveRect]; FillRound(sr, 6, TF_PILL); TextAt(@"Save", sr.origin.x + 11, 17, Font(12, NO, TF_TEXT));
	if ([info length]) { NSDictionary *a = Font(11, NO, TF_DIM); NSSize z = [info sizeWithAttributes: a]; [info drawAtPoint: NSMakePoint(kr.origin.x - z.width - 14, 17 - z.height / 2) withAttributes: a]; }
}
- (void)_pickKind:(NSMenuItem *)it { kind = [[it title] isEqual: @"Any"] ? nil : [it title]; [self setNeedsDisplay: YES]; [target performSelector: @selector(searchScopeChanged:) withObject: @(scope)]; }
- (NSRect)_saveRect { return NSMakeRect([self bounds].size.width - 66, 6, 52, 22); }
- (NSRect)_kindRect { return NSMakeRect([self bounds].size.width - 66 - 6 - 118, 6, 118, 22); }
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	if (NSPointInRect(p, [self _saveRect])) { [target performSelector: @selector(saveSearch)]; return; }
	if (NSPointInRect(p, [self _kindRect])) { NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (NSString *k in @[ @"Any", @"Folders", @"Documents", @"Images", @"Audio", @"Movies", @"PDF", @"Presentations", @"Applications" ]) { NSMenuItem *it = [m addItemWithTitle: k action: @selector(_pickKind:) keyEquivalent: @""]; [it setTarget: self]; [it setState: [k isEqual: kind ?: @"Any"] ? NSOnState : NSOffState]; } NSRect kr = [self _kindRect]; TFPopupMenu(self, NSMakePoint(kr.origin.x, NSMaxY(kr) + 2), m); return; } for (int k = 0; k < 2; k++) if (NSPointInRect(p, [self _tok: k]) && scope != k) { scope = k; [self setNeedsDisplay: YES]; [target performSelector: @selector(searchScopeChanged:) withObject: @(k)]; } }
@end

/* ---------- the status bar ---------- */
@implementation TStatusBarView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSRect)_track { NSRect b = [self bounds]; return NSMakeRect(b.size.width - 104, 0, 82, b.size.height); }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(b); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, 0, b.size.width, 1)); NSDictionary *at = Font(11, NO, TF_DIM); NSSize z = [text sizeWithAttributes: at];
	[text ?: @"" drawAtPoint: NSMakePoint(b.size.width / 2 - z.width / 2, b.size.height / 2 - z.height / 2) withAttributes: at];
	if (showSlider) { NSRect t = [self _track]; [TFDark() ? TFRGBA(255, 255, 255, 0.22) : TFRGBA(0, 0, 0, 0.2) setFill]; FillRound(NSMakeRect(t.origin.x, 13, t.size.width, 3), 1.5, TFDark() ? TFRGBA(255, 255, 255, 0.22) : TFRGBA(0, 0, 0, 0.2)); CGFloat kx = t.origin.x + 7 + value * (t.size.width - 14); FillRound(NSMakeRect(kx - 7, 7, 14, 14), 7, TFDark() ? TFRGB(200, 200, 200) : TFRGB(255, 255, 255)); [TF_LINE setStroke]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(kx - 6.5, 7.5, 13, 13)] stroke]; }
}
- (void)mouseDown:(NSEvent *)e
{
	if (!showSlider) return; NSRect t = [self _track]; NSEvent *ev = e;
	do { NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil]; if (p.x < t.origin.x - 8) break; value = MAX(0, MIN(1, (p.x - t.origin.x - 7) / (t.size.width - 14))); [self setNeedsDisplay: YES]; [target performSelector: @selector(sliderChanged:) withObject: @(value)];
		if ([ev type] == NSLeftMouseUp) break; ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES]; } while (1);
}
@end

/* ---------- the path bar ---------- */
@implementation TPathBarView
- (BOOL)isFlipped { return YES; }
- (void)setPath:(NSString *)p { path = [p copy]; NSMutableArray *a = [NSMutableArray array]; NSString *q = p; while (YES) { [a insertObject: q atIndex: 0]; if ([q isEqual: @"/"]) break; q = [q stringByDeletingLastPathComponent]; if (![q length]) break; } _paths = a; [self setNeedsDisplay: YES]; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_PATHBAR setFill]; NSRectFill(b); [TFDark() ? TFRGB(46, 46, 46) : TF_LINE setFill]; NSRectFill(NSMakeRect(0, 0, b.size.width, 1)); _rects = [NSMutableArray array]; CGFloat x = 5; NSDictionary *at = Font(11, NO, TF_TEXT);
	for (NSString *p in _paths) {
		NSString *name = TFDisplayName(p); CGFloat tw = [name sizeWithAttributes: at].width, w = tw + 34; TFDrawIcon(p, NSMakeRect(x + 6, 8, 14, 14)); TextAt(name, x + 24, 15, at);
		if (p != [_paths lastObject]) TFSymbol(@"chevron.right", NSMakeRect(x + w - 12, 0, 8, 30), 8, TF_DIM);
		[_rects addObject: [NSValue valueWithRect: NSMakeRect(x, 0, w, 30)]]; x += w;
	}
}
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSUInteger i = 0; i < [_rects count]; i++) if (NSPointInRect(p, [_rects[i] rectValue])) { [delegate pathBarGoTo: _paths[i]]; return; } }
- (void)rightMouseDown:(NSEvent *)e       /* the menu of a path item, as the Mac's (AX of the open menu) */
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; if (![delegate respondsToSelector: @selector(pathBarMenuForPath:)]) return;
	for (NSUInteger i = 0; i < [_rects count]; i++) if (NSPointInRect(p, [_rects[i] rectValue])) { NSMenu *m = [delegate pathBarMenuForPath: _paths[i]]; if (m) TFPopupMenu(self, p, m); return; }
}
@end

/* ---------- the toolbar ---------- */
/* the "gallery" glyph of the view modes: a rectangle over four dashes (no SF Symbol of that look): an NSImage that draws itself in the colour of the theme */
@interface TGroupGlyph : NSImage @end
@implementation TGroupGlyph       /* the Group glyph: two rows of three small boxes over a line, and a chevron (as measured in the Finder's toolbar); drawn in flipped coordinates about the centre of the 48 wide pill */
- (void)drawInRect:(NSRect)r fromRect:(NSRect)f operation:(NSCompositingOperation)op fraction:(CGFloat)a
{
	NSColor *t = TFDark() ? TFRGB(245, 245, 245) : TF_TEXT; CGFloat cx = NSMidX(r), cy = NSMidY(r), left = cx - 24; [NSGraphicsContext saveGraphicsState];
	if (![[NSGraphicsContext currentContext] isFlipped]) { NSAffineTransform *x = [NSAffineTransform transform]; [x translateXBy: 0 yBy: 2 * cy]; [x scaleXBy: 1 yBy: -1]; [x concat]; }
	[t setStroke]; for (int row = 0; row < 2; row++) for (int col = 0; col < 3; col++) { NSBezierPath *o = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(left + 9 + col * 6.5, cy - 3.5 + row * 6, 5, 4) xRadius: 1 yRadius: 1]; [o setLineWidth: 1.1]; [o stroke]; }
	[t setFill]; NSRectFill(NSMakeRect(left + 9, cy - 7, 17, 1.2));
	NSBezierPath *c = [NSBezierPath bezierPath]; [c setLineWidth: 1.5]; [c setLineCapStyle: NSRoundLineCapStyle]; [c setLineJoinStyle: NSRoundLineJoinStyle]; [c moveToPoint: NSMakePoint(left + 31, cy - 1.5)]; [c lineToPoint: NSMakePoint(left + 35, cy + 2.5)]; [c lineToPoint: NSMakePoint(left + 39, cy - 1.5)]; [c stroke]; [NSGraphicsContext restoreGraphicsState];
}
@end
@interface TShareGlyph : NSImage @end
@implementation TShareGlyph       /* the Share glyph (a box with an arrow), drawn in the colour of the theme; the shape is in flipped coordinates */
- (void)drawInRect:(NSRect)r fromRect:(NSRect)f operation:(NSCompositingOperation)op fraction:(CGFloat)a
{
	NSColor *t = TFDark() ? TFRGB(245, 245, 245) : TF_TEXT; CGFloat cx = NSMidX(r), cy = NSMidY(r); [NSGraphicsContext saveGraphicsState];
	if (![[NSGraphicsContext currentContext] isFlipped]) { NSAffineTransform *x = [NSAffineTransform transform]; [x translateXBy: 0 yBy: 2 * cy]; [x scaleXBy: 1 yBy: -1]; [x concat]; }
	cy += 0; [t setStroke]; NSBezierPath *q = [NSBezierPath bezierPath]; [q setLineWidth: 1.7]; [q setLineCapStyle: NSRoundLineCapStyle]; [q setLineJoinStyle: NSRoundLineJoinStyle]; [q moveToPoint: NSMakePoint(cx, cy + 3)]; [q lineToPoint: NSMakePoint(cx, cy - 10)]; [q moveToPoint: NSMakePoint(cx - 3.8, cy - 6.2)]; [q lineToPoint: NSMakePoint(cx, cy - 10.2)]; [q lineToPoint: NSMakePoint(cx + 3.8, cy - 6.2)];
	NSBezierPath *u = [NSBezierPath bezierPath]; [u setLineWidth: 1.7]; [u setLineCapStyle: NSRoundLineCapStyle]; [u setLineJoinStyle: NSRoundLineJoinStyle]; [u moveToPoint: NSMakePoint(cx - 3.5, cy - 3.8)]; [u lineToPoint: NSMakePoint(cx - 4.8, cy - 3.8)]; [u curveToPoint: NSMakePoint(cx - 7.6, cy - 1) controlPoint1: NSMakePoint(cx - 6.4, cy - 3.8) controlPoint2: NSMakePoint(cx - 7.6, cy - 2.6)]; [u lineToPoint: NSMakePoint(cx - 7.6, cy + 6)]; [u curveToPoint: NSMakePoint(cx - 4.8, cy + 8.8) controlPoint1: NSMakePoint(cx - 7.6, cy + 7.6) controlPoint2: NSMakePoint(cx - 6.4, cy + 8.8)]; [u lineToPoint: NSMakePoint(cx + 4.8, cy + 8.8)]; [u curveToPoint: NSMakePoint(cx + 7.6, cy + 6) controlPoint1: NSMakePoint(cx + 6.4, cy + 8.8) controlPoint2: NSMakePoint(cx + 7.6, cy + 7.6)]; [u lineToPoint: NSMakePoint(cx + 7.6, cy - 1)]; [u curveToPoint: NSMakePoint(cx + 4.8, cy - 3.8) controlPoint1: NSMakePoint(cx + 7.6, cy - 2.6) controlPoint2: NSMakePoint(cx + 6.4, cy - 3.8)]; [u lineToPoint: NSMakePoint(cx + 3.5, cy - 3.8)]; [u stroke]; [q stroke]; [NSGraphicsContext restoreGraphicsState];
}
@end
@interface TGalleryGlyph : NSImage @end
@implementation TGalleryGlyph
- (void)drawInRect:(NSRect)r fromRect:(NSRect)f operation:(NSCompositingOperation)op fraction:(CGFloat)a
{
	NSColor *t = TFDark() ? TFRGB(245, 245, 245) : TF_TEXT; NSRect g = NSMakeRect(NSMidX(r) - 10, NSMidY(r) - 7, 20, 14); BOOL fl = [[NSGraphicsContext currentContext] isFlipped]; double ry = fl ? g.origin.y + 0.8 : g.origin.y + 5.8, dy = fl ? g.origin.y + 12 : g.origin.y; [t setStroke]; NSBezierPath *o = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(g.origin.x + 0.8, ry, 18.4, 7.4) xRadius: 2 yRadius: 2]; [o setLineWidth: 1.6]; [o stroke]; [t setFill]; for (int q = 0; q < 4; q++) NSRectFill(NSMakeRect(g.origin.x + 1 + q * 5, dy, 3, 2));
}
@end
@implementation TToolbarView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSRect)_pill:(int)k                    /* 0 nav, 1 modes, 2 group, 3 actions, 4 search: 36 high 8 from the top; widths, gaps (7) and the right margin (8) as measured in the 1022 wide window */
{
	CGFloat w = [self bounds].size.width, sw = searching ? 200 : 37, x = w - 8 - sw; if (k == 4) return NSMakeRect(x, 8, sw, 36);
	if (trashMode) { x -= 7 + 66; if (k == 5) return NSMakeRect(x, 8, 66, 36); }
	x -= 7 + 112; if (k == 3) return NSMakeRect(x, 8, 112, 36); x -= 7 + 48; if (k == 2) return NSMakeRect(x, 8, 48, 36); x -= 7 + 161; if (k == 1) return NSMakeRect(x, 8, 161, 36);
	return NSMakeRect(7, 8, 74, 36);
}
- (void)_syncSearchSegment
{
	if (!srchSeg) { srchSeg = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect]; [srchSeg setSegmentStyle: NSSegmentStyleCapsule]; [srchSeg setTrackingMode: NSSegmentSwitchTrackingMomentary]; [srchSeg setSegmentCount: 1]; [srchSeg setImage: [NSImage imageWithSystemSymbolName: @"magnifyingglass" accessibilityDescription: nil] forSegment: 0]; [srchSeg setWidth: 37 forSegment: 0]; [srchSeg setIdentifier: @"nosep"]; [srchSeg setTarget: self]; [srchSeg setAction: @selector(_searchPicked:)]; [self addSubview: srchSeg]; }
	[srchSeg setFrame: [self _pill: 4]]; [srchSeg setHidden: searching];
}
- (void)_searchPicked:(id)s { [NSApp sendAction: @selector(cmdToggleSearch:) to: target from: self]; }
- (void)_syncGroupSegment
{
	if (!grpSeg) { grpSeg = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect]; [grpSeg setSegmentStyle: NSSegmentStyleCapsule]; [grpSeg setTrackingMode: NSSegmentSwitchTrackingMomentary]; [grpSeg setSegmentCount: 1]; [grpSeg setImage: [[TGroupGlyph alloc] initWithSize: NSMakeSize(34, 20)] forSegment: 0]; [grpSeg setWidth: 48 forSegment: 0]; [grpSeg setIdentifier: @"nosep"]; [grpSeg setTarget: self]; [grpSeg setAction: @selector(_groupPicked:)]; [self addSubview: grpSeg]; }
	[grpSeg setFrame: [self _pill: 2]];
}
- (void)_groupPicked:(NSSegmentedControl *)s { NSRect gr = [self _pill: 2]; if ([target respondsToSelector: @selector(groupMenu)]) TFPopupMenu(self, NSMakePoint(gr.origin.x, 46), [target performSelector: @selector(groupMenu)]); }
- (void)_syncNavSegment
{
	if (!navSeg) { navSeg = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect]; [navSeg setSegmentStyle: NSSegmentStyleCapsule]; [navSeg setTrackingMode: NSSegmentSwitchTrackingMomentary]; [navSeg setSegmentCount: 2]; NSArray *n = @[ @"chevron.left", @"chevron.right" ];
		for (int k = 0; k < 2; k++) { [navSeg setImage: [NSImage imageWithSystemSymbolName: n[k] accessibilityDescription: nil] forSegment: k]; [navSeg setWidth: 37 forSegment: k]; } [navSeg setTarget: self]; [navSeg setAction: @selector(_navPicked:)]; [self addSubview: navSeg]; }
	[navSeg setFrame: [self _pill: 0]]; [navSeg setEnabled: canBack forSegment: 0]; [navSeg setEnabled: canForward forSegment: 1];
}
- (void)_navPicked:(NSSegmentedControl *)s { NSInteger k = [s selectedSegment]; if (k == 0 && canBack) [NSApp sendAction: @selector(cmdBack:) to: target from: self]; else if (k == 1 && canForward) [NSApp sendAction: @selector(cmdForward:) to: target from: self]; }
- (void)_syncActionSegment
{
	if (!actSeg) { actSeg = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect]; [actSeg setSegmentStyle: NSSegmentStyleCapsule]; [actSeg setTrackingMode: NSSegmentSwitchTrackingMomentary]; [actSeg setSegmentCount: 3]; NSArray *n = @[ @"", @"tag", @"ellipsis" ]; [actSeg setIdentifier: @"nosep"];       /* no lines between the segments (theme) */
		for (int k = 0; k < 3; k++) { [actSeg setImage: k == 0 ? [[TShareGlyph alloc] initWithSize: NSMakeSize(20, 20)] : [NSImage imageWithSystemSymbolName: n[k] accessibilityDescription: nil] forSegment: k]; [actSeg setWidth: 112.0 / 3 forSegment: k]; } [actSeg setTarget: self]; [actSeg setAction: @selector(_actPicked:)]; [self addSubview: actSeg]; }
	[actSeg setFrame: [self _pill: 3]];
}
- (void)_actPicked:(NSSegmentedControl *)s
{
	NSInteger k = [s selectedSegment]; NSRect ac = [self _pill: 3]; CGFloat aw = ac.size.width / 3;
	if (k == 2) TFPopupMenu(self, NSMakePoint(ac.origin.x + 2 * aw, 46), [target performSelector: @selector(actionMenu)]); else if (k == 1) [target performSelector: @selector(cmdTagsPopup:) withObject: nil]; else [target performSelector: @selector(cmdShare:) withObject: nil];
}
- (void)_syncModeSegment
{
	if (!modeSeg) { modeSeg = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect]; [modeSeg setSegmentStyle: NSSegmentStyleCapsule]; [modeSeg setSegmentCount: 4]; NSArray *syms = @[ @"square.grid.2x2", @"list.bullet", @"rectangle.split.3x1", @"" ];
		for (int k = 0; k < 4; k++) { NSImage *im = k == 3 ? [[TGalleryGlyph alloc] initWithSize: NSMakeSize(20, 14)] : [NSImage imageWithSystemSymbolName: syms[k] accessibilityDescription: nil]; [modeSeg setImage: im forSegment: k]; [modeSeg setWidth: 161.0 / 4 forSegment: k]; }
		[modeSeg setTarget: self]; [modeSeg setAction: @selector(_modePicked:)]; [self addSubview: modeSeg]; }
	[modeSeg setFrame: [self _pill: 1]]; if ([modeSeg selectedSegment] != mode) [modeSeg setSelectedSegment: mode];
}
- (void)_modePicked:(NSSegmentedControl *)s { if (getenv("FINDER_DEBUG")) NSLog(@"mode picked %ld", (long)[s selectedSegment]); SEL a[4] = { @selector(cmdViewAsIcons:), @selector(cmdViewAsList:), @selector(cmdViewAsColumns:), @selector(cmdViewAsGallery:) }; NSInteger k = [s selectedSegment] & 3; [NSApp sendAction: a[k] to: target from: self]; }
- (NSRect)buttonRect:(int)i { NSRect ac = [self _pill: 3]; CGFloat aw = ac.size.width / 3; return NSMakeRect(ac.origin.x + i * aw, 0, aw, 52); }
- (void)setSearching:(BOOL)on
{
	searching = on; if (!search) { search = [[NSTextField alloc] initWithFrame: NSZeroRect]; [search setBordered: NO]; [search setBezeled: NO]; [search setDrawsBackground: NO]; [[search cell] setBackgroundColor: [NSColor clearColor]]; [search setFont: [NSFont systemFontOfSize: 13]]; [search setTextColor: TF_TEXT]; [search setFocusRingType: NSFocusRingTypeNone]; [search setDelegate: (id)self]; [self addSubview: search]; }
	NSRect p = [self _pill: 4]; [search setFrame: NSMakeRect(p.origin.x + 32, 14, p.size.width - 44, 22)]; [search setHidden: !on]; if (on) { [[self window] makeFirstResponder: search]; NSTextView *fe = (NSTextView *)[search currentEditor]; [fe setDrawsBackground: NO]; [fe setBackgroundColor: [NSColor clearColor]]; [fe setTextColor: TF_TEXT]; [fe setInsertionPointColor: TF_TEXT]; } else [search setStringValue: @""]; [self setNeedsDisplay: YES];
}
- (void)controlTextDidBeginEditing:(NSNotification *)n { NSTextView *fe = (NSTextView *)[[search window] fieldEditor: YES forObject: search]; [fe setDrawsBackground: NO]; [fe setTextColor: TF_TEXT]; [fe setInsertionPointColor: TF_TEXT]; }
- (void)controlTextDidChange:(NSNotification *)n { [target performSelector: @selector(searchChanged:) withObject: [search stringValue]]; }
- (void)setFrameSize:(NSSize)s { [super setFrameSize: s]; if (searching) { NSRect p = [self _pill: 4]; [search setFrame: NSMakeRect(p.origin.x + 32, 14, p.size.width - 44, 22)]; } }
- (void)drawRect:(NSRect)r
{
	[(KeyWin(self) ? TF_CONTENT : TF_SIDEBAR) setFill]; NSRectFill([self bounds]); NSColor *t = TFDark() ? TFRGB(245, 245, 245) : TF_TEXT; NSRect pr = _pressed; NSColor *off = TFDark() ? TFRGBA(255, 255, 255, 0.28) : TFRGBA(0, 0, 0, 0.25);
	[self _syncNavSegment];       /* back/forward: an NSSegmentedControl (capsule) */
	TextAt(title ?: @"", 93, 26, Font(15, YES, KeyWin(self) ? t : TF_DIM));
	[self _syncModeSegment];       /* the view modes are an NSSegmentedControl (capsule style, drawn by the theme) */
	[self _syncGroupSegment];       /* Group: a one segment capsule that opens the menu */
	[self _syncActionSegment];       /* Share, Tags, Action: an NSSegmentedControl (capsule) */
	if (trashMode) { NSRect er = [self _pill: 5]; GlassPill(er, pr); NSSize ez = [@"Empty" sizeWithAttributes: Font(13, NO, t)]; [@"Empty" drawAtPoint: NSMakePoint(NSMidX(er) - ez.width / 2, 26 - ez.height / 2) withAttributes: Font(13, NO, t)]; }
	NSRect sr = [self _pill: 4]; [self _syncSearchSegment]; if (searching) { GlassPill(sr, pr); TFSymbol(@"magnifyingglass", NSMakeRect(sr.origin.x, 8, 34, 36), 20, TF_DIM); }       /* collapsed: an NSSegmentedControl capsule; open: the pill with the text field */
	if (searching && ![[search stringValue] length] && [[self window] firstResponder] != [search currentEditor]) TextAt(@"Search", sr.origin.x + 34, 26, Font(13, NO, TF_DIM));
}
- (BOOL)isDragPoint:(NSPoint)p { for (int k = 0; k < (trashMode ? 6 : 5); k++) if (NSPointInRect(p, [self _pill: k])) return NO; return YES; }
- (NSRect)_hitRect:(NSPoint)p                                                                  /* the control under p, for the pressed look */
{
	NSRect nav = [self _pill: 0], md = [self _pill: 1], ac = [self _pill: 3];
	if (NSPointInRect(p, nav)) return p.x < NSMidX(nav) ? NSMakeRect(nav.origin.x, 7, nav.size.width / 2, 38) : NSMakeRect(NSMidX(nav), 7, nav.size.width / 2, 38);
	if (NSPointInRect(p, md)) { CGFloat sw = md.size.width / 4; int k = (int)((p.x - md.origin.x) / sw) & 3; return NSMakeRect(md.origin.x + k * sw, 7, sw, 38); }
	if (NSPointInRect(p, ac)) { CGFloat aw = ac.size.width / 3; int k = (int)((p.x - ac.origin.x) / aw); return NSMakeRect(ac.origin.x + k * aw, 7, aw, 38); }
	if (NSPointInRect(p, [self _pill: 2])) return [self _pill: 2]; if (NSPointInRect(p, [self _pill: 4])) return [self _pill: 4]; if (trashMode && NSPointInRect(p, [self _pill: 5])) return [self _pill: 5];
	return NSZeroRect;
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p0 = [self convertPoint: [e locationInWindow] fromView: nil]; NSRect hit = [self _hitRect: p0]; if (NSIsEmptyRect(hit)) return; _pressed = hit; [self setNeedsDisplay: YES]; [self displayIfNeeded]; NSEvent *ev = e;
	while ([ev type] != NSLeftMouseUp) { ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES]; NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; NSRect now = NSPointInRect(q, hit) ? hit : NSZeroRect; if (!NSEqualRects(now, _pressed)) { _pressed = now; [self setNeedsDisplay: YES]; [self displayIfNeeded]; } }
	BOOL inside = !NSIsEmptyRect(_pressed); _pressed = NSZeroRect; [self setNeedsDisplay: YES]; if (inside) [self _act: e point: p0];
}
- (void)_act:(NSEvent *)e point:(NSPoint)p
{
	NSRect nav = [self _pill: 0], md = [self _pill: 1];
	if (NSPointInRect(p, nav)) { if (p.x < NSMidX(nav)) { if (canBack) [NSApp sendAction: @selector(cmdBack:) to: target from: self]; } else if (canForward) [NSApp sendAction: @selector(cmdForward:) to: target from: self]; return; }
	if (NSPointInRect(p, md)) { SEL a[4] = { @selector(cmdViewAsIcons:), @selector(cmdViewAsList:), @selector(cmdViewAsColumns:), @selector(cmdViewAsGallery:) }; [NSApp sendAction: a[(int)((p.x - md.origin.x) / (md.size.width / 4)) & 3] to: target from: self]; return; }
	NSRect ac = [self _pill: 3]; if (NSPointInRect(p, ac)) { CGFloat aw = ac.size.width / 3; if (p.x > ac.origin.x + 2 * aw) TFPopupMenu(self, NSMakePoint(ac.origin.x + 2 * aw, 46), [target performSelector: @selector(actionMenu)]); else if (p.x > ac.origin.x + aw) { [target performSelector: @selector(cmdTagsPopup:) withObject: nil]; } else { [target performSelector: @selector(cmdShare:) withObject: nil]; } return; }
	{ NSRect gr = [self _pill: 2]; if (NSPointInRect(p, gr) && [target respondsToSelector: @selector(groupMenu)]) { TFPopupMenu(self, NSMakePoint(gr.origin.x, 46), [target performSelector: @selector(groupMenu)]); return; } }
	if (trashMode && NSPointInRect(p, [self _pill: 5])) { [NSApp sendAction: @selector(cmdEmptyTrash:) to: target from: self]; return; }
	if (NSPointInRect(p, [self _pill: 4]) && !searching) [NSApp sendAction: @selector(cmdToggleSearch:) to: target from: self];
}
@end

/* ---------- the trim on top: the window buttons, the rim ---------- */
@implementation TWindowTrim
- (BOOL)isFlipped { return YES; } - (BOOL)isOpaque { return NO; }
- (NSRect)_light:(int)k { return NSMakeRect(18 + 23 * k, 18, 16, 16); }       /* measured on the Mac (AX): 16 x 16 at x 18, 41, 64, 18 from the top */
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) _pressed = -1; return self; }
- (NSRect)_group { return NSInsetRect(NSUnionRect([self _light: 0], [self _light: 2]), -4, -4); }
- (void)_pollHover:(NSTimer *)t { NSWindow *w = [self window]; BOOL in = NO; if (w && [w isVisible]) { NSPoint lp = [self convertPoint: [w convertScreenToBase: [NSEvent mouseLocation]] fromView: nil]; in = NSPointInRect(lp, [self _group]) && NSPointInRect(lp, [self bounds]); } if (in != _hover) { _hover = in; [self setNeedsDisplayInRect: [self _group]]; } }
- (void)viewDidMoveToWindow { if ([self window] && !_poll) _poll = [NSTimer scheduledTimerWithTimeInterval: 0.05 target: self selector: @selector(_pollHover:) userInfo: nil repeats: YES]; }
- (NSView *)hitTest:(NSPoint)p { NSPoint q = [self convertPoint: p fromView: [self superview]]; for (int k = 0; k < 3; k++) if (NSPointInRect(q, NSInsetRect([self _light: k], -4, -4))) return self; return nil; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)drawRect:(NSRect)r
{
	BOOL key = KeyWin(self); NSRect b = [self bounds]; NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(b, 0.5, 0.5) xRadius: 16 yRadius: 16]; [TFDark() ? TFRGBA(255, 255, 255, 0.20) : TFRGBA(0, 0, 0, 0.22) setStroke]; [rim setLineWidth: 1]; [rim stroke];
	NSColor *cols[3] = { TFRGB(242, 96, 86), TFRGB(253, 193, 1), TFRGB(57, 193, 1) }; Class sup = NSClassFromString(@"WsdFinderSupport");
	for (int k = 0; k < 3; k++) { NSRect c = [self _light: k]; BOOL pr = _pressed == k;
		NSImage *pic = nil; if (key || _hover || pr) { SEL sl = NSSelectorFromString(@"windowButtonKind:state:"); if ([sup respondsToSelector: sl]) pic = ((NSImage *(*)(id, SEL, int, int))objc_msgSend)(sup, sl, k, pr ? 2 : (_hover ? 1 : 0)); }
		if (pic) { BOOL rel = _relBtn == k && _relTimer; SEL ds = NSSelectorFromString(@"drawWindowButton:rect:held:pull:"); NSPoint pl = pr ? _pull : rel ? NSMakePoint(_relPull.x * _relF, _relPull.y * _relF) : NSZeroPoint; if ([sup respondsToSelector: ds]) ((void (*)(id, SEL, NSImage *, NSRect, BOOL, NSPoint))objc_msgSend)(sup, ds, pic, c, pr || rel, pl); else [pic drawInRect: c fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0]; continue; }
		[(key ? cols[k] : (TFDark() ? TFRGB(76, 76, 76) : TFRGB(205, 205, 205))) setFill]; [[NSBezierPath bezierPathWithOvalInRect: c] fill]; [TFRGBA(0, 0, 0, 0.12) setStroke]; [[NSBezierPath bezierPathWithOvalInRect: NSInsetRect(c, 0.5, 0.5)] stroke]; }
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (int k = 0; k < 3; k++) if (NSPointInRect(p, NSInsetRect([self _light: k], -4, -4))) { _pressed = k; _inside = YES; _hover = YES; [self setNeedsDisplayInRect: [self _group]]; return; }       /* the action runs when it is released over the button */
}
- (void)mouseDragged:(NSEvent *)e { if (_pressed < 0) return; NSPoint q = [self convertPoint: [e locationInWindow] fromView: nil]; NSRect cr = [self _light: _pressed]; _inside = NSPointInRect(q, NSInsetRect(cr, -4, -4)); _pull = NSMakePoint(q.x - NSMidX(cr), q.y - NSMidY(cr)); [self setNeedsDisplay: YES]; }       /* it stretches like rubber toward the pointer (WsdDrawWindowButton) */
- (void)_release:(NSTimer *)t { _relT += 1.0 / 60; _relF = exp(-_relT * 11.0) * cos(_relT * 26.0); if (_relT > 0.4) { [_relTimer invalidate]; _relTimer = nil; _relBtn = -1; _relF = 0; } [self setNeedsDisplay: YES]; }
- (void)mouseUp:(NSEvent *)e { if (_pressed < 0) return; int k = _pressed; BOOL fire = _inside; _pressed = -1; _inside = NO; if (hypot(_pull.x, _pull.y) > 3) { _relBtn = k; _relPull = _pull; _relT = 0; _relF = 1; [_relTimer invalidate]; _relTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(_release:) userInfo: nil repeats: YES]; } _pull = NSZeroPoint; [self setNeedsDisplay: YES]; if (fire) { if (k == 0) [[self window] performClose: self]; else if (k == 1) [[self window] performMiniaturize: self]; else [[self window] performZoom: self]; } }
@end

/* ---------- the preview pane ---------- */
@interface NSDictionary (TFAdd) - (NSDictionary *)dictionaryWithAddedEntries:(NSDictionary *)e; @end
@implementation NSDictionary (TFAdd) - (NSDictionary *)dictionaryWithAddedEntries:(NSDictionary *)e { NSMutableDictionary *m = [self mutableCopy]; [m addEntriesFromDictionary: e]; return m; } @end
@implementation TPreviewPane
- (BOOL)isFlipped { return YES; }
/* Layout read from the accessibility tree of the real Finder's preview pane (310 wide; from the top of the pane): the preview 273 x 255 at (10, 10), the name 14 pt bold at (10, 291), the kind and the
 * size 13 pt dimmed at (9, 313), "Information" 14 pt bold at (9, 337), the rows "Created" and "Modified" 13 pt (the label dimmed at x 9, the value bold, right-aligned to x 284) on a pitch of 23 from y 361,
 * "Tags" 14 pt bold at (9, 415), its field 273 x 33 at (10, 438). Missing: "Show More" (its rows depend on the kind of file and were measured for a PDF only), the preview of documents (only pictures here),
 * the quick actions under the pane. The dates are written as the Mac does ("Monday, 3 August 2026 at 18:31"). */
static NSString *LongDate(NSDate *d) { if (!d) return @""; static NSDateFormatter *f; if (!f) { f = [[NSDateFormatter alloc] init]; [f setLocale: [[NSLocale alloc] initWithLocaleIdentifier: @"en_GB"]]; [f setDateFormat: @"EEEE, d MMMM yyyy 'at' HH:mm"]; } return [f stringFromDate: d]; }
/* the quick actions under the pane (AX and pixels of the real one): a bar 70 high at the bottom, darker (29,30,33) with a line (65,67,70) on top; buttons 64 / 46 / 42 wide at x 47 / 132 / 210 and 14 from the bar's top, a 14 pt symbol over an 11 pt label, grey (142,142,144) */
- (NSArray *)_quickActions:(BOOL)dir path:(NSString *)p       /* centres from the AX frames: three buttons 79 / 155 / 231, a single one (a ZIP) 193; the kinds measured: picture, PDF, archive */
{
	NSString *ext = [[p pathExtension] lowercaseString]; BOOL img = !dir && [@[ @"png", @"jpg", @"jpeg", @"tif", @"tiff", @"gif", @"bmp", @"heic" ] containsObject: ext], pdf = !dir && [ext isEqual: @"pdf"]; NSMutableArray *a = [NSMutableArray array];
	NSDictionary *more = @{ @"t": @"More…", @"s": @"ellipsis.circle", @"sel": @"cmdOpenQuickActionsPrefPane:" }, *markup = @{ @"t": @"Markup", @"s": @"pencil.tip.crop.circle", @"sel": @"" };
	if (img) { [a addObject: @{ @"t": @"Rotate Left", @"s": @"rotate.left", @"sel": @"cmdRotateLeft:", @"c": @79 }]; [a addObject: [markup dictionaryWithAddedEntries: @{ @"c": @155 }]]; [a addObject: [more dictionaryWithAddedEntries: @{ @"c": @231 }]]; }
	else if (pdf) { NSArray *apps = TFAppsForFile(p); [a addObject: [markup dictionaryWithAddedEntries: @{ @"c": @79 }]]; if ([apps count]) [a addObject: @{ @"t": [@"Open with " stringByAppendingString: apps[0][@"name"]], @"s": @"ellipsis.circle", @"sel": @"", @"c": @155 }]; [a addObject: [more dictionaryWithAddedEntries: @{ @"c": @231 }]]; }       /* without a default application only two buttons: their places are not measured (the slots 79 and 231 are assumed) */
	else [a addObject: [more dictionaryWithAddedEntries: @{ @"c": @193 }]];
	return a;
}
- (CGFloat)_barH { return TFPreviewOpt(@"quickActions") ? 70 : 0; }
- (void)_drawQuickBar:(BOOL)dir path:(NSString *)p
{
	if (![self _barH]) return;
	NSRect b = [self bounds]; CGFloat top = NSMaxY(b) - 70; [TFRGB(29, 30, 33) setFill]; NSRectFill(NSMakeRect(1, top, b.size.width - 1, 70)); [TFRGB(65, 67, 70) setFill]; NSRectFill(NSMakeRect(0, top - 1, b.size.width, 1));
	for (NSDictionary *q in [self _quickActions: dir path: p]) { CGFloat cx = [q[@"c"] doubleValue]; NSColor *c = TFRGB(142, 142, 144); TFSymbol(q[@"s"], NSMakeRect(cx - 7, top + 17, 14, 14), 14, c); NSDictionary *la = Font(11, NO, c); NSString *t = q[@"t"]; NSArray *lines = @[ t ];
		if ([t sizeWithAttributes: la].width > 70) { NSRange r = [t rangeOfString: @" " options: NSBackwardsSearch]; if (r.location != NSNotFound) lines = @[ [t substringToIndex: r.location], [t substringFromIndex: r.location + 1] ]; }
		for (NSUInteger i = 0; i < [lines count]; i++) { NSSize ls = [lines[i] sizeWithAttributes: la]; [lines[i] drawAtPoint: NSMakePoint(cx - ls.width / 2, top + 40 + i * 14) withAttributes: la]; } }
}
- (void)scrollWheel:(NSEvent *)e { CGFloat room = MAX(0, _content - ([self bounds].size.height - [self _barH])); _scroll = MAX(0, MIN(room, _scroll - [e deltaY] * 10)); [self setNeedsDisplay: YES]; }
- (void)mouseDown:(NSEvent *)e
{
	if ([paths count] != 1) return; NSPoint pt = [self convertPoint: [e locationInWindow] fromView: nil]; if (![self _barH]) return; CGFloat top = NSMaxY([self bounds]) - 70; if (pt.y < top) { if (NSPointInRect(NSMakePoint(pt.x, pt.y + _scroll), NSMakeRect(215, 335, 72, 22))) { _more = !_more; [self setNeedsDisplay: YES]; } return; } NSString *p = paths[0]; BOOL dir = [[[[NSFileManager defaultManager] attributesOfItemAtPath: p error: NULL] fileType] isEqual: NSFileTypeDirectory];
	for (NSDictionary *q in [self _quickActions: dir path: p]) { CGFloat cx = [q[@"c"] doubleValue]; if (fabs(pt.x - cx) <= 32) { if ([q[@"sel"] length]) [NSApp sendAction: NSSelectorFromString(q[@"sel"]) to: nil from: self]; else NSBeep(); return; } }
}
- (void)drawRect:(NSRect)dirty
{
	NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(b); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, 0, 1, b.size.height)); NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
	NSDictionary *tl = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 14], NSForegroundColorAttributeName: TF_TEXT, NSParagraphStyleAttributeName: ps }, *sub = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TF_DIM, NSParagraphStyleAttributeName: ps }, *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 14], NSForegroundColorAttributeName: TF_TEXT };
	if ([paths count] != 1) {
		NSString *dir = [paths count] ? nil : folder; unsigned long long total = 0; for (NSString *p in paths) total += [[fm attributesOfItemAtPath: p error: NULL][NSFileSize] unsignedLongLongValue];
		NSString *title = [paths count] ? [NSString stringWithFormat: @"%lu items", (unsigned long)[paths count]] : [dir length] ? (TFDisplayName(dir) ?: [dir lastPathComponent]) : @"";
		NSRect ir = NSMakeRect(NSMidX(b) - 64, 10 + (255 - 128) / 2, 128, 128); if ([paths count]) TFDrawIcon(@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns", ir); else if (dir) TFDrawIcon(dir, ir);
		[title drawInRect: NSMakeRect(10, 291 + 1, 273, 20) withAttributes: tl]; if ([paths count]) [TFSizeString(total) drawInRect: NSMakeRect(9, 313, 275, 18) withAttributes: sub];
		return;
	}
	NSString *p = paths[0]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory]; NSImage *th = dir ? nil : Thumb(p); NSRect pr = NSMakeRect(10, 10, 273, 255); BOOL img = !dir && [@[ @"png", @"jpg", @"jpeg", @"tif", @"tiff", @"gif", @"bmp", @"heic" ] containsObject: [[p pathExtension] lowercaseString]];
	[NSGraphicsContext saveGraphicsState]; NSRectClip(NSMakeRect(0, 0, b.size.width, b.size.height - [self _barH])); NSAffineTransform *tr0 = [NSAffineTransform transform]; [tr0 translateXBy: 0 yBy: -_scroll]; [tr0 concat];       /* the pane scrolls above the bar */
	if (th) { NSSize z = [th size]; CGFloat k = MIN(MIN(pr.size.width / z.width, pr.size.height / z.height), 2); NSRect tr = NSMakeRect(NSMidX(pr) - z.width * k / 2, NSMidY(pr) - z.height * k / 2, z.width * k, z.height * k); [NSGraphicsContext saveGraphicsState]; [[NSBezierPath bezierPathWithRoundedRect: tr xRadius: 10 yRadius: 10] addClip]; [th drawInRect: tr fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [NSGraphicsContext restoreGraphicsState]; }
	else TFDrawIcon(p, NSMakeRect(NSMidX(pr) - 64, NSMidY(pr) - 64, 128, 128));
	/* the name: up to two lines, the block ends at y 311 (AX: 273 x 44 at 267 for a long name, one line ends at the same place); the second line is shortened in the middle */
	{ NSString *nm = [p lastPathComponent]; NSDictionary *plain = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 14] }; if ([nm sizeWithAttributes: plain].width <= 273) [nm drawInRect: NSMakeRect(10, 292, 273, 20) withAttributes: tl];
		else { NSMutableString *l1 = [NSMutableString string]; NSArray *words = [nm componentsSeparatedByString: @" "]; NSUInteger used = 0; for (NSString *w in words) { NSString *t = [l1 length] ? [NSString stringWithFormat: @"%@ %@", l1, w] : w; if ([t sizeWithAttributes: plain].width > 273 && [l1 length]) break; [l1 setString: t]; used++; if ([l1 sizeWithAttributes: plain].width > 273) break; }
			NSString *rest = used < [words count] ? [[words subarrayWithRange: NSMakeRange(used, [words count] - used)] componentsJoinedByString: @" "] : @""; if (![rest length]) { NSUInteger n = [l1 length]; while (n > 1 && [[l1 substringToIndex: n] sizeWithAttributes: plain].width > 273) n--; rest = [l1 substringFromIndex: n]; [l1 setString: [l1 substringToIndex: n]]; }
			[l1 drawInRect: NSMakeRect(10, 270, 273, 20) withAttributes: tl]; [rest drawInRect: NSMakeRect(10, 292, 273, 20) withAttributes: tl]; } }
	[[NSString stringWithFormat: @"%@%@", TFKindString(p, dir), dir ? @"" : [@" - " stringByAppendingString: TFSizeString([at[NSFileSize] unsignedLongLongValue])]] drawInRect: NSMakeRect(9, 314, 275, 18) withAttributes: sub];
	[@"Information" drawAtPoint: NSMakePoint(9, 337 + 1) withAttributes: head]; if (img) { NSString *sm = _more ? @"Show Less" : @"Show More"; [sm drawAtPoint: NSMakePoint(284 - [sm sizeWithAttributes: Font(13, NO, TF_ACCENT)].width, 339) withAttributes: Font(13, NO, TF_ACCENT)]; }
	struct stat sb; NSDate *opened = at[NSFileModificationDate]; if (!stat([p fileSystemRepresentation], &sb)) opened = [NSDate dateWithTimeIntervalSince1970: sb.st_atime];
	NSMutableArray *rws = [NSMutableArray array]; if (TFPreviewOpt(@"created")) [rws addObject: @[ @"Created", LongDate(at[NSFileCreationDate]) ]]; if (TFPreviewOpt(@"modified")) [rws addObject: @[ @"Modified", LongDate(at[NSFileModificationDate]) ]]; if (TFPreviewOpt(@"lastOpened")) [rws addObject: @[ @"Last opened", LongDate(opened) ]]; NSArray *rows = rws; if (_more && img) { BOOL jpg = [@[ @"jpg", @"jpeg" ] containsObject: [[p pathExtension] lowercaseString]]; if (jpg) rows = [rows arrayByAddingObject: @[ @"Content created", LongDate(at[NSFileCreationDate]) ]]; else { NSBitmapImageRep *br = [[NSBitmapImageRep imageRepsWithContentsOfFile: p] firstObject]; if (br) rows = [rows arrayByAddingObject: @[ @"Dimensions", [NSString stringWithFormat: @"%ld × %ld", (long)[br pixelsWide], (long)[br pixelsHigh]] ]]; } }       /* Show More of a picture: "Content created" (the other rows depend on the kind and are not measured) */
	double y = 361;
	for (NSUInteger i = 0; i < [rows count]; i++) { NSArray *row = rows[i]; NSDictionary *la = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TF_DIM }, *va = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: TF_TEXT }; [row[0] drawAtPoint: NSMakePoint(9, y) withAttributes: la]; NSSize vs = [row[1] sizeWithAttributes: va]; [row[1] drawAtPoint: NSMakePoint(284 - vs.width, y) withAttributes: va];
		if (i + 1 < [rows count]) { [TFRGB(65, 67, 70) setFill]; NSRectFill(NSMakeRect(10, y + 19, 273, 1)); } y += 23; }
	double ty = y + 8;       /* "Tags" follows the rows by 8 (361 + 3 x 23 + 8 = 438 with the third row, 415 with two) */
	if (!TFPreviewOpt(@"tags")) { _content = ty; [NSGraphicsContext restoreGraphicsState]; [self _drawQuickBar: dir path: p]; return; }
	[@"Tags" drawAtPoint: NSMakePoint(9, ty + 1) withAttributes: head]; NSArray *tg = TFTagsOf(p); FillRound(NSMakeRect(10, ty + 23, 273, 33), 6, TFDark() ? TFRGBA(255, 255, 255, 0.05) : TFRGBA(0, 0, 0, 0.04)); [[tg count] ? [tg componentsJoinedByString: @", "] : @"Add Tags…" drawAtPoint: NSMakePoint(18, ty + 23 + 9) withAttributes: Font(13, NO, TF_DIM)];
	_content = ty + 23 + 33 + 12; [NSGraphicsContext restoreGraphicsState];
	[self _drawQuickBar: dir path: p];
}
@end

/* ---------- the root view: drops from other programs ---------- */
@implementation TFinderRoot
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) [self registerForDraggedTypes: @[ NSFilenamesPboardType ]]; return self; }
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender { return NSDragOperationCopy; }
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender { return NSDragOperationCopy; }
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender { return YES; }
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *paths = [[sender draggingPasteboard] propertyListForType: NSFilenamesPboardType]; if (![paths count]) return NO; id d = [[self window] delegate]; if (![d respondsToSelector: @selector(finderExternalDropPaths:atWindowPoint:)]) return NO;
	[d finderExternalDropPaths: paths atWindowPoint: [sender draggingLocation]]; return YES;
}
@end

/* ---------- the window ---------- */
@implementation TFinderWindow
- (BOOL)canBecomeKeyWindow { return YES; } - (BOOL)canBecomeMainWindow { return YES; }
static void RedrawTree(NSView *v) { [v setNeedsDisplay: YES]; for (NSView *k in [v subviews]) RedrawTree(k); }
- (void)_redrawTree { RedrawTree([[self contentView] superview] ?: [self contentView]); }
- (void)becomeKeyWindow { [super becomeKeyWindow]; [self _redrawTree]; [self performSelector: @selector(_redrawTree) withObject: nil afterDelay: 0.05]; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self _redrawTree]; [self performSelector: @selector(_redrawTree) withObject: nil afterDelay: 0.05]; }
- (BOOL)validateMenuItem:(NSMenuItem *)it { if ([it action] && [NSStringFromSelector([it action]) isEqual: @"performClose:"]) return YES; return [super validateMenuItem: it]; }       /* the window has no title bar (style mask 0): NSWindow would disable Close Window */
- (void)performClose:(id)s { if (getenv("FINDER_DEBUG")) NSLog(@"Finder: performClose on %@ (key %d)", self, (int)[self isKeyWindow]); if ([[self delegate] respondsToSelector: @selector(windowShouldClose:)] && ![(id)[self delegate] windowShouldClose: self]) return; [self close]; }
- (void)performMiniaturize:(id)s { _mini = YES; [self orderOut: nil]; [NSApp addWindowsItem: self title: [NSString stringWithFormat: @"%@ (minimised)", [self title] ?: @"Finder"] filename: NO]; }
- (void)miniaturize:(id)s { [self performMiniaturize: s]; }
- (void)deminiaturize:(id)s { _mini = NO; [self orderFront: nil]; [self makeKeyWindow]; }
- (BOOL)isMiniaturized { return _mini; }
- (void)zoom:(id)s { NSRect vf = [[NSScreen mainScreen] frame]; vf.size.height -= 30; if (_zoomed) { [self setFrame: _savedFrame display: YES]; _zoomed = NO; } else { _savedFrame = [self frame]; [self setFrame: vf display: YES]; _zoomed = YES; } }
- (void)performZoom:(id)s { [self zoom: s]; }
- (BOOL)isZoomed { return _zoomed; }
- (BOOL)performKeyEquivalent:(NSEvent *)e { if ([e type] == NSKeyDown && ![e modifierFlags] && [[e characters] isEqual: @" "]) return NO; return [super performKeyEquivalent: e]; }       /* a plain space is the views' (Quick Look), not a key equivalent of a control */
- (BOOL)wsdIsResizable { return YES; }       /* the window's edges are resized by the application (WsdResize.m), live, with plain events */
- (BOOL)wsdWantsMoveAt:(NSEvent *)e       /* a press on the toolbar's empty part moves the window (a double click zooms it: that one goes to sendEvent:) */
{
	if ([e clickCount] >= 2) return NO; NSPoint p = [e locationInWindow]; NSView *cv = [self contentView]; NSView *hit = [cv hitTest: [[cv superview] convertPoint: p fromView: nil]];
	return [hit respondsToSelector: @selector(isDragPoint:)] && [(id)hit isDragPoint: [hit convertPoint: p fromView: nil]];
}
- (void)_track:(int)m event:(NSEvent *)event                  /* m: 0 moves, else the edges (1 left, 2 right, 4 bottom, 8 top) */
{
	NSRect frame = [self frame]; NSPoint start = [NSEvent mouseLocation]; NSSize mn = [self minSize]; NSEvent *e = event; if (getenv("FINDER_DEBUG_KEY")) NSLog(@"window track mode %d from %@ frame %@", m, NSStringFromPoint(start), NSStringFromRect(frame));
	while ([e type] != NSLeftMouseUp) {
		e = [self nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		NSPoint now = [NSEvent mouseLocation]; CGFloat dx = now.x - start.x, dy = now.y - start.y; NSRect nf = frame;
		if (!m) nf.origin = NSMakePoint(frame.origin.x + dx, frame.origin.y + dy);
		else { if (m & 2) nf.size.width = frame.size.width + dx; if (m & 1) { nf.size.width = frame.size.width - dx; nf.origin.x = frame.origin.x + dx; } if (m & 8) nf.size.height = frame.size.height + dy; if (m & 4) { nf.size.height = frame.size.height - dy; nf.origin.y = frame.origin.y + dy; }
			if (nf.size.width < mn.width) { if (m & 1) nf.origin.x = NSMaxX(frame) - mn.width; nf.size.width = mn.width; } if (nf.size.height < mn.height) { if (m & 4) nf.origin.y = NSMaxY(frame) - mn.height; nf.size.height = mn.height; } }
		if (getenv("FINDER_DEBUG_KEY")) NSLog(@"window track: event %ld now %@ new frame %@", (long)[e type], NSStringFromPoint(now), NSStringFromRect(nf));
		if (!NSEqualRects(nf, [self frame])) [self setFrame: nf display: YES];
	}
}
- (void)sendEvent:(NSEvent *)e
{
	if (getenv("FINDER_KEYS") && [e type] == NSKeyDown) NSLog(@"Finder key: chars %@ ign %@ flags %lx code %d", [e characters], [e charactersIgnoringModifiers], (unsigned long)[e modifierFlags], (int)[e keyCode]);
	if ([e type] == NSKeyDown && ([e modifierFlags] & NSCommandKeyMask)) {                                                       /* Command-Delete: Move to Trash, with Shift: Empty Trash */
		NSString *k = [e charactersIgnoringModifiers]; unichar c = [k length] ? [k characterAtIndex: 0] : 0;
		if (c == 0x7f || c == 8 || c == NSDeleteFunctionKey || c == NSBackspaceCharacter) { [NSApp sendAction: ([e modifierFlags] & NSShiftKeyMask) ? @selector(cmdEmptyTrash:) : @selector(cmdMoveToTrash:) to: nil from: self]; return; } }
	if ([e type] == NSLeftMouseDown) {
		NSPoint p = [e locationInWindow]; NSRect b = [[self contentView] bounds]; int m = 0; const CGFloat ed = 5, co = 14;
		if (p.x < ed) m |= 1; if (p.x > b.size.width - ed) m |= 2; if (p.y < ed) m |= 4; if (p.y > b.size.height - ed) m |= 8;
		if (m == 1 || m == 2) { if (p.y < co) m |= 4; else if (p.y > b.size.height - co) m |= 8; } else if (m == 4 || m == 8) { if (p.x < co) m |= 1; else if (p.x > b.size.width - co) m |= 2; }
		if (m) { [self _track: m event: e]; return; }
		NSView *cv = [self contentView]; NSView *hit = [cv hitTest: [[cv superview] convertPoint: p fromView: nil]];
		if ([hit respondsToSelector: @selector(isDragPoint:)] && [(id)hit isDragPoint: [hit convertPoint: p fromView: nil]]) { if ([e clickCount] == 2) { [self performZoom: nil]; return; } [self _track: 0 event: e]; return; }
	}
	[super sendEvent: e];
}
@end
