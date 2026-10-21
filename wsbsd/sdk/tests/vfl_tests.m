/* Visual Format Language strings of real applications: every one parses (no exception) and the constraints of the simple ones solve to the sizes Apple's engine gives */
#import <Cocoa/Cocoa.h>
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface Gutter : NSView { @public NSSize sz; } @end
@implementation Gutter - (NSSize)intrinsicContentSize { return sz; } - (BOOL)isFlipped { return YES; } @end
static NSView *V(void) { NSView *v = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 10, 10)]; [v setTranslatesAutoresizingMaskIntoConstraints: NO]; return v; }
static BOOL Parses(NSString *fmt, NSDictionary *views, NSLayoutFormatOptions o)
{
	@try { NSArray *a = [NSLayoutConstraint constraintsWithVisualFormat: fmt options: o metrics: nil views: views]; return [a count] > 0; }
	@catch (NSException *e) { printf("  exception for %s: %s\n", [fmt UTF8String], [[e reason] UTF8String]); return NO; }
}
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSDictionary *v = @{ @"line": V(), @"selection": V(), @"dividerOne": V(), @"grammar": V(), @"dividerTwo": V(), @"tabSize": V(), @"dividerThree": V(), @"items": V(), @"dividerFour": V(), @"symbol": V(), @"dividerFive": V(), @"recording": V() };
		CHECK(Parses(@"H:|-10-[line]-[selection(>=50,<=225)]-8-[dividerOne(==1)]-2-[grammar(>=125@400,>=50,<=225)]-5-[dividerTwo(==1)]-2-[tabSize]-4-[dividerThree(==1)]-5-[items(==31)]-4-[dividerFour(==1)]-2-[symbol(>=125@450,>=50)]-5-[dividerFive(==1)]-6-[recording]-7-|", v, 0));
		CHECK(Parses(@"H:[line]-[selection]-(>=1)-[grammar]-(>=1)-[tabSize]-(>=1)-[symbol]", v, NSLayoutFormatAlignAllBaseline));
		CHECK(Parses(@"H:[selection]-(>=1)-[dividerOne]-(>=1)-[dividerTwo]-(>=1)-[dividerThree]-(>=1)-[items]-(>=1)-[dividerFour]-(>=1)-[dividerFive]-(>=1)-[recording]", v, NSLayoutFormatAlignAllCenterY));
		CHECK(Parses(@"V:|-5-[dividerOne(==15,==dividerTwo,==dividerThree,==dividerFour,==dividerFive)]-5-|", v, 0));
		CHECK(Parses(@"H:|-(3@53)-[line]-(>=3@53)-[selection]-(>=6@53)-|", v, 0));
		CHECK(Parses(@"V:[line]-(4)-|", v, 0));
		/* solve: a 200x100 container, a fixed 23 high bar at the bottom and a view above it that takes the rest (the layout of TextMate's document view) */
		NSView *c = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 200, 100)], *top = V(), *bar = V(); NSWindow *w1 = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 200, 100) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: YES]; [w1 setContentView: c]; [c addSubview: top]; [c addSubview: bar]; NSDictionary *d = @{ @"top": top, @"bar": bar };
		[c addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[top]|" options: 0 metrics: nil views: d]]; [c addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[bar]|" options: 0 metrics: nil views: d]];
		[c addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[top][bar(==23)]|" options: 0 metrics: nil views: d]];
		[c layoutSubtreeIfNeeded];
		printf("  top=%s bar=%s\n", [NSStringFromRect([top frame]) UTF8String], [NSStringFromRect([bar frame]) UTF8String]);
		CHECK(NSWidth([top frame]) == 200 && NSHeight([bar frame]) == 23 && NSHeight([top frame]) == 77);                                           /* Apple: top is 77 high, bar 23 */
		CHECK(NSMinY([top frame]) == 23 && NSMinY([bar frame]) == 0);                                                                               /* y up: the bar is at the bottom, the top view above it */
		/* a connection with a predicate: at least 10 between two views, 5 more than that is fine */
		NSView *c2 = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 300, 40)], *a = V(), *b = V(); NSWindow *w2 = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 300, 40) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: YES]; [w2 setContentView: c2]; [c2 addSubview: a]; [c2 addSubview: b]; NSDictionary *d2 = @{ @"a": a, @"b": b };
		[c2 addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[a(50)]-(>=10)-[b(50)]|" options: 0 metrics: nil views: d2]]; [c2 addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[a]|" options: 0 metrics: nil views: d2]]; [c2 addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[b]|" options: 0 metrics: nil views: d2]];
		[c2 layoutSubtreeIfNeeded]; printf("  a=%s b=%s\n", [NSStringFromRect([a frame]) UTF8String], [NSStringFromRect([b frame]) UTF8String]); CHECK(NSMinX([a frame]) == 0 && NSMaxX([b frame]) == 300 && NSMinX([b frame]) - NSMaxX([a frame]) >= 10);
		/* constraints added before the view reaches a window are kept and applied then (applications build their interface first) */
		NSView *c3 = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 300, 40)], *line = V(), *rest = V();
		[line addConstraint: [NSLayoutConstraint constraintWithItem: line attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual toItem: nil attribute: NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 1]];
		[c3 addSubview: line]; [c3 addSubview: rest]; NSDictionary *d3 = @{ @"line": line, @"rest": rest };
		[c3 addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[line][rest]|" options: 0 metrics: nil views: d3]]; [c3 addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[line]|" options: 0 metrics: nil views: d3]]; [c3 addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[rest]|" options: 0 metrics: nil views: d3]];
		CHECK([[c3 constraints] count] >= 3);                                                                                                  /* kept, not dropped */
		NSWindow *w3 = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 300, 40) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: YES]; [w3 setContentView: c3]; [c3 layoutSubtreeIfNeeded];
		printf("  line=%s rest=%s\n", [NSStringFromRect([line frame]) UTF8String], [NSStringFromRect([rest frame]) UTF8String]); CHECK(NSWidth([line frame]) == 1 && NSWidth([rest frame]) == 299);
		/* TextMate's gutter: a scroll view whose document view is pinned left, top and right inside its clip view and whose width follows the document's intrinsic width */
		{ NSView *top = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 428, 430)]; NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 428, 430) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: YES]; [w setContentView: top];
		  NSScrollView *sv = [[NSScrollView alloc] initWithFrame: NSZeroRect]; [sv setTranslatesAutoresizingMaskIntoConstraints: NO]; Gutter *g = [[Gutter alloc] initWithFrame: NSZeroRect]; g->sz = NSMakeSize(0, 0); [g setTranslatesAutoresizingMaskIntoConstraints: NO]; [sv setDocumentView: g]; [sv setBorderType: NSNoBorder];
		  NSView *cv = [sv contentView]; [cv addConstraint: [NSLayoutConstraint constraintWithItem: g attribute: NSLayoutAttributeLeft relatedBy: NSLayoutRelationEqual toItem: cv attribute: NSLayoutAttributeLeft multiplier: 1 constant: 0]];
		  [cv addConstraint: [NSLayoutConstraint constraintWithItem: g attribute: NSLayoutAttributeTop relatedBy: NSLayoutRelationEqual toItem: cv attribute: NSLayoutAttributeTop multiplier: 1 constant: 0]];
		  [cv addConstraint: [NSLayoutConstraint constraintWithItem: g attribute: NSLayoutAttributeRight relatedBy: NSLayoutRelationEqual toItem: cv attribute: NSLayoutAttributeRight multiplier: 1 constant: 0]];
		  NSScrollView *rest = [[NSScrollView alloc] initWithFrame: NSZeroRect]; [rest setTranslatesAutoresizingMaskIntoConstraints: NO]; [rest setHasVerticalScroller: YES]; [rest setHasHorizontalScroller: YES]; [rest setAutohidesScrollers: YES]; [rest setBorderType: NSNoBorder]; [rest setDocumentView: [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 16, 32)]]; [top addSubview: sv]; [top addSubview: rest]; NSView *div = V(); [div addConstraint: [NSLayoutConstraint constraintWithItem: div attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual toItem: nil attribute: NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 1]]; [top addSubview: div]; NSDictionary *d = @{ @"sv": sv, @"rest": rest, @"g": g, @"div": div };
		  [top addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[sv(==g)][div][rest(>=100)]|" options: NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllBottom metrics: nil views: d]]; [top addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[sv]|" options: 0 metrics: nil views: d]];
		  [top layoutSubtreeIfNeeded];
		  printf("  sv=%s g=%s rest=%s clipbounds=%s\n", [NSStringFromRect([sv frame]) UTF8String], [NSStringFromRect([g frame]) UTF8String], [NSStringFromRect([rest frame]) UTF8String], [NSStringFromRect([cv bounds]) UTF8String]);
		  g->sz = NSMakeSize(42, 425); [g invalidateIntrinsicContentSize]; [top layoutSubtreeIfNeeded];                         /* the size is known only after the data is loaded */
		  for (int i = 0; i < 6; i++) { g->sz = NSMakeSize(42, MAX(NSHeight([top frame]) - 40, NSHeight([sv frame]) + (i % 2 ? 32 : -15))); [g invalidateIntrinsicContentSize]; [top layoutSubtreeIfNeeded]; }       /* TextMate: the height follows the frames, every layout changes it */
		  for (int i = 0; i < 2; i++) { [top removeConstraints: [top constraints]];                                                     /* OakDocumentView updateConstraints: drop everything and add it again */
		    [top addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[sv(==g)][div][rest(>=100)]|" options: NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllBottom metrics: nil views: d]]; [top addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[sv]|" options: 0 metrics: nil views: d]]; [top setNeedsUpdateConstraints: YES]; [top layoutSubtreeIfNeeded]; }
		  printf("  after invalidate: top=%s sv=%s rest=%s ntop=%d\n", [NSStringFromRect([top frame]) UTF8String], [NSStringFromRect([sv frame]) UTF8String], [NSStringFromRect([rest frame]) UTF8String], (int)[[top constraints] count]);
		  CHECK(NSWidth([sv frame]) == 42 && NSWidth([g frame]) == 42 && isfinite(NSHeight([g frame])) && isfinite([cv bounds].origin.x) && NSWidth([rest frame]) == 385); }
		/* nested: the constraints of a grandchild's subviews were added while nothing was in a window */
		{ NSView *outer = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 300, 100)], *mid = V(), *bar = V(), *x = V(), *y = V(); NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 300, 100) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: YES];
		  [bar addSubview: x]; [bar addSubview: y]; NSDictionary *bd = @{ @"x": x, @"y": y };
		  [bar addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-10-[x(20)]-5-[y(>=30)]-10-|" options: 0 metrics: nil views: bd]]; [bar addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|-5-[x(15)]-5-|" options: 0 metrics: nil views: bd]]; [bar addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|-5-[y(15)]-5-|" options: 0 metrics: nil views: bd]];
		  [mid addSubview: bar]; NSDictionary *md = @{ @"bar": bar }; [mid addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[bar]|" options: 0 metrics: nil views: md]]; [mid addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:[bar]|" options: 0 metrics: nil views: md]];
		  [outer addSubview: mid]; NSDictionary *od = @{ @"mid": mid }; [outer addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[mid]|" options: 0 metrics: nil views: od]]; [outer addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[mid]|" options: 0 metrics: nil views: od]];
		  [w setContentView: outer]; [outer layoutSubtreeIfNeeded];
		  printf("  bar=%s x=%s y=%s\n", [NSStringFromRect([bar frame]) UTF8String], [NSStringFromRect([x frame]) UTF8String], [NSStringFromRect([y frame]) UTF8String]);
		  CHECK(NSHeight([bar frame]) == 25 && NSWidth([x frame]) == 20 && NSWidth([y frame]) == 255 && NSMinX([x frame]) == 10); }
	}
	printf(fails ? "vfl_tests: %d failed\n" : "vfl_tests: ok\n", fails); return fails != 0;
}
