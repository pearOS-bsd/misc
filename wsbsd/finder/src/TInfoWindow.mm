/* Get Info: the inspector of an item (icon, name, size, tags, General, More Info, Name & Extension, Sharing & Permissions), in the window of the Finder (borderless, rounded, buttons on top). */
#import "TFinderViews.h"
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TInfoDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface TInfoView : NSView { @public NSString *path; }
@end
@implementation TInfoView
- (BOOL)isFlipped { return YES; }
- (BOOL)isDragPoint:(NSPoint)p { return p.y < 52; }
static NSString *Perm(mode_t m, int shift) { int b = (m >> shift) & 7; return (b & 6) == 6 ? @"Read & Write" : (b & 4) ? @"Read only" : (b & 2) ? @"Write only" : @"No Access"; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_SIDEBAR setFill]; NSRectFill(b); NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: path error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && ![[path pathExtension] isEqual: @"app"];
	NSDictionary *tx = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TF_TEXT }, *dim = @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: TF_DIM }, *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: TF_TEXT };
	NSString *title = [[path lastPathComponent] stringByAppendingString: @" Info"]; NSSize ts = [title sizeWithAttributes: head]; [title drawAtPoint: NSMakePoint(b.size.width / 2 - ts.width / 2, 19) withAttributes: head];
	TFDrawIcon(path, NSMakeRect(24, 62, 56, 56)); NSString *name = [path lastPathComponent]; [name drawAtPoint: NSMakePoint(92, 70) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 15], NSForegroundColorAttributeName: TF_TEXT }];
	unsigned long long size = [at[NSFileSize] unsignedLongLongValue]; [dir ? @"Folder" : TFSizeString(size) drawAtPoint: NSMakePoint(92, 94) withAttributes: dim];
	CGFloat y = 138; NSArray *tags = TFTagsOf(path); if ([tags count]) { [NSClassFromString(@"WsdFinderSupport") drawTagDots: tags rightEdge: 104 centerY: y + 8]; [[tags componentsJoinedByString: @", "] drawAtPoint: NSMakePoint(112, y) withAttributes: dim]; y += 28; }
	struct stat sb; stat([path fileSystemRepresentation], &sb); struct passwd *pw = getpwuid(sb.st_uid); struct group *gr = getgrgid(sb.st_gid);
	NSArray *sections = @[
		@[ @"General:", @[ @[ @"Kind:", TFKindString(path, dir) ], @[ @"Size:", dir ? @"--" : [NSString stringWithFormat: @"%@ (%llu bytes)", TFSizeString(size), size] ], @[ @"Where:", [path stringByDeletingLastPathComponent] ], @[ @"Created:", TFDateString(at[NSFileCreationDate]) ], @[ @"Modified:", TFDateString(at[NSFileModificationDate]) ] ] ],
		@[ @"Name & Extension:", @[ @[ @"", name ], @[ @"", [[path pathExtension] length] ? @"Extension is shown" : @"No extension" ] ] ],
		@[ @"Sharing & Permissions:", @[ @[ @"", pw ? [NSString stringWithFormat: @"%s  (Me)", pw->pw_name] : @"owner" ], @[ @"Owner:", Perm(sb.st_mode, 6) ], @[ @"Group:", [NSString stringWithFormat: @"%s  %@", gr ? gr->gr_name : "group", Perm(sb.st_mode, 3)] ], @[ @"Everyone:", Perm(sb.st_mode, 0) ] ] ] ];
	for (NSArray *sec in sections) {
		[TF_LINE setFill]; NSRectFill(NSMakeRect(20, y - 6, b.size.width - 40, 1)); TFSymbol(@"chevron.down", NSMakeRect(18, y, 14, 18), 9, TF_DIM); [sec[0] drawAtPoint: NSMakePoint(34, y) withAttributes: head]; y += 28;
		for (NSArray *row in sec[1]) {
			NSSize ls = [row[0] sizeWithAttributes: dim]; [row[0] drawAtPoint: NSMakePoint(104 - ls.width, y) withAttributes: dim];
			NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle]; [row[1] drawInRect: NSMakeRect(112, y, b.size.width - 126, 16) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: TF_TEXT, NSParagraphStyleAttributeName: ps }]; y += 22;
		}
		y += 10;
	}
	(void)tx;
}
@end

NSWindow *TFOpenInfoWindow(NSString *path)
{
	static NSMutableDictionary *open; if (!open) open = [NSMutableDictionary dictionary]; NSWindow *old = open[path]; if (old && [old isVisible]) { [old makeKeyAndOrderFront: nil]; return old; }
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(420 + 22 * [open count] % 120, 180, 310, 520) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(280, 300)];
	TInfoView *v = [[TInfoView alloc] initWithFrame: NSMakeRect(0, 0, 310, 520)]; v->path = [path copy]; [w setContentView: v]; [v setAutoresizesSubviews: YES];
	TWindowTrim *trim = [[TWindowTrim alloc] initWithFrame: [v bounds]]; [trim setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [v addSubview: trim];
	open[path] = w; [w makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: w radius: 16]; return w;
}
