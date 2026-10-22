#import "TFinderViews.h"
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TFDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface NSObject (WsdFinderSupport)
+ (void)roundWindow:(NSWindow *)w radius:(int)r;
+ (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c;
@end

NSString *TFSizeString(unsigned long long b) { return [NSByteCountFormatter stringFromByteCount: (long long)b countStyle: NSByteCountFormatterCountStyleFile]; }
NSString *TFDateString(NSDate *d)
{
	if (!d) return @""; NSCalendar *cal = [NSCalendar currentCalendar]; NSDateFormatter *tf = [[NSDateFormatter alloc] init]; [tf setDateFormat: @"HH:mm"]; NSString *t = [tf stringFromDate: d];
	if ([cal isDateInToday: d]) return [@"Today at " stringByAppendingString: t]; if ([cal isDateInYesterday: d]) return [@"Yesterday at " stringByAppendingString: t];
	NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"d MMM yyyy 'at' HH:mm"]; return [df stringFromDate: d];
}
NSString *TFKindString(NSString *path, BOOL dir)
{
	if (dir) return [[path pathExtension] isEqual: @"app"] ? @"Application" : @"Folder";
	NSString *ext = [path pathExtension]; NSString *u = [ext length] ? (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL) : nil;
	NSString *d = u && ![u hasPrefix: @"dyn."] ? (__bridge_transfer NSString *)UTTypeCopyDescription((__bridge CFStringRef)u) : nil; if ([d isKindOfClass: [NSString class]] && [d length]) return [[[d substringToIndex: 1] uppercaseString] stringByAppendingString: [d substringFromIndex: 1]];
	return [ext length] ? [NSString stringWithFormat: @"%@ document", [ext uppercaseString]] : @"Document";
}
BOOL TFSymbol(NSString *name, NSRect cell, CGFloat pt, NSColor *tint)
{
	Class k = NSClassFromString(@"WsdFinderSupport"); if (!k) return NO; return [k drawSymbol: name inRect: cell size: pt weight: 4 color: tint];
}
NSImage *TFIcon(NSString *path)
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary]; NSString *ext = [[path pathExtension] lowercaseString]; BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d];
	NSString *key = d || ![ext length] ? path : [@"." stringByAppendingString: ext]; NSImage *i = cache[key]; if (!i) { i = [[NSWorkspace sharedWorkspace] iconForFile: path]; if (i) cache[key] = i; } return i;
}
static NSString *Truncated(NSString *s, NSDictionary *at, CGFloat w)             /* the middle replaced by an ellipsis until it fits */
{
	if ([s sizeWithAttributes: at].width <= w) return s; NSUInteger n = [s length], keep = n;
	while (keep > 2) { keep--; NSUInteger a = (keep + 1) / 2, b = keep / 2; NSString *t = [NSString stringWithFormat: @"%@…%@", [s substringToIndex: a], [s substringFromIndex: n - b]]; if ([t sizeWithAttributes: at].width <= w) return t; }
	return @"…";
}
static NSArray *WrapLabel(NSString *s, NSDictionary *at, CGFloat w, int maxLines)   /* the name on at most two lines, the last one cut in the middle */
{
	NSMutableArray *lines = [NSMutableArray array]; NSString *rest = s;
	while ([rest length] && (int)[lines count] < maxLines - 1) {
		if ([rest sizeWithAttributes: at].width <= w) break; NSUInteger n = [rest length], cut = n;
		while (cut > 1 && [[rest substringToIndex: cut] sizeWithAttributes: at].width > w) cut--;
		NSRange sp = [[rest substringToIndex: cut] rangeOfCharacterFromSet: [NSCharacterSet characterSetWithCharactersInString: @" -_.,"] options: NSBackwardsSearch];
		if (sp.location != NSNotFound && sp.location > 3 && cut < n) cut = sp.location + 1;
		[lines addObject: [rest substringToIndex: cut]]; rest = [rest substringFromIndex: cut];
	}
	if ([rest length]) [lines addObject: Truncated(rest, at, w)]; return lines;
}
static void FillRound(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }
static BOOL KeyWin(NSView *v) { return [[v window] isKeyWindow]; }
static NSDictionary *Font(CGFloat sz, BOOL bold, NSColor *c) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: sz] : [NSFont systemFontOfSize: sz], NSForegroundColorAttributeName: c }; }
static void TextAt(NSString *s, CGFloat x, CGFloat cy, NSDictionary *at) { NSSize z = [s sizeWithAttributes: at]; [s drawAtPoint: NSMakePoint(x, cy - z.height / 2) withAttributes: at]; }

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
static const CGFloat kCW = 112, kCH = 126, kPad = 10, kIcon = 64;
@implementation TIconView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _items = [NSMutableArray array]; _sel = [NSMutableIndexSet indexSet]; _anchor = -1; } return self; }
- (void)setFolder:(NSString *)folder
{
	[_items removeAllObjects]; [_sel removeAllIndexes]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *names = [NSMutableArray array];
	for (NSString *n in [fm contentsOfDirectoryAtPath: folder error: NULL]) if (![n hasPrefix: @"."] && (![filter length] || [n rangeOfString: filter options: NSCaseInsensitiveSearch].location != NSNotFound)) [names addObject: n];
	for (NSString *n in [names sortedArrayUsingSelector: @selector(localizedStandardCompare:)]) {
		NSString *p = [folder stringByAppendingPathComponent: n]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && ![[p pathExtension] isEqual: @"app"]; NSString *info = @"";
		if (dir) { NSUInteger c = 0; for (NSString *s in [fm contentsOfDirectoryAtPath: p error: NULL]) if (![s hasPrefix: @"."]) c++; info = [NSString stringWithFormat: @"%lu item%s", (unsigned long)c, c == 1 ? "" : "s"]; }
		else if (![[p pathExtension] isEqual: @"app"]) info = TFSizeString([at[NSFileSize] unsignedLongLongValue]);
		[_items addObject: [@{ @"name": n, @"path": p, @"info": info } mutableCopy]];
	}
	off = 0; [self setNeedsDisplay: YES]; [self _notify];
}
- (void)reloadKeepingSelection { NSArray *keep = [self selectedPaths]; NSString *dir = [_items count] ? [_items[0][@"path"] stringByDeletingLastPathComponent] : nil; if (!dir) return; CGFloat o = off; [self setFolder: dir]; for (NSUInteger i = 0; i < [_items count]; i++) if ([keep containsObject: _items[i][@"path"]]) [_sel addIndex: i]; off = o; [self setNeedsDisplay: YES]; }
- (NSInteger)_cols { return MAX(1, (NSInteger)floor(([self bounds].size.width - 2 * kPad) / kCW)); }
- (CGFloat)contentHeight { NSInteger c = [self _cols]; return 2 * kPad + ceil((double)[_items count] / c) * kCH; }
- (NSRect)_cell:(NSInteger)i { NSInteger c = [self _cols]; return NSMakeRect(kPad + (i % c) * kCW, kPad + (i / c) * kCH, kCW, kCH); }
- (NSInteger)_index:(NSPoint)p { NSInteger c = [self _cols]; if (p.x < kPad || p.y < kPad) return -1; NSInteger col = (NSInteger)((p.x - kPad) / kCW), row = (NSInteger)((p.y - kPad) / kCH); if (col >= c) return -1; NSInteger i = row * c + col; return i < (NSInteger)[_items count] ? i : -1; }
- (void)drawContent:(NSRect)v
{
	NSDictionary *lab = Font(12, NO, TF_TEXT); NSDictionary *labSel = Font(12, NO, TFRGB(255, 255, 255)); NSDictionary *inf = Font(10.5, NO, TFDark() ? TFRGB(66, 140, 235) : TFRGB(0, 100, 220)); BOOL key = KeyWin(self);
	for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) {
		NSRect c = [self _cell: i]; if (NSMaxY(c) < v.origin.y || c.origin.y > NSMaxY(v)) continue; NSMutableDictionary *it = _items[i]; BOOL sel = [_sel containsIndex: i];
		NSRect ir = NSMakeRect(c.origin.x + 24, c.origin.y + 4, kIcon, kIcon);
		if (sel) FillRound(NSInsetRect(ir, -4, -4), 6, key ? TFRGBA(255, 255, 255, 0.14) : TFRGB(52, 52, 52));
		NSImage *icon = TFIcon(it[@"path"]); if (icon) [icon drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
		NSArray *lines = it[@"lines"]; if (!lines) { lines = WrapLabel(it[@"name"], lab, kCW - 12, 2); it[@"lines"] = lines; }
		CGFloat y = c.origin.y + 81; CGFloat lh = 16;
		for (NSString *ln in lines) {
			NSSize z = [ln sizeWithAttributes: lab]; if (sel) FillRound(NSMakeRect(NSMidX(c) - z.width / 2 - 5, y - 9, z.width + 10, 18), 5, key ? TF_ACCENT : TFRGB(90, 90, 90));
			[ln drawAtPoint: NSMakePoint(NSMidX(c) - z.width / 2, y - z.height / 2) withAttributes: sel ? labSel : lab]; y += lh;
		}
		if ([it[@"info"] length]) { NSSize z = [it[@"info"] sizeWithAttributes: inf]; [it[@"info"] drawAtPoint: NSMakePoint(NSMidX(c) - z.width / 2, y - z.height / 2 - 1) withAttributes: inf]; }
	}
}
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (NSArray *)selectedPaths { NSMutableArray *a = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { [a addObject: self->_items[i][@"path"]]; }]; return a; }
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e
{
	NSInteger i = [self _index: p]; NSUInteger fl = [e modifierFlags]; BOOL multi = (fl & NSCommandKeyMask) != 0;
	if (i >= 0) {
		NSRect c = [self _cell: i]; NSRect hit = NSMakeRect(c.origin.x + 12, c.origin.y, c.size.width - 24, 100); if (!NSPointInRect(p, hit)) i = -1;      /* the empty corners of a cell belong to the background */
	}
	if (i < 0) {                                                                                                                                  /* a rubber band over the background */
		NSIndexSet *base = multi ? [_sel copy] : [NSIndexSet indexSet]; NSPoint a = p; NSEvent *ev = e; [_sel removeAllIndexes]; [_sel addIndexes: base];
		while ([ev type] != NSLeftMouseUp) {
			ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
			NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; q.y = q.y - topInset + off; NSRect band = NSMakeRect(MIN(a.x, q.x), MIN(a.y, q.y), fabs(q.x - a.x), fabs(q.y - a.y));
			[_sel removeAllIndexes]; [_sel addIndexes: base]; for (NSInteger k = 0; k < (NSInteger)[_items count]; k++) { NSRect c = [self _cell: k]; if (NSIntersectsRect(band, NSMakeRect(c.origin.x + 24, c.origin.y + 4, kIcon, kIcon + 40))) [_sel addIndex: k]; }
			[self setNeedsDisplay: YES];
		}
		[self _notify]; return;
	}
	if (fl & NSShiftKeyMask && _anchor >= 0) { [_sel removeAllIndexes]; [_sel addIndexesInRange: NSMakeRange(MIN(_anchor, i), labs(i - _anchor) + 1)]; }
	else if (multi) { if ([_sel containsIndex: i]) [_sel removeIndex: i]; else [_sel addIndex: i]; _anchor = i; }
	else { if (![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; } _anchor = i; }
	[self setNeedsDisplay: YES]; [self _notify];
	if ([e clickCount] == 2 && [delegate respondsToSelector: @selector(iconViewOpenItem:)]) [delegate iconViewOpenItem: _items[i][@"path"]];
}
- (NSMenu *)menuForEvent:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSInteger i = [self _index: NSMakePoint(p.x, p.y - topInset + off)];
	if (i >= 0 && ![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; [self setNeedsDisplay: YES]; [self _notify]; } else if (i < 0) { [_sel removeAllIndexes]; [self setNeedsDisplay: YES]; [self _notify]; }
	return [self menu];
}
- (void)selectAll:(id)s { [_sel addIndexesInRange: NSMakeRange(0, [_items count])]; [self setNeedsDisplay: YES]; [self _notify]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0]; NSInteger cur = [_sel count] ? (NSInteger)[_sel lastIndex] : -1, n = (NSInteger)[_items count], cols = [self _cols], t = cur; NSUInteger fl = [e modifierFlags];
	if (c == NSLeftArrowFunctionKey) t = MAX(0, cur - 1); else if (c == NSRightArrowFunctionKey) t = cur < 0 ? 0 : MIN(n - 1, cur + 1);
	else if (c == NSUpArrowFunctionKey && !(fl & NSCommandKeyMask)) t = cur < 0 ? 0 : MAX(0, cur - cols); else if (c == NSDownArrowFunctionKey && !(fl & NSCommandKeyMask)) t = cur < 0 ? 0 : MIN(n - 1, cur + cols);
	else if ((c == '\r' || (c == NSDownArrowFunctionKey && (fl & NSCommandKeyMask))) && cur >= 0) { [delegate iconViewOpenItem: _items[cur][@"path"]]; return; }
	else if (c == NSUpArrowFunctionKey && (fl & NSCommandKeyMask)) { [NSApp sendAction: @selector(cmdOpenParent:) to: nil from: self]; return; }
	else if (isalnum(c) && !(fl & (NSCommandKeyMask | NSControlKeyMask))) {                                                                           /* type to select */
		static NSString *buf; static NSDate *last; if (!last || [[NSDate date] timeIntervalSinceDate: last] > 1) buf = @""; buf = [buf stringByAppendingString: [k lowercaseString]]; last = [NSDate date];
		for (NSInteger i = 0; i < n; i++) if ([[_items[i][@"name"] lowercaseString] hasPrefix: buf]) { t = i; break; }
	}
	else { [super keyDown: e]; return; }
	if (n) { [_sel removeAllIndexes]; [_sel addIndex: MAX(0, t)]; _anchor = MAX(0, t); [self reveal: [self _cell: MAX(0, t)]]; [self setNeedsDisplay: YES]; [self _notify]; }
}
@end

