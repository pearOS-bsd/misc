/* OpenControls.m — what the controls need to be drawn and used on wsd (look: docs/UI-MAC.md, dark): slider, pop-up, check box and radio, table (rows of the data source) */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import "NSEvent.h"
#import "NSWindow.h"
#import "NSView.h"
#import <objc/runtime.h>
#import "NSSlider.h"
#import "NSPopUpButton.h"
#import "NSTableView.h"
#import "NSTableColumn.h"
#import "NSButton.h"
#import "NSProgressIndicator.h"
#import "NSFont.h"
#import "OpenBackend.h"
extern void OpenDrawSlider(CGContextRef cg, CGRect b, double f, BOOL enabled);
extern void OpenDrawProgress(CGContextRef cg, CGRect b, double f);
extern void OpenDrawPopUp(CGContextRef cg, CGRect frame, NSString *title, BOOL enabled);
extern NSInteger OpenPopupMenu(NSView *anchor, NSArray *titles, NSInteger sel);
#import "NSApplication.h"
@protocol OpenTableDS <NSObject>
@optional
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t;
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r;
@end

#define STORE(obj, key) objc_getAssociatedObject(obj, &key)
#define PUT(obj, key, val) objc_setAssociatedObject(obj, &key, val, OBJC_ASSOCIATION_RETAIN)
static CGContextRef CG(void) { return [[NSGraphicsContext currentContext] CGContext]; }
static void Text(NSString *t, CGPoint p, CGFloat size, CGFloat alpha)
{
    NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize:size], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:alpha] };
    CGSize ts = [t sizeWithAttributes:at];
    [t drawAtPoint:CGPointMake(p.x, p.y - ts.height / 2) withAttributes:at];
}
static void Round(CGContextRef cg, CGRect r, CGFloat rad) { CGPathRef p = CGPathCreateWithRoundedRect(r, rad, rad, NULL); CGContextAddPath(cg, p); CGPathRelease(p); }

/* ---- slider: 4 pt track, accent up to the knob, white knob 18 pt ---- */
static char kSV, kSMin, kSMax;
@implementation NSSlider (OpenControls)
+ (instancetype)sliderWithValue:(double)v minValue:(double)lo maxValue:(double)hi target:(id)t action:(SEL)a
{
    NSSlider *s = [[self alloc] initWithFrame:CGRectMake(0, 0, 100, 26)];
    [s setMinValue:lo]; [s setMaxValue:hi]; [s setDoubleValue:v]; [s setTarget:t]; [s setAction:a];
    return s;
}
- (double)doubleValue { return [STORE(self, kSV) doubleValue]; }
- (void)setDoubleValue:(double)v { double lo = [self minValue], hi = [self maxValue]; PUT(self, kSV, @(v < lo ? lo : v > hi ? hi : v)); [self display]; }
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = CG(); if (!cg) return;
    double lo = [self minValue], hi = [self maxValue], f = hi > lo ? ([self doubleValue] - lo) / (hi - lo) : 0;
    OpenDrawSlider(cg, [self bounds], f, YES);
}
- (void)_openSet:(NSEvent *)e
{
    CGPoint p = [e locationInWindow]; for (NSView *v = self; v && v != [[self window] contentView]; v = [v superview]) p.x -= [v frame].origin.x;
    CGFloat w = [self bounds].size.width - 20, f = (p.x - 10) / (w > 0 ? w : 1); if (f < 0) f = 0; if (f > 1) f = 1;
    [self setDoubleValue:[self minValue] + f * ([self maxValue] - [self minValue])];
    if ([self action]) [[self target] performSelector:[self action] withObject:self];
}
- (void)mouseDown:(NSEvent *)e { [self _openSet:e]; }
- (void)mouseDragged:(NSEvent *)e { [self _openSet:e]; }
@end

/* ---- progress bar ---- */
@implementation NSProgressIndicator (OpenControls)
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = CG(); if (!cg) return;
    double lo = [self minValue], hi = [self maxValue], f = hi > lo ? ([self doubleValue] - lo) / (hi - lo) : 0;
    OpenDrawProgress(cg, [self bounds], f);
}
@end

