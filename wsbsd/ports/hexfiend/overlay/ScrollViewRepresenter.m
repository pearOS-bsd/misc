/* Port of ScrollViewRepresenter.swift */
#import "Hex_Fiend-Swift.h"

@interface ScrollViewRepresenterDocumentView : NSView
- (instancetype)initWithRepresenter: (ScrollViewRepresenter *)representer hexRep: (HFHexTextRepresenter *)hexRep;
- (void)addHexRep;
@end

@implementation ScrollViewRepresenter {
	HFHexTextRepresenter *hexRep;
	ScrollViewRepresenterDocumentView *documentView;
}

- (instancetype)init { if ((self = [super init])) hexRep = [[HFHexTextRepresenter alloc] init]; return self; }

- (NSView *)createView
{
	NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
	[scrollView setAutoresizingMask: NSViewHeightSizable];
	[scrollView setBorderType: NSNoBorder];
	[scrollView setDrawsBackground: NO];
	[scrollView setHasVerticalScroller: YES];
	[scrollView setUsesPredominantAxisScrolling: YES];
	documentView = [[ScrollViewRepresenterDocumentView alloc] initWithRepresenter: self hexRep: hexRep];
	[scrollView setDocumentView: documentView];
	return scrollView;
}

- (void)controllerDidChange: (HFControllerPropertyBits)bits
{
	if (bits == (HFControllerPropertyBits)-1 && documentView && [hexRep controller] == nil && [self controller]) {
		[[self controller] addRepresenter: hexRep];
		[documentView addHexRep];
	}
}

- (CGFloat)minimumViewWidthForBytesPerLine: (NSUInteger)bytesPerLine { return [hexRep minimumViewWidthForBytesPerLine: bytesPerLine]; }
+ (NSPoint)defaultLayoutPosition { return NSMakePoint(5, 0); }
@end

@implementation ScrollViewRepresenterDocumentView {
	__weak ScrollViewRepresenter *representer;
	HFHexTextRepresenter *hexRep;
	BOOL showingHexRep;
}

- (instancetype)initWithRepresenter: (ScrollViewRepresenter *)r hexRep: (HFHexTextRepresenter *)h
{
	if ((self = [super initWithFrame: NSZeroRect])) { representer = r; hexRep = h; }
	return self;
}

- (void)addHexRep { [self addSubview: [hexRep view]]; showingHexRep = YES; [self updateFrame]; }

- (void)updateFrame
{
	NSScrollView *sv = [self enclosingScrollView];
	if (!sv) return;
	NSRect f = [self frame]; f.size = NSMakeSize([sv frame].size.width, 1000); [self setFrame: f];
	if (!showingHexRep || ![hexRep controller]) return;
	NSView *view = [hexRep view]; NSRect vf = [self bounds];
	vf.size.width = [hexRep minimumViewWidthForBytesPerLine: [[hexRep controller] bytesPerLine]];
	[view setFrame: vf];
}

- (void)viewDidMoveToSuperview { [super viewDidMoveToSuperview]; [self updateFrame]; }
- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	dispatch_async(dispatch_get_main_queue(), ^{ [self scrollPoint: NSMakePoint(0, [self bounds].size.height)]; });
}
@end
