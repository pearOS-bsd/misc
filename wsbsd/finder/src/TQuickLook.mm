/* Quick Look (space bar, File > Quick Look): a dark window with the file's name in the title, the picture, the beginning of the text, or the icon with kind and size. Space or Escape closes it. */
#import "TFinderViews.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TQLDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface TQuickLookView : NSView { @public NSString *path; NSImage *image; NSString *text; }
@end
@implementation TQuickLookView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 44; }
- (void)keyDown:(NSEvent *)e { NSString *k = [e characters]; if ([k isEqual: @" "] || [k isEqual: @"\033"]) { [[self window] close]; return; } [super keyDown: e]; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TFRGB(34, 34, 34) setFill]; NSRectFill(b); NSDictionary *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: TFRGB(235, 235, 235) }, *dim = @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: TFRGBA(255, 255, 255, 0.5) };
	NSString *t = [path lastPathComponent]; NSSize ts = [t sizeWithAttributes: head]; [t drawAtPoint: NSMakePoint(b.size.width / 2 - ts.width / 2, 15) withAttributes: head];
	NSRect area = NSMakeRect(24, 52, b.size.width - 48, b.size.height - 76);
	if (image) { NSSize z = [image size]; CGFloat k = MIN(MIN(area.size.width / z.width, area.size.height / z.height), 1.0 * 4); NSRect d = NSMakeRect(NSMidX(area) - z.width * k / 2, NSMidY(area) - z.height * k / 2, z.width * k, z.height * k); [image drawInRect: d fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
	else if (text) { NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByWordWrapping]; [TFRGB(250, 250, 250) setFill]; NSRectFill(area); [text drawInRect: NSInsetRect(area, 14, 12) withAttributes: @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize: 12], NSForegroundColorAttributeName: TFRGB(30, 30, 30), NSParagraphStyleAttributeName: ps }]; }
	else {
		NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: path error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && !TFIsPackage(path); CGFloat s = MIN(MIN(area.size.width, area.size.height - 80), 256);
		TFDrawIcon(path, NSMakeRect(NSMidX(area) - s / 2, area.origin.y + 10, s, s)); NSString *line = [NSString stringWithFormat: @"%@ - %@", TFKindString(path, dir), dir ? @"--" : TFSizeString([at[NSFileSize] unsignedLongLongValue])]; NSSize ls = [line sizeWithAttributes: dim]; [line drawAtPoint: NSMakePoint(NSMidX(area) - ls.width / 2, area.origin.y + s + 28) withAttributes: dim];
	}
}
@end

NSWindow *TFOpenQuickLook(NSString *path)
{
	static NSWindow *w; if (w && [w isVisible]) { BOOL same = [[(TQuickLookView *)[w contentView] valueForKey: @"path"] isEqual: path]; [w close]; if (same) return nil; }
	NSImage *img = nil; NSString *txt = nil; NSString *ext = [[path pathExtension] lowercaseString]; NSFileManager *fm = [NSFileManager defaultManager]; unsigned long long size = [[fm attributesOfItemAtPath: path error: NULL][NSFileSize] unsignedLongLongValue];
	if ([@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"tif", @"bmp" ] containsObject: ext] && size < 40000000) img = [[NSImage alloc] initWithContentsOfFile: path];
	else if (size < 4000000 && ![fm isExecutableFileAtPath: path]) { NSData *d = [NSData dataWithContentsOfFile: path]; if ([d length]) { NSData *head = [d subdataWithRange: NSMakeRange(0, MIN([d length], 6000))]; NSString *s = [[NSString alloc] initWithData: head encoding: NSUTF8StringEncoding]; if (s && ![s containsString: @"\0"]) txt = s; } }
	NSSize cs = img ? NSMakeSize(MIN(MAX([img size].width + 48, 360), 1100), MIN(MAX([img size].height + 76, 300), 720)) : txt ? NSMakeSize(640, 520) : NSMakeSize(420, 420); NSRect sf = [[NSScreen mainScreen] frame];
	w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(NSMidX(sf) - cs.width / 2, NSMidY(sf) - cs.height / 2 + 30, cs.width, cs.height) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(300, 240)];
	TQuickLookView *v = [[TQuickLookView alloc] initWithFrame: NSMakeRect(0, 0, cs.width, cs.height)]; v->path = [path copy]; v->image = img; v->text = txt; [v setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [w setContentView: v];
	TWindowTrim *trim = [[TWindowTrim alloc] initWithFrame: [v bounds]]; [trim setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [v addSubview: trim]; [w makeKeyAndOrderFront: nil]; [w makeFirstResponder: v]; [NSClassFromString(@"WsdFinderSupport") roundWindow: w radius: 16]; return w;
}