/* ---- pop-up button: items kept here, a click goes to the next item (the menu comes with NSMenu drawing) ---- */
static char kPTitles, kPSel;
@implementation NSPopUpButton (OpenControls)
- (instancetype)initWithFrame:(CGRect)f pullsDown:(BOOL)pd { return [self initWithFrame:f]; }
- (void)addItemsWithTitles:(NSArray *)t { PUT(self, kPTitles, [[STORE(self, kPTitles) ?: @[] arrayByAddingObjectsFromArray:t] copy]); [self display]; }
- (void)addItemWithTitle:(NSString *)t { [self addItemsWithTitles:@[t]]; }
- (NSInteger)indexOfSelectedItem { return [STORE(self, kPSel) integerValue]; }
- (NSString *)titleOfSelectedItem { NSArray *a = STORE(self, kPTitles); NSInteger i = [self indexOfSelectedItem]; return i < (NSInteger)[a count] ? a[i] : nil; }
- (void)selectItemAtIndex:(NSInteger)i { PUT(self, kPSel, @(i)); [self display]; }
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = CG(); if (!cg) return;
    OpenDrawPopUp(cg, CGRectInset([self bounds], 1, 0), [self titleOfSelectedItem], YES);
}
- (void)mouseDown:(NSEvent *)e { NSArray *a = STORE(self, kPTitles); if (![a count]) return; NSInteger i = OpenPopupMenu(self, a, [self indexOfSelectedItem]); if (i >= 0) { [self selectItemAtIndex:i]; if ([self action]) [[self target] performSelector:[self action] withObject:self]; } }
@end

/* ---- check box / radio: the kind is kept in the button ---- */
static char kBKind, kBState;
@implementation NSButton (OpenControls)
+ (instancetype)checkboxWithTitle:(NSString *)t target:(id)tg action:(SEL)a { NSButton *b = [[self alloc] initWithFrame:CGRectMake(0, 0, 100, 22)]; b.title = t; b.target = tg; b.action = a; PUT(b, kBKind, @1); return b; }
+ (instancetype)radioButtonWithTitle:(NSString *)t target:(id)tg action:(SEL)a { NSButton *b = [self checkboxWithTitle:t target:tg action:a]; PUT(b, kBKind, @2); return b; }
- (NSControlStateValue)state { return [STORE(self, kBState) integerValue]; }
- (void)setState:(NSControlStateValue)v { PUT(self, kBState, @(v)); [self display]; }
- (NSInteger)_openKind { return [STORE(self, kBKind) integerValue]; }
@end

/* ---- table: the rows of the data source, one line per row, the columns side by side ---- */
static char kTDS, kTDG, kTSel;
@implementation NSTableView (OpenControls)
- (void)setDataSource:(id)d { PUT(self, kTDS, d); }
- (id)dataSource { return STORE(self, kTDS); }
- (void)setDelegate:(id)d { PUT(self, kTDG, d); }
- (id)delegate { return STORE(self, kTDG); }
- (NSInteger)selectedRow { NSNumber *n = STORE(self, kTSel); return n ? [n integerValue] : -1; }
- (CGFloat)_openRowHeight { CGFloat h = [self rowHeight]; return h > 0 ? h : 24; }
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = CG(); if (!cg) return;
    id<OpenTableDS> ds = [self dataSource]; CGRect b = [self bounds]; CGFloat rh = [self _openRowHeight];
    NSInteger n = [ds respondsToSelector:@selector(numberOfRowsInTableView:)] ? [ds numberOfRowsInTableView:self] : 0;
    for (NSInteger r = 0; r < n; r++) {
        CGFloat y = b.size.height - (r + 1) * rh;
        CGContextSetRGBFillColor(cg, r == [self selectedRow] ? 63 / 255.0 : (r & 1 ? 38 / 255.0 : 30 / 255.0), r == [self selectedRow] ? 96 / 255.0 : (r & 1 ? 38 / 255.0 : 30 / 255.0), r == [self selectedRow] ? 130 / 255.0 : (r & 1 ? 38 / 255.0 : 30 / 255.0), 1);
        CGContextFillRect(cg, CGRectMake(0, y, b.size.width, rh));
        CGFloat x = 6;
        for (NSTableColumn *c in [self tableColumns]) {
            id v = [ds respondsToSelector:@selector(tableView:objectValueForTableColumn:row:)] ? [ds tableView:self objectValueForTableColumn:c row:r] : nil;
            if (v) Text([v description], CGPointMake(x, y + rh / 2), 13, 0.85);
            x += [c width];
        }
    }
}
- (void)mouseDown:(NSEvent *)e
{
    CGPoint p = [e locationInWindow]; for (NSView *v = self; v && v != [[self window] contentView]; v = [v superview]) p.y -= [v frame].origin.y;
    NSInteger r = (NSInteger)((p.y > 0 ? ([self bounds].size.height - p.y) : 0) / [self _openRowHeight]);
    PUT(self, kTSel, @(r)); [self display];
}
@end
