/* Quick Look (space bar, File > Quick Look): a dark window with the file's name in the title, the picture, the beginning of the text, or the icon with kind and size. Space or Escape closes it. */
#import "TFinderViews.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TQLDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface TQuickLookView : NSView { @public NSString *path; NSImage *image; NSString *text; }
@end
@implementation TQuickLookView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 44; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; if (NSPointInRect(p, NSMakeRect(7, 8, 22, 22))) [[self window] close]; }       /* the close button of the panel: the only one that acts (the grey one beside it is the Mac's disabled full-screen button) */
- (void)keyDown:(NSEvent *)e { NSString *k = [e characters]; if ([k isEqual: @" "] || [k isEqual: @"\033"]) { [[self window] close]; return; } [super keyDown: e]; }
- (void)drawRect:(NSRect)r
{
	/* measured on the Mac (AX + pixels): a glass panel with corners of about 22; for a text file 816 x 849: the content (30,30,30) is 806 x 806, 5 in from the sides and the bottom and 38 down; the close button (an x in a circle) and the grey disabled one are 14 x 14 at (11, 12) and (31, 12), the name (bold 13) at 51, Share 34 x 26 at the right (7 in) and "Open with ..." as a pill 140 x 26 left of it; for a folder or a file without a preview 575 x 328: the icon 256 x 256 at (20, 48), the name (bold, about 20) at (298, 128) with the size and the date below in grey */
	NSRect b = [self bounds]; BOOL preview = image || text; CGFloat W = b.size.width, H = b.size.height;
	[[NSColor clearColor] setFill]; NSRectFill(b);
	NSBezierPath *panel = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(b, 0.5, 0.5) xRadius: 22 yRadius: 22]; [(preview ? TFRGBA(62, 70, 84, 0.96) : TFRGBA(58, 62, 70, 0.9)) setFill]; [panel fill]; [TFRGBA(255, 255, 255, 0.18) setStroke]; [panel setLineWidth: 1]; [panel stroke];
	NSDictionary *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: TFRGB(240, 240, 240) }, *dim = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TFRGBA(255, 255, 255, 0.6) };
	for (int k = 0; k < 2; k++) { NSRect c = NSMakeRect(11 + 20 * k, 12, 14, 14); [TFRGBA(255, 255, 255, k ? 0.28 : 0.55) setFill]; [[NSBezierPath bezierPathWithOvalInRect: c] fill]; [TFRGB(58, 62, 70) setStroke]; NSBezierPath *x = [NSBezierPath bezierPath]; [x setLineWidth: 1.6]; if (k == 0) { [x moveToPoint: NSMakePoint(15, 16)]; [x lineToPoint: NSMakePoint(21, 22)]; [x moveToPoint: NSMakePoint(21, 16)]; [x lineToPoint: NSMakePoint(15, 22)]; } else { [x appendBezierPath: [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(35.5, 16.5, 7, 7)]]; [x moveToPoint: NSMakePoint(36.5, 22.5)]; [x lineToPoint: NSMakePoint(41.5, 17.5)]; } [x stroke]; }
	CGFloat right = W - 7 - 34; TFSymbol(@"square.and.arrow.up", NSMakeRect(right, 6, 34, 26), 13, TFRGBA(255, 255, 255, 0.85));
	NSString *t = [path lastPathComponent];
	if (preview) {
		[t drawAtPoint: NSMakePoint(51, 11) withAttributes: head];
		NSString *app = TFAppsForFile(path).count ? TFAppsForFile(path)[0][@"name"] : nil; if (app) { NSString *lab = [@"Open with " stringByAppendingString: app]; NSSize ls = [lab sizeWithAttributes: head]; CGFloat pw = MAX(140, ls.width + 28); NSRect pill = NSMakeRect(right - 6 - pw, 6, pw, 26); [TFRGBA(255, 255, 255, 0.14) setFill]; [[NSBezierPath bezierPathWithRoundedRect: pill xRadius: 13 yRadius: 13] fill]; [lab drawAtPoint: NSMakePoint(NSMidX(pill) - ls.width / 2, NSMidY(pill) - ls.height / 2) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TFRGB(240, 240, 240) }]; }
		NSRect area = NSMakeRect(5, 38, W - 10, H - 43); NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect: area xRadius: 6 yRadius: 6]; [NSGraphicsContext saveGraphicsState]; [clip addClip]; [TFRGB(30, 30, 30) setFill]; NSRectFill(area);
		if (image) { NSSize z = [image size]; CGFloat k = MIN(MIN(area.size.width / z.width, area.size.height / z.height), 4); NSRect d = NSMakeRect(NSMidX(area) - z.width * k / 2, NSMidY(area) - z.height * k / 2, z.width * k, z.height * k); [image drawInRect: d fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
		else { NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByWordWrapping]; [text drawInRect: NSInsetRect(area, 4, 2) withAttributes: @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize: 11], NSForegroundColorAttributeName: TFRGB(235, 235, 235), NSParagraphStyleAttributeName: ps }]; }
		[NSGraphicsContext restoreGraphicsState];
	} else {
		NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: path error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && !TFIsPackage(path);
		TFDrawIcon(path, NSMakeRect(20, 48, 256, 256));
		[t drawAtPoint: NSMakePoint(298, 128) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 20], NSForegroundColorAttributeName: TFRGB(245, 245, 245) }];
		NSString *l1 = dir ? [NSString stringWithFormat: @"%@, %lu items", TFSizeString([at[NSFileSize] unsignedLongLongValue]), (unsigned long)[[fm contentsOfDirectoryAtPath: path error: NULL] count]] : [NSString stringWithFormat: @"%@ - %@", TFKindString(path, dir), TFSizeString([at[NSFileSize] unsignedLongLongValue])]; [l1 drawAtPoint: NSMakePoint(298, 160) withAttributes: dim];
		NSString *l2 = [NSString stringWithFormat: @"Last modified %@", TFDateString(at[NSFileModificationDate])]; [l2 drawAtPoint: NSMakePoint(298, 182) withAttributes: dim];
	}
}
@end