/* ---------- the list view ---------- */
static const CGFloat kRow = 24, kHead = 28;
@implementation TListView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _items = [NSMutableArray array]; _sel = [NSMutableIndexSet indexSet]; _sortKey = @"name"; _asc = YES; topInset = kHead; _anchor = -1; } return self; }
- (void)setFolder:(NSString *)folder
{
	[_items removeAllObjects]; [_sel removeAllIndexes]; NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *n in [fm contentsOfDirectoryAtPath: folder error: NULL]) @try {
		if ([n hasPrefix: @"."] || ([filter length] && [n rangeOfString: filter options: NSCaseInsensitiveSearch].location == NSNotFound)) continue;
		NSString *p = [folder stringByAppendingPathComponent: n]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && ![[p pathExtension] isEqual: @"app"];
		[_items addObject: @{ @"name": n, @"path": p, @"dir": @(dir), @"date": at[NSFileModificationDate] ?: [NSDate distantPast], @"size": dir ? @(-1) : at[NSFileSize] ?: @0, @"kind": TFKindString(p, dir) }];
	} @catch (NSException *x) { NSLog(@"TListView %@: %@", n, x); }
	[self _sort]; off = 0; [self setNeedsDisplay: YES]; [self _notify];
}
- (void)_sort { NSString *k = _sortKey; BOOL asc = _asc; NSArray *sorted = [_items sortedArrayUsingComparator: ^NSComparisonResult(NSDictionary *a, NSDictionary *b) { NSComparisonResult r = [k isEqual: @"name"] || [k isEqual: @"kind"] ? [a[k] localizedStandardCompare: b[k]] : [a[k] compare: b[k]]; return asc ? r : (NSComparisonResult)(-r); }]; if (getenv("FINDER_DEBUG")) NSLog(@"Finder: list sort %lu -> %lu", (unsigned long)[_items count], (unsigned long)[sorted count]); [_items setArray: sorted]; }
- (CGFloat)contentHeight { return [_items count] * kRow + 8; }
- (NSArray *)_cols { CGFloat w = [self bounds].size.width; CGFloat kind = 150, size = 90, date = 170; return @[ @[ @"name", @"Name", @0, @(w - kind - size - date - 14) ], @[ @"date", @"Date Modified", @(w - kind - size - date - 14), @(date) ], @[ @"size", @"Size", @(w - kind - size - 14), @(size) ], @[ @"kind", @"Kind", @(w - kind - 14), @(kind) ] ]; }
- (void)drawContent:(NSRect)v
{
	BOOL key = KeyWin(self); NSArray *cols = [self _cols]; CGFloat w = [self bounds].size.width;
	for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) {
		CGFloat y = 4 + i * kRow; if (y + kRow < v.origin.y || y > NSMaxY(v)) continue; NSDictionary *it = _items[i]; BOOL sel = [_sel containsIndex: i]; CGFloat cy = y + kRow / 2;
		if (sel) FillRound(NSMakeRect(8, y, w - 16 - 10, kRow), 6, key ? TF_ACCENT : TFRGB(70, 70, 70)); else if (i % 2) FillRound(NSMakeRect(8, y, w - 16 - 10, kRow), 6, TFDark() ? TFRGBA(255, 255, 255, 0.04) : TFRGBA(0, 0, 0, 0.04));
		NSColor *tc = sel ? TFRGB(255, 255, 255) : TF_TEXT, *dc = sel ? TFRGBA(255, 255, 255, 0.8) : TF_DIM; NSImage *ic = TFIcon(it[@"path"]); if (ic) [ic drawInRect: NSMakeRect(18, cy - 8, 16, 16) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
		for (NSArray *c in cols) {
			NSString *k = c[0], *s; CGFloat x = [c[2] doubleValue] + ([k isEqual: @"name"] ? 42 : 8), cw = [c[3] doubleValue] - ([k isEqual: @"name"] ? 50 : 16); NSDictionary *at = Font(13, NO, [k isEqual: @"name"] ? tc : dc);
			if ([k isEqual: @"name"]) s = it[@"name"]; else if ([k isEqual: @"date"]) s = TFDateString(it[@"date"]); else if ([k isEqual: @"size"]) s = [it[@"size"] longLongValue] < 0 ? @"--" : TFSizeString([it[@"size"] unsignedLongLongValue]); else s = it[@"kind"];
			s = Truncated(s, at, cw); if ([k isEqual: @"size"]) x += cw - [s sizeWithAttributes: at].width; TextAt(s, x, cy, at);
		}
	}
}
- (void)drawRect:(NSRect)r
{
	[super drawRect: r]; NSRect b = [self bounds]; [TF_CONTENT setFill]; NSRectFill(NSMakeRect(0, 0, b.size.width, kHead)); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, kHead - 1, b.size.width, 1));
	for (NSArray *c in [self _cols]) {
		NSString *k = c[0]; NSDictionary *at = Font(12, YES, TF_DIM); CGFloat x = [c[2] doubleValue] + ([k isEqual: @"name"] ? 42 : 8); TextAt(c[1], x, kHead / 2, at);
		if ([k isEqual: _sortKey]) TFSymbol(_asc ? @"chevron.up" : @"chevron.down", NSMakeRect(x + [c[1] sizeWithAttributes: at].width + 6, 0, 10, kHead), 9, TF_DIM);
		if (![k isEqual: @"name"]) { [TF_LINE setFill]; NSRectFill(NSMakeRect([c[2] doubleValue], 6, 1, kHead - 12)); }
	}
	NSRect th = [self thumbRect]; if (!NSIsEmptyRect(th)) FillRound(th, 5, TFDark() ? TFRGB(159, 159, 159) : TFRGBA(0, 0, 0, 0.35));
}
- (NSInteger)_row:(NSPoint)p { NSInteger i = (NSInteger)floor((p.y - 4) / kRow); return i >= 0 && i < (NSInteger)[_items count] ? i : -1; }
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (NSArray *)selectedPaths { NSMutableArray *a = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { [a addObject: self->_items[i][@"path"]]; }]; return a; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	if (p.y < kHead) { for (NSArray *c in [self _cols]) if (p.x >= [c[2] doubleValue] && p.x < [c[2] doubleValue] + [c[3] doubleValue]) { if ([_sortKey isEqual: c[0]]) _asc = !_asc; else { _sortKey = c[0]; _asc = YES; } [self _sort]; [self setNeedsDisplay: YES]; } return; }
	[super mouseDown: e];
}
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e
{
	NSInteger i = [self _row: p]; NSUInteger fl = [e modifierFlags]; if (i < 0) { [_sel removeAllIndexes]; [self setNeedsDisplay: YES]; [self _notify]; return; }
	if (fl & NSShiftKeyMask && _anchor >= 0) { [_sel removeAllIndexes]; [_sel addIndexesInRange: NSMakeRange(MIN(_anchor, i), labs(i - _anchor) + 1)]; }
	else if (fl & NSCommandKeyMask) { if ([_sel containsIndex: i]) [_sel removeIndex: i]; else [_sel addIndex: i]; _anchor = i; }
	else { if (![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; } _anchor = i; }
	[self setNeedsDisplay: YES]; [self _notify]; if ([e clickCount] == 2) [delegate iconViewOpenItem: _items[i][@"path"]];
}
- (NSMenu *)menuForEvent:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSInteger i = [self _row: NSMakePoint(p.x, p.y - topInset + off)]; if (i >= 0 && ![_sel containsIndex: i]) { [_sel removeAllIndexes]; [_sel addIndex: i]; [self setNeedsDisplay: YES]; [self _notify]; } return [self menu]; }
- (void)selectAll:(id)s { [_sel addIndexesInRange: NSMakeRange(0, [_items count])]; [self setNeedsDisplay: YES]; [self _notify]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0]; NSInteger cur = [_sel count] ? (NSInteger)[_sel lastIndex] : -1, n = (NSInteger)[_items count], t = cur;
	if (c == NSUpArrowFunctionKey) t = cur < 0 ? 0 : MAX(0, cur - 1); else if (c == NSDownArrowFunctionKey) t = cur < 0 ? 0 : MIN(n - 1, cur + 1); else if (c == '\r' && cur >= 0) { [delegate iconViewOpenItem: _items[cur][@"path"]]; return; } else { [super keyDown: e]; return; }
	if (n) { [_sel removeAllIndexes]; [_sel addIndex: t]; _anchor = t; [self reveal: NSMakeRect(0, 4 + t * kRow, 10, kRow)]; [self setNeedsDisplay: YES]; [self _notify]; }
}
@end

