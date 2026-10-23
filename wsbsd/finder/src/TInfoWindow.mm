/* Get Info, laid out after the Mac's own window (400 wide, measured on macOS 27): the header with icon, name, size and modification, the tag field, and the sections General, More Info, Name & Extension, Comments,
 * Open with, Preview and Sharing & Permissions, each folded or unfolded by its header. The comment is kept in the extended attribute com.apple.metadata:kMDItemFinderComment, the permissions are the file's mode. */
#import "TFinderViews.h"
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/extattr.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TInfoDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
static NSColor *C(int v) { return TFDark() ? TFRGB(v, v, v) : TFRGB(255 - v, 255 - v, 255 - v); }
static NSDictionary *Fo(CGFloat sz, BOOL bold, NSColor *c) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: sz] : [NSFont systemFontOfSize: sz], NSForegroundColorAttributeName: c }; }
static void Rnd(NSRect r, CGFloat rad, NSColor *f, NSColor *s) { NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad]; if (f) { [f setFill]; [p fill]; } if (s) { [s setStroke]; [p setLineWidth: 1]; [p stroke]; } }
static NSString *Perm(mode_t m, int shift) { int b = (m >> shift) & 7; return (b & 6) == 6 ? @"Read & Write" : (b & 4) ? @"Read only" : (b & 2) ? @"Write only" : @"No Access"; }
static NSString *CommentOf(NSString *p) { char buf[4096]; ssize_t n = extattr_get_file([p fileSystemRepresentation], EXTATTR_NAMESPACE_USER, "com.apple.metadata:kMDItemFinderComment", buf, sizeof buf); if (n <= 0) return @""; id pl = [NSPropertyListSerialization propertyListWithData: [NSData dataWithBytes: buf length: (NSUInteger)n] options: 0 format: NULL error: NULL]; return [pl isKindOfClass: [NSString class]] ? pl : @""; }
static void SetComment(NSString *p, NSString *c) { if (![c length]) { extattr_delete_file([p fileSystemRepresentation], EXTATTR_NAMESPACE_USER, "com.apple.metadata:kMDItemFinderComment"); return; } NSData *d = [NSPropertyListSerialization dataWithPropertyList: c format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL]; if (d) extattr_set_file([p fileSystemRepresentation], EXTATTR_NAMESPACE_USER, "com.apple.metadata:kMDItemFinderComment", [d bytes], [d length]); }
static NSString *Prompt(NSString *title, NSString *initial, BOOL multi)
{
	NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: title]; NSTextField *f = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 320, multi ? 80 : 24)]; [f setStringValue: initial ?: @""]; [a setAccessoryView: f]; [a addButtonWithTitle: @"OK"]; [a addButtonWithTitle: @"Cancel"];
	return [a runModal] == NSAlertFirstButtonReturn ? [f stringValue] : nil;
}