NSWindow *TFOpenQuickLook(NSString *path)
{
	static NSWindow *w; if (w && [w isVisible]) { BOOL same = [[(TQuickLookView *)[w contentView] valueForKey: @"path"] isEqual: path]; [w close]; if (same) return nil; }
	NSImage *img = nil; NSString *txt = nil; NSString *ext = [[path pathExtension] lowercaseString]; NSFileManager *fm = [NSFileManager defaultManager]; unsigned long long size = [[fm attributesOfItemAtPath: path error: NULL][NSFileSize] unsignedLongLongValue];
	if ([@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"tif", @"bmp" ] containsObject: ext] && size < 40000000) img = [[NSImage alloc] initWithContentsOfFile: path];
	else if (size < 4000000 && ![fm isExecutableFileAtPath: path]) { NSData *d = [NSData dataWithContentsOfFile: path]; if ([d length]) { NSData *head = [d subdataWithRange: NSMakeRange(0, MIN([d length], 6000))]; NSString *s = [[NSString alloc] initWithData: head encoding: NSUTF8StringEncoding]; if (s && ![s containsString: @"\0"]) txt = s; } }
	NSSize cs = img ? NSMakeSize(MIN(MAX([img size].width + 10, 360), 1100), MIN(MAX([img size].height + 43, 300), 800)) : txt ? NSMakeSize(816, MIN(849, [[NSScreen mainScreen] frame].size.height - 80)) : NSMakeSize(575, 328); NSRect sf = [[NSScreen mainScreen] frame];
	w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(NSMidX(sf) - cs.width / 2, NSMidY(sf) - cs.height / 2 + 30, cs.width, cs.height) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(300, 240)];
	TQuickLookView *v = [[TQuickLookView alloc] initWithFrame: NSMakeRect(0, 0, cs.width, cs.height)]; v->path = [path copy]; v->image = img; v->text = txt; [v setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [w setContentView: v];
	[w makeKeyAndOrderFront: nil]; [w makeFirstResponder: v]; [NSClassFromString(@"WsdFinderSupport") roundWindow: w radius: 22]; return w;
}