/* ---------- the sidebar ---------- */
@implementation TSidebarView
- (instancetype)initWithFrame:(NSRect)f
{
	if ((self = [super initWithFrame: f])) {
		NSString *home = NSHomeDirectory(); NSMutableArray *r = [NSMutableArray array];
		void (^item)(NSString *, NSString *, NSString *) = ^(NSString *t, NSString *sym, NSString *p) { [r addObject: @{ @"k": @"item", @"t": t, @"s": sym, @"p": p ?: @"" }]; };
		void (^head)(NSString *) = ^(NSString *t) { [r addObject: @{ @"k": @"head", @"t": t }]; };
		item(@"Recents", @"clock", @"recents://"); item(@"Shared", @"person.2", @"shared://");
		head(@"Favorites"); item(@"Applications", @"a.square", @"/Applications"); item(@"Desktop", @"menubar.dock.rectangle", [home stringByAppendingPathComponent: @"Desktop"]); item(@"Documents", @"doc", [home stringByAppendingPathComponent: @"Documents"]); item(@"Downloads", @"arrow.down.circle", [home stringByAppendingPathComponent: @"Downloads"]);
		head(@"Locations"); item(@"iCloud Drive", @"icloud", [home stringByAppendingPathComponent: @"Library/Mobile Documents/com~apple~CloudDocs"]); item(NSUserName(), @"house", home); item(@"Macintosh HD", @"internaldrive", @"/"); item(@"AirDrop", @"airdrop", @"airdrop://"); item(@"Trash", @"trash", [home stringByAppendingPathComponent: @".Trash"]);
		head(@"Tags"); for (NSString *t in @[ @"Red", @"Orange", @"Yellow", @"Green", @"Blue", @"Purple", @"Gray" ]) [r addObject: @{ @"k": @"tag", @"t": t, @"p": [@"tag://" stringByAppendingString: t] }];
		item(@"All Tags…", @"", @"tags://"); _rows = r;
	}
	return self;
}
- (void)drawBackground { [TF_SIDEBAR setFill]; NSRectFill([self bounds]); }
- (NSRect)_rect:(NSInteger)i                                          /* rows 32 apart from y 52, a section header 19 high with 13 above it */
{
	CGFloat y = 52; for (NSInteger k = 0; k <= i; k++) { BOOL head = [_rows[k][@"k"] isEqual: @"head"]; if (head) { y += 13; if (k == i) return NSMakeRect(15, y, [self bounds].size.width - 30, 19); y += 19; } else { if (k == i) return NSMakeRect(10, y, [self bounds].size.width - 37, 32); y += 32; } }
	return NSZeroRect;
}
- (CGFloat)contentHeight { return NSMaxY([self _rect: (NSInteger)[_rows count] - 1]) + 12; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 52; }
static NSColor *TagColorFor(NSString *n) { NSDictionary *c = @{ @"Red": TFRGB(255, 69, 58), @"Orange": TFRGB(255, 159, 10), @"Yellow": TFRGB(255, 214, 10), @"Green": TFRGB(48, 209, 88), @"Blue": TFRGB(10, 132, 255), @"Purple": TFRGB(191, 90, 242), @"Gray": TFRGB(152, 152, 157) }; return c[n]; }
- (void)drawContent:(NSRect)v
{
	BOOL key = KeyWin(self); NSColor *tint = key ? TF_BLUE : TFRGB(150, 150, 150);
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) {
		NSDictionary *it = _rows[i]; NSRect r = [self _rect: i]; if (NSMaxY(r) < v.origin.y || r.origin.y > NSMaxY(v)) continue; NSString *k = it[@"k"];
		if ([k isEqual: @"head"]) { TextAt(it[@"t"], r.origin.x, NSMidY(r), Font(11, YES, TFDark() ? TFRGBA(255, 255, 255, 0.40) : TFRGBA(0, 0, 0, 0.45))); continue; }
		BOOL cur = [it[@"p"] length] && [current isEqual: it[@"p"]]; if (cur) FillRound(r, 11, key ? TFRGBA(255, 255, 255, 0.13) : TFRGB(51, 51, 51));
		NSRect ic = NSMakeRect(18, NSMidY(r) - 11, 22, 22);
		if ([k isEqual: @"tag"]) { [TagColorFor(it[@"t"]) setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(22, NSMidY(r) - 6, 13, 13)] fill]; }
		else if ([it[@"t"] isEqual: @"All Tags…"]) { [[NSColor colorWithCalibratedWhite: 0.6 alpha: 1] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(21, NSMidY(r) - 5, 10, 10)] fill]; [[NSColor colorWithCalibratedWhite: 0.45 alpha: 1] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(27, NSMidY(r) - 5, 10, 10)] fill]; }
		else if (![it[@"s"] length] || !TFSymbol(it[@"s"], ic, 15, tint)) { }
		TextAt(it[@"t"], 45, NSMidY(r), Font(13, NO, TF_TEXT));
	}
}
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e
{
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if (![_rows[i][@"k"] isEqual: @"head"] && NSPointInRect(p, [self _rect: i])) { NSString *path = _rows[i][@"p"]; if ([path hasPrefix: @"/"]) [delegate sidebarGoTo: path]; return; }
}
@end

