/* TDesktopView / TDesktopWindowController: the desktop shows the items of ~/Desktop as icons with their names in columns from the top right (the default arrangement of the Finder); a double click opens an item. */
#import "TDesktopWindow.h"

@interface TDesktopView : NSView { NSArray<NSString *> *_names; NSString *_folder; NSInteger _selected; }
- (instancetype)initWithFrame:(NSRect)f folder:(NSString *)folder;
- (void)reload;
@end
@implementation TDesktopView
static const CGFloat kCellW = 100, kCellH = 100, kIcon = 64, kMargin = 20;
- (instancetype)initWithFrame:(NSRect)f folder:(NSString *)folder { if ((self = [super initWithFrame: f])) { _folder = [folder copy]; _selected = -1; [self reload]; } return self; }
- (BOOL)isFlipped { return YES; }
- (void)reload
{
	NSMutableArray *a = [NSMutableArray array]; for (NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: _folder error: NULL]) if (![n hasPrefix: @"."]) [a addObject: n];
	_names = [a sortedArrayUsingSelector: @selector(localizedStandardCompare:)]; [self setNeedsDisplay: YES];
}
/* the cell of item i: columns from the right edge, top to bottom */
- (NSRect)cellForIndex:(NSInteger)i
{
	NSInteger perColumn = MAX(1, (NSInteger)(([self bounds].size.height - 2 * kMargin - 30) / kCellH)); NSInteger col = i / perColumn, row = i % perColumn;
	return NSMakeRect([self bounds].size.width - kMargin - (col + 1) * kCellW, 30 + kMargin + row * kCellH, kCellW, kCellH);
}
- (void)drawRect:(NSRect)r
{
	NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: [NSColor whiteColor] };
	for (NSInteger i = 0; i < (NSInteger)[_names count]; i++) {
		NSRect c = [self cellForIndex: i]; if (!NSIntersectsRect(c, r)) continue; NSString *name = _names[i], *path = [_folder stringByAppendingPathComponent: name];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile: path]; NSRect ir = NSMakeRect(NSMidX(c) - kIcon / 2, c.origin.y + 6, kIcon, kIcon);
		if (icon) [icon drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
		NSRect lr = NSMakeRect(c.origin.x + 4, NSMaxY(ir) + 4, c.size.width - 8, 32);
		if (i == _selected) { [[NSColor colorWithCalibratedRed: 0.1 green: 0.35 blue: 0.8 alpha: 0.9] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(lr, 0, 0) xRadius: 4 yRadius: 4] fill]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.25] setFill]; [[NSBezierPath bezierPathWithRoundedRect: ir xRadius: 6 yRadius: 6] fill]; }
		NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setAlignment: NSTextAlignmentCenter]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
		NSMutableDictionary *a2 = [at mutableCopy]; a2[NSParagraphStyleAttributeName] = ps; NSShadow *sh = [[NSShadow alloc] init]; [sh setShadowOffset: NSMakeSize(0, -1)]; [sh setShadowBlurRadius: 2]; [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.8]]; a2[NSShadowAttributeName] = sh;
		[name drawInRect: lr withAttributes: a2];
	}
}
- (NSInteger)indexAtPoint:(NSPoint)p { for (NSInteger i = 0; i < (NSInteger)[_names count]; i++) if (NSPointInRect(p, [self cellForIndex: i])) return i; return -1; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)mouseDown:(NSEvent *)e
{
	NSInteger i = [self indexAtPoint: [self convertPoint: [e locationInWindow] fromView: nil]]; _selected = i; [self setNeedsDisplay: YES];
	if (i >= 0 && [e clickCount] == 2) [[NSWorkspace sharedWorkspace] openFile: [_folder stringByAppendingPathComponent: _names[i]]];
}
@end

@interface TDesktopWindowController : NSObject { TDesktopWindow *_window; TDesktopView *_view; }
+ (instancetype)sharedController;
- (void)showDesktop;
@end
@implementation TDesktopWindowController
+ (instancetype)sharedController { static id s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [[self alloc] init]; }); return s; }
- (void)showDesktop
{
	@try { [self _showDesktop]; } @catch (NSException *e) { NSLog(@"Finder: showDesktop failed: %@ %@ %@", [e name], [e reason], [e callStackSymbols]); }
}
- (void)_showDesktop
{
	if (_window) return; NSScreen *screen = [NSScreen mainScreen]; NSLog(@"Finder: showDesktop screen %@ frame %@", screen, NSStringFromRect([screen frame])); _window = [[TDesktopWindow alloc] initWithScreen: screen];
	_view = [[TDesktopView alloc] initWithFrame: [[_window contentView] bounds] folder: [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"]]; [_view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [[_window contentView] addSubview: _view];
	[_window orderBack: nil];
}
@end