@interface TInfoView : NSView { @public NSString *path; NSMutableSet *folded; CGFloat scroll, total; NSMutableArray *_hits; }
@end
@implementation TInfoView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 36; }
- (void)scrollWheel:(NSEvent *)e { CGFloat mx = MAX(0, total - [self bounds].size.height); scroll = MAX(0, MIN(mx, scroll - [e deltaY] * 24)); [self setNeedsDisplay: YES]; }
- (void)drawRect:(NSRect)r { @try { [self _draw: r]; } @catch (NSException *x) { NSLog(@"Finder: Get Info draw: %@ %@", [x name], [x reason]); } }
- (void)_draw:(NSRect)r
{
	NSRect b = [self bounds]; CGFloat W = b.size.width; [C(27) setFill]; NSRectFill(b); _hits = [NSMutableArray array]; if (!folded) folded = [NSMutableSet setWithObjects: @"Comments", @"Open with", @"Preview", nil];
	NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: path error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && ![[path pathExtension] isEqual: @"app"]; unsigned long long size = [at[NSFileSize] unsignedLongLongValue];
	struct stat sb; stat([path fileSystemRepresentation], &sb); NSColor *t = C(235), *dim = TFDark() ? TFRGBA(255, 255, 255, 0.55) : TFRGBA(0, 0, 0, 0.55), *line = C(49);
	/* the title bar */
	NSString *title = [[path lastPathComponent] stringByAppendingString: @" Info"]; NSDictionary *th = Fo(13, YES, t); NSString *tt = title; while ([tt sizeWithAttributes: th].width > W - 190 && [tt length] > 8) tt = [[tt substringToIndex: [tt length] - 4] stringByAppendingString: @"…"]; NSSize ts = [tt sizeWithAttributes: th]; TFDrawIcon(path, NSMakeRect(W / 2 - ts.width / 2 - 20, 12, 14, 14)); [tt drawAtPoint: NSMakePoint(W / 2 - ts.width / 2, 12) withAttributes: th];
	NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; NSRectClip(NSMakeRect(0, 36, W, b.size.height - 36)); NSAffineTransform *tr = [NSAffineTransform transform]; [tr translateXBy: 0 yBy: -scroll]; [tr concat];
	CGFloat y = 44;
	/* the header */
	TFDrawIcon(path, NSMakeRect(14, y + 2, 32, 32)); NSString *nm = [path lastPathComponent]; NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle]; NSString *sz = dir ? @"--" : TFSizeString(size); if ([sz hasSuffix: @"bytes"]) sz = size ? [NSString stringWithFormat: @"%llu bytes", size] : @"Zero KB";
	NSSize zs = [sz sizeWithAttributes: Fo(13, YES, t)]; [sz drawAtPoint: NSMakePoint(W - 14 - zs.width, y + 2) withAttributes: Fo(13, YES, t)]; [nm drawInRect: NSMakeRect(52, y + 2, W - 80 - zs.width, 17) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: t, NSParagraphStyleAttributeName: ps }];
	[[@"Modified: " stringByAppendingString: TFDateString(at[NSFileModificationDate])] drawAtPoint: NSMakePoint(52, y + 20) withAttributes: Fo(11, NO, dim)]; y += 42;
	NSRect tagBox = NSMakeRect(7, y, W - 14, 32); Rnd(tagBox, 3, nil, C(53)); NSArray *tags = TFTagsOf(path); if ([tags count]) { double wdt = [NSClassFromString(@"WsdFinderSupport") tagDotsWidth: tags]; [NSClassFromString(@"WsdFinderSupport") drawTagDots: tags rightEdge: 12 + wdt centerY: y + 16]; [[tags componentsJoinedByString: @", "] drawAtPoint: NSMakePoint(12 + wdt + 6, y + 9) withAttributes: Fo(12, NO, t)]; } else [@"Add Tags..." drawAtPoint: NSMakePoint(8, y + 9) withAttributes: Fo(12, NO, dim)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: tagBox], @"a": @"tags" }]; y += 38;
	/* sections */
	NSArray *secs = @[ @"General", @"More Info", @"Name & Extension", @"Comments", @"Open with", @"Preview", @"Sharing & Permissions" ];
	for (NSString *sec in secs) {
		[line setFill]; NSRectFill(NSMakeRect(0, y, W, 1)); BOOL open = ![folded containsObject: sec]; NSRect hr = NSMakeRect(0, y, W, 24); TFSymbolW(open ? @"chevron.down" : @"chevron.right", NSMakeRect(7, y + 3, 14, 18), 8, 6, dim); [[sec stringByAppendingString: @":"] drawAtPoint: NSMakePoint(22, y + 6) withAttributes: Fo(11, YES, t)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: hr], @"a": @"fold", @"s": sec }]; y += 26;
		if (!open) { y += 2; continue; }
		if ([sec isEqual: @"General"]) {
			NSMutableArray *rows = [NSMutableArray array]; [rows addObject: @[ @"Kind:", TFKindString(path, dir) ]]; [rows addObject: @[ @"Size:", dir ? @"--" : [NSString stringWithFormat: @"%@ (%llu bytes on disk)", size ? TFSizeString(size) : @"Zero bytes", (unsigned long long)sb.st_blocks * 512] ]];
			NSMutableArray *chain = [NSMutableArray array]; NSString *q = [path stringByDeletingLastPathComponent]; while ([q length] && ![q isEqual: @"/"]) { [chain insertObject: TFDisplayName(q) atIndex: 0]; q = [q stringByDeletingLastPathComponent]; } [chain insertObject: @"Macintosh HD" atIndex: 0]; [rows addObject: @[ @"Where:", [chain componentsJoinedByString: @" ▸ "] ]];
			NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"EEEE, d MMMM yyyy 'at' HH:mm"]; [rows addObject: @[ @"Created:", [df stringFromDate: at[NSFileCreationDate]] ?: @"" ]]; [rows addObject: @[ @"Modified:", [df stringFromDate: at[NSFileModificationDate]] ?: @"" ]];
			for (NSArray *row in rows) { NSSize ls = [row[0] sizeWithAttributes: Fo(11, NO, dim)]; [row[0] drawAtPoint: NSMakePoint(100 - ls.width, y) withAttributes: Fo(11, NO, dim)]; NSMutableParagraphStyle *p2 = [[NSMutableParagraphStyle alloc] init]; [p2 setLineBreakMode: NSLineBreakByTruncatingMiddle]; [row[1] drawInRect: NSMakeRect(106, y, W - 116, 14) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: t, NSParagraphStyleAttributeName: p2 }]; y += 14.4; }
			y += 8; BOOL locked = (sb.st_flags & UF_IMMUTABLE) != 0; for (NSArray *cb in @[ @[ @"Stationery pad", @NO ], @[ @"Locked", @(locked) ] ]) { NSRect box = NSMakeRect(58, y, 14, 14); Rnd(box, 4, [cb[1] boolValue] ? TF_ACCENT : C(45), C(60)); if ([cb[1] boolValue]) TFSymbol(@"checkmark", box, 9, TFRGB(255, 255, 255)); [cb[0] drawAtPoint: NSMakePoint(80, y) withAttributes: Fo(11, NO, t)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: NSInsetRect(box, -2, -2)], @"a": [cb[0] isEqual: @"Locked"] ? @"lock" : @"none" }]; y += 20; }
			y += 4;
		} else if ([sec isEqual: @"More Info"]) { [@"Last opened:" drawAtPoint: NSMakePoint(14, y) withAttributes: Fo(11, YES, t)]; NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"EEEE, d MMMM yyyy 'at' HH:mm"]; [[df stringFromDate: at[@"NSFileAccessDate"] ?: at[NSFileModificationDate]] ?: @"" drawAtPoint: NSMakePoint(88, y) withAttributes: Fo(11, NO, t)]; y += 22; }
		else if ([sec isEqual: @"Name & Extension"]) { NSRect f = NSMakeRect(13, y, W - 26, 24); Rnd(f, 6, C(23), C(40)); [nm drawInRect: NSMakeRect(f.origin.x + 6, y + 5, f.size.width - 12, 16) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: t, NSParagraphStyleAttributeName: ps }]; [_hits addObject: @{ @"r": [NSValue valueWithRect: f], @"a": @"rename" }]; y += 38; NSRect box = NSMakeRect(16, y, 14, 14); Rnd(box, 4, C(45), C(60)); [@"Hide extension" drawAtPoint: NSMakePoint(38, y) withAttributes: Fo(11, NO, t)]; y += 26; }
		else if ([sec isEqual: @"Comments"]) { NSRect f = NSMakeRect(4, y, W - 8, 62); Rnd(f, 3, C(30), C(53)); [CommentOf(path) drawInRect: NSInsetRect(f, 6, 4) withAttributes: Fo(11, NO, t)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: f], @"a": @"comment" }]; y += 72; }
		else if ([sec isEqual: @"Open with"]) { NSArray *apps = TFAppsForFile(path); NSString *an = [apps count] ? apps[0][@"name"] : @"None"; NSRect pill = NSMakeRect(14, y, W - 28, 20); Rnd(pill, 5, C(45), nil); if ([apps count]) TFDrawIcon(apps[0][@"path"], NSMakeRect(20, y + 2, 16, 16)); [[NSString stringWithFormat: @"%@%@", an, [apps count] ? @" (default)" : @""] drawAtPoint: NSMakePoint(40, y + 3) withAttributes: Fo(11, NO, t)]; TFSymbol(@"chevron.up.chevron.down", NSMakeRect(NSMaxX(pill) - 22, y, 16, 20), 8, dim); y += 30; [@"Use this application to open all documents like this one." drawAtPoint: NSMakePoint(14, y) withAttributes: Fo(11, NO, t)]; y += 20; Rnd(NSMakeRect(14, y, 86, 20), 5, C(40), nil); [@"Change All…" drawAtPoint: NSMakePoint(24, y + 3) withAttributes: Fo(11, NO, TFDark() ? TFRGBA(255, 255, 255, 0.3) : TFRGBA(0, 0, 0, 0.3))]; y += 30; }
		else if ([sec isEqual: @"Preview"]) { NSImage *th = nil; NSString *ext = [[path pathExtension] lowercaseString]; if ([@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"bmp" ] containsObject: ext]) th = [[NSImage alloc] initWithContentsOfFile: path]; CGFloat s = 100; NSRect pr = NSMakeRect(W / 2 - s / 2, y + 4, s, s); if (th && [th size].width > 0) { NSSize z = [th size]; CGFloat k = MIN(s * 1.6 / z.width, s / z.height); [th drawInRect: NSMakeRect(W / 2 - z.width * k / 2, y + 4 + (s - z.height * k) / 2, z.width * k, z.height * k) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; } else TFDrawIcon(path, pr); y += s + 20; }
		else if ([sec isEqual: @"Sharing & Permissions"]) {
			struct passwd *pw = getpwuid(sb.st_uid); struct group *gr = getgrgid(sb.st_gid); BOOL canW = access([path fileSystemRepresentation], W_OK) == 0; [canW ? @"You can read and write" : @"You can only read"  drawAtPoint: NSMakePoint(14, y) withAttributes: Fo(11, NO, t)]; y += 20;
			NSRect tb = NSMakeRect(14, y, W - 28, 112); Rnd(tb, 0, C(38), C(53)); [C(35) setFill]; NSRectFill(NSMakeRect(tb.origin.x + 1, y + 1, tb.size.width - 2, 22)); [@"Name" drawAtPoint: NSMakePoint(24, y + 5) withAttributes: Fo(11, YES, t)]; [@"Privilege" drawAtPoint: NSMakePoint(tb.origin.x + 202, y + 5) withAttributes: Fo(11, YES, t)]; [C(53) setFill]; NSRectFill(NSMakeRect(tb.origin.x + 190, y + 1, 1, tb.size.height - 2));
			NSArray *rows = @[ @[ pw ? [NSString stringWithFormat: @"%s (Me)", pw->pw_name] : @"owner", Perm(sb.st_mode, 6), @6, @"person.circle" ], @[ gr ? @(gr->gr_name) : @"group", Perm(sb.st_mode, 3), @3, @"person.2" ], @[ @"everyone", Perm(sb.st_mode, 0), @0, @"person.2" ] ]; CGFloat ry = y + 24;
			for (NSUInteger i = 0; i < 3; i++) { NSArray *row = rows[i]; if (i % 2 == 0) { [C(41) setFill]; NSRectFill(NSMakeRect(tb.origin.x + 1, ry, tb.size.width - 2, 16)); } TFSymbol(row[3], NSMakeRect(tb.origin.x + 4, ry, 16, 16), 11, t); [row[0] drawAtPoint: NSMakePoint(tb.origin.x + 26, ry + 2) withAttributes: Fo(11, NO, t)]; [row[1] drawAtPoint: NSMakePoint(tb.origin.x + 202, ry + 2) withAttributes: Fo(11, NO, t)]; TFSymbol(@"chevron.up.chevron.down", NSMakeRect(NSMaxX(tb) - 22, ry, 16, 16), 8, dim); [_hits addObject: @{ @"r": [NSValue valueWithRect: NSMakeRect(tb.origin.x + 190, ry, tb.size.width - 190, 16)], @"a": @"perm", @"sh": row[2] }]; ry += 16; }
			y += 124; }
	}
	total = y + 20; [g restoreGraphicsState];
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; p.y += scroll; if (p.y < 36 + scroll) return;
	for (NSDictionary *h in _hits) if (NSPointInRect(p, [h[@"r"] rectValue])) { NSString *a = h[@"a"];
		if ([a isEqual: @"fold"]) { if ([folded containsObject: h[@"s"]]) [folded removeObject: h[@"s"]]; else [folded addObject: h[@"s"]]; [self setNeedsDisplay: YES]; return; }
		if ([a isEqual: @"lock"]) { struct stat sb; stat([path fileSystemRepresentation], &sb); chflags([path fileSystemRepresentation], (sb.st_flags & UF_IMMUTABLE) ? (sb.st_flags & ~UF_IMMUTABLE) : (sb.st_flags | UF_IMMUTABLE)); [self setNeedsDisplay: YES]; return; }
		if ([a isEqual: @"comment"]) { NSString *c = Prompt(@"Comments", CommentOf(path), YES); if (c) { SetComment(path, c); [self setNeedsDisplay: YES]; } return; }
		if ([a isEqual: @"rename"]) { NSString *n = Prompt(@"Name & Extension", [path lastPathComponent], NO); if ([n length] && ![n containsString: @"/"] && ![n isEqual: [path lastPathComponent]]) { NSString *to = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: n]; if ([[NSFileManager defaultManager] moveItemAtPath: path toPath: to error: NULL]) { path = to; [self setNeedsDisplay: YES]; } } return; }
		if ([a isEqual: @"tags"]) { NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; Class sp = NSClassFromString(@"WsdFinderSupport"); NSArray *cur = TFTagsOf(path); for (NSString *n in [sp tagNames]) { NSMenuItem *it = [m addItemWithTitle: n action: @selector(_tag:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: n]; [it setTag: 1]; [it setState: [cur containsObject: n] ? NSOnState : NSOffState]; } TFPopupMenu(self, NSMakePoint(14, [h[@"r"] rectValue].origin.y + 34 - scroll), m); return; }
		if ([a isEqual: @"perm"]) { int sh = [h[@"sh"] intValue]; NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (NSArray *o in @[ @[ @"Read & Write", @6 ], @[ @"Read only", @4 ], @[ @"Write only", @2 ], @[ @"No Access", @0 ] ]) { NSMenuItem *it = [m addItemWithTitle: o[0] action: @selector(_perm:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: @[ @(sh), o[1] ]]; } NSRect r = [h[@"r"] rectValue]; TFPopupMenu(self, NSMakePoint(r.origin.x, NSMaxY(r) - scroll), m); return; }
	}
}
- (void)_tag:(NSMenuItem *)it { NSMutableArray *cur = [TFTagsOf(path) mutableCopy]; NSString *n = [it representedObject]; if ([cur containsObject: n]) [cur removeObject: n]; else [cur addObject: n]; TFSetTags(cur, path); [self setNeedsDisplay: YES]; }
- (void)_perm:(NSMenuItem *)it { NSArray *a = [it representedObject]; int sh = [a[0] intValue], bits = [a[1] intValue]; struct stat sb; if (stat([path fileSystemRepresentation], &sb)) return; mode_t m = (sb.st_mode & 07777 & ~(7 << sh)) | (mode_t)(bits << sh); chmod([path fileSystemRepresentation], m); [self setNeedsDisplay: YES]; }
@end

NSWindow *TFOpenInfoWindow(NSString *path)
{
	static NSMutableDictionary *open; if (!open) open = [NSMutableDictionary dictionary]; NSWindow *old = open[path]; if (old && [old isVisible]) { [old makeKeyAndOrderFront: nil]; return old; }
	CGFloat sh = [[NSScreen mainScreen] frame].size.height; CGFloat H = MIN(928, sh - 90);
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(420 + 22 * ([open count] % 5), sh - H - 50 - 22 * ([open count] % 5), 400, H) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(400, 300)]; [w setMaxSize: NSMakeSize(400, 1400)];
	TInfoView *v = [[TInfoView alloc] initWithFrame: NSMakeRect(0, 0, 400, H)]; v->path = [path copy]; [w setContentView: v]; [v setAutoresizesSubviews: YES];
	TWindowTrim *trim = [[TWindowTrim alloc] initWithFrame: [v bounds]]; [trim setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [v addSubview: trim];
	open[path] = w; [w makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: w radius: 16]; return w;
}