/* ---------- the path bar ---------- */
@implementation TPathBarView
- (BOOL)isFlipped { return YES; }
- (void)setPath:(NSString *)p { path = [p copy]; NSMutableArray *a = [NSMutableArray array]; NSString *q = p; while (YES) { [a insertObject: q atIndex: 0]; if ([q isEqual: @"/"]) break; q = [q stringByDeletingLastPathComponent]; if (![q length]) break; } _paths = a; [self setNeedsDisplay: YES]; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_PATHBAR setFill]; NSRectFill(b); [TF_LINE setFill]; NSRectFill(NSMakeRect(0, 0, b.size.width, 1)); _rects = [NSMutableArray array]; CGFloat x = 5; NSDictionary *at = Font(11, NO, TF_TEXT);
	for (NSString *p in _paths) {
		NSString *name = [p isEqual: @"/"] ? @"Macintosh HD" : [p lastPathComponent]; CGFloat tw = [name sizeWithAttributes: at].width, w = tw + 34; NSImage *ic = TFIcon(p);
		if (ic) [ic drawInRect: NSMakeRect(x + 6, 8, 14, 14) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; TextAt(name, x + 24, 15, at);
		if (p != [_paths lastObject]) TFSymbol(@"chevron.right", NSMakeRect(x + w - 12, 0, 8, 30), 8, TF_DIM);
		[_rects addObject: [NSValue valueWithRect: NSMakeRect(x, 0, w, 30)]]; x += w;
	}
}
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSUInteger i = 0; i < [_rects count]; i++) if (NSPointInRect(p, [_rects[i] rectValue])) { [delegate pathBarGoTo: _paths[i]]; return; } }
@end

/* ---------- the toolbar ---------- */
@implementation TToolbarView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSRect)_pill:(int)k                    /* 0 nav, 1 modes, 2 group, 3 actions, 4 search: anchored at the right, 38 high 7 from the top */
{
	CGFloat w = [self bounds].size.width, sw = searching ? 200 : 38, x = w - 7 - sw; if (k == 4) return NSMakeRect(x, 7, sw, 38);
	x -= 8 + 108; if (k == 3) return NSMakeRect(x, 7, 108, 38); x -= 8 + 47; if (k == 2) return NSMakeRect(x, 7, 47, 38); x -= 8 + 162; if (k == 1) return NSMakeRect(x, 7, 162, 38);
	return NSMakeRect(7, 7, 75, 38);
}
- (void)setSearching:(BOOL)on
{
	searching = on; if (!search) { search = [[NSTextField alloc] initWithFrame: NSZeroRect]; [search setBordered: NO]; [search setBezeled: NO]; [search setDrawsBackground: NO]; [search setFont: [NSFont systemFontOfSize: 13]]; [search setTextColor: TF_TEXT]; [search setFocusRingType: NSFocusRingTypeNone]; [search setDelegate: (id)self]; [self addSubview: search]; }
	NSRect p = [self _pill: 4]; [search setFrame: NSMakeRect(p.origin.x + 32, 14, p.size.width - 44, 22)]; [search setHidden: !on]; if (on) [[self window] makeFirstResponder: search]; else [search setStringValue: @""]; [self setNeedsDisplay: YES];
}
- (void)controlTextDidChange:(NSNotification *)n { [target performSelector: @selector(searchChanged:) withObject: [search stringValue]]; }
- (void)setFrameSize:(NSSize)s { [super setFrameSize: s]; if (searching) { NSRect p = [self _pill: 4]; [search setFrame: NSMakeRect(p.origin.x + 32, 14, p.size.width - 44, 22)]; } }
- (void)drawRect:(NSRect)r
{
	[TF_SIDEBAR setFill]; NSRectFill([self bounds]); NSColor *t = TF_TEXT; NSRect nav = [self _pill: 0]; FillRound(nav, 19, TF_PILL);
	[TF_LINE setFill]; NSRectFill(NSMakeRect(NSMidX(nav), 17, 1, 18));
	TFSymbol(@"chevron.left", NSMakeRect(nav.origin.x, 7, 37, 38), 15, canBack ? t : TFRGBA(255, 255, 255, 0.25)); TFSymbol(@"chevron.right", NSMakeRect(NSMidX(nav), 7, 37, 38), 15, canForward ? t : TFRGBA(255, 255, 255, 0.25));
	TextAt(title ?: @"", 94, 26, Font(13, YES, t));
	NSRect md = [self _pill: 1]; FillRound(md, 19, TF_PILL); NSArray *syms = @[ @"square.grid.2x2", @"list.bullet", @"rectangle.split.3x1", @"square.grid.3x1.below.line.grid.1x2" ]; CGFloat sw = md.size.width / 4;
	for (int k = 0; k < 4; k++) { NSRect c = NSMakeRect(md.origin.x + k * sw, 7, sw, 38); if (k == mode) FillRound(NSInsetRect(c, 2, 2), 17, TFDark() ? TFRGB(88, 88, 88) : TFRGB(214, 214, 218)); TFSymbol(syms[k], c, 15, t); }
	NSRect gr = [self _pill: 2]; FillRound(gr, 19, TF_PILL); for (int a = 0; a < 3; a++) for (int c = 0; c < 3; c++) { [t setFill]; NSRectFill(NSMakeRect(gr.origin.x + 9 + a * 5, 20 + c * 5, 3, 3)); }
	TFSymbol(@"chevron.down", NSMakeRect(NSMaxX(gr) - 20, 7, 12, 38), 9, TF_DIM);
	NSRect ac = [self _pill: 3]; FillRound(ac, 19, TF_PILL); CGFloat aw = ac.size.width / 3;
	TFSymbol(@"square.and.arrow.up", NSMakeRect(ac.origin.x, 7, aw, 38), 15, t); TFSymbol(@"tag", NSMakeRect(ac.origin.x + aw, 7, aw, 38), 15, t);
	NSRect e = NSMakeRect(ac.origin.x + 2 * aw, 7, aw, 38); for (int k = 0; k < 3; k++) { [t setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(NSMidX(e) - 7 + k * 6, 24, 3, 3)] fill]; }
	NSRect sr = [self _pill: 4]; FillRound(sr, 19, TF_PILL); TFSymbol(@"magnifyingglass", NSMakeRect(sr.origin.x, 7, searching ? 34 : sr.size.width, 38), 15, searching ? TF_DIM : t);
	if (searching && ![[search stringValue] length] && [[self window] firstResponder] != [search currentEditor]) TextAt(@"Search", sr.origin.x + 34, 26, Font(13, NO, TF_DIM));
}
- (BOOL)isDragPoint:(NSPoint)p { for (int k = 0; k < 5; k++) if (NSPointInRect(p, [self _pill: k])) return NO; return YES; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSRect nav = [self _pill: 0], md = [self _pill: 1];
	if (NSPointInRect(p, nav)) { if (p.x < NSMidX(nav)) { if (canBack) [NSApp sendAction: @selector(cmdBack:) to: target from: self]; } else if (canForward) [NSApp sendAction: @selector(cmdForward:) to: target from: self]; return; }
	if (NSPointInRect(p, md)) { SEL a[4] = { @selector(cmdViewAsIcons:), @selector(cmdViewAsList:), @selector(cmdViewAsColumns:), @selector(cmdViewAsGallery:) }; [NSApp sendAction: a[(int)((p.x - md.origin.x) / (md.size.width / 4)) & 3] to: target from: self]; return; }
	NSRect ac = [self _pill: 3]; if (NSPointInRect(p, ac)) { if (p.x > ac.origin.x + 2 * ac.size.width / 3) { NSMenu *m = [target performSelector: @selector(actionMenu)]; [NSMenu popUpContextMenu: m withEvent: e forView: self]; } return; }
	if (NSPointInRect(p, [self _pill: 4]) && !searching) [NSApp sendAction: @selector(cmdToggleSearch:) to: target from: self];
}
@end

/* ---------- the trim on top: the window buttons, the rim ---------- */
@implementation TWindowTrim
- (BOOL)isFlipped { return YES; } - (BOOL)isOpaque { return NO; }
- (NSRect)_light:(int)k { return NSMakeRect(19 + 23 * k, 19, 14, 14); }
- (NSView *)hitTest:(NSPoint)p { NSPoint q = [self convertPoint: p fromView: [self superview]]; for (int k = 0; k < 3; k++) if (NSPointInRect(q, NSInsetRect([self _light: k], -4, -4))) return self; return nil; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)drawRect:(NSRect)r
{
	BOOL key = KeyWin(self); NSRect b = [self bounds]; NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(b, 0.5, 0.5) xRadius: 16 yRadius: 16]; [TFDark() ? TFRGBA(255, 255, 255, 0.20) : TFRGBA(0, 0, 0, 0.22) setStroke]; [rim setLineWidth: 1]; [rim stroke];
	NSColor *cols[3] = { TFRGB(255, 95, 87), TFRGB(254, 188, 46), TFRGB(40, 200, 64) };
	for (int k = 0; k < 3; k++) { NSRect c = [self _light: k]; [(key ? cols[k] : (TFDark() ? TFRGB(76, 76, 76) : TFRGB(205, 205, 205))) setFill]; [[NSBezierPath bezierPathWithOvalInRect: c] fill]; [TFRGBA(0, 0, 0, 0.12) setStroke]; [[NSBezierPath bezierPathWithOvalInRect: NSInsetRect(c, 0.5, 0.5)] stroke]; }
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (int k = 0; k < 3; k++) if (NSPointInRect(p, NSInsetRect([self _light: k], -4, -4))) {
		NSEvent *ev = e; while ([ev type] != NSLeftMouseUp) ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		if (NSPointInRect([self convertPoint: [ev locationInWindow] fromView: nil], NSInsetRect([self _light: k], -4, -4))) { if (k == 0) [[self window] performClose: self]; else if (k == 1) [[self window] performMiniaturize: self]; else [[self window] performZoom: self]; } return;
	}
}
@end

/* ---------- the window ---------- */
@implementation TFinderWindow
- (BOOL)canBecomeKeyWindow { return YES; } - (BOOL)canBecomeMainWindow { return YES; }
- (void)_track:(int)m event:(NSEvent *)event                  /* m: 0 moves, else the edges (1 left, 2 right, 4 bottom, 8 top) */
{
	NSRect frame = [self frame]; NSPoint start = [NSEvent mouseLocation]; NSSize mn = [self minSize]; NSEvent *e = event;
	while ([e type] != NSLeftMouseUp) {
		e = [self nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		NSPoint now = [NSEvent mouseLocation]; CGFloat dx = now.x - start.x, dy = now.y - start.y; NSRect nf = frame;
		if (!m) nf.origin = NSMakePoint(frame.origin.x + dx, frame.origin.y + dy);
		else { if (m & 2) nf.size.width = frame.size.width + dx; if (m & 1) { nf.size.width = frame.size.width - dx; nf.origin.x = frame.origin.x + dx; } if (m & 8) nf.size.height = frame.size.height + dy; if (m & 4) { nf.size.height = frame.size.height - dy; nf.origin.y = frame.origin.y + dy; }
			if (nf.size.width < mn.width) { if (m & 1) nf.origin.x = NSMaxX(frame) - mn.width; nf.size.width = mn.width; } if (nf.size.height < mn.height) { if (m & 4) nf.origin.y = NSMaxY(frame) - mn.height; nf.size.height = mn.height; } }
		if (!NSEqualRects(nf, [self frame])) [self setFrame: nf display: YES];
	}
}
- (void)sendEvent:(NSEvent *)e
{
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
