/* NSGlassEffectView and NSGlassEffectContainerView (macOS 26 "Liquid Glass"): the view reports its rounded rectangle to the window server, whose compositor draws the glass material
 * (blur, lens, specular rim; shapes of one window that touch melt together) behind the window's own pixels. The window turns non-opaque, as with NSVisualEffectView. The tint is drawn
 * over the glass by the view. contentView is kept inside the view's bounds. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <GNUstepGUI/GSDisplayServer.h>

@interface GSDisplayServer (WsdGlass) - (void) wsdGlassSlot: (int)slot : (int)win : (NSRect)r : (int)radius : (int)mode; @end

enum { WsdGlassRegular = 0, WsdGlassClear = 1 };

@interface NSGlassEffectView : NSView { NSView *_contentView; CGFloat _cornerRadius; NSColor *_tintColor; NSInteger _style; int _slot; NSWindow *_slotWindow; }
- (NSView *)contentView; - (void)setContentView:(NSView *)v;
- (CGFloat)cornerRadius; - (void)setCornerRadius:(CGFloat)r;
- (NSColor *)tintColor; - (void)setTintColor:(NSColor *)c;
- (NSInteger)style; - (void)setStyle:(NSInteger)s;
@end

static char kSlots;
@implementation NSGlassEffectView
- (id)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _slot = -1; _cornerRadius = 0; } return self; }
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)contentView { return _contentView; }
- (void)setContentView:(NSView *)v
{
	if (v == _contentView) return;
	[_contentView removeFromSuperview];
	[_contentView release]; _contentView = [v retain];
	if (v) { [v setFrame: [self bounds]]; [v setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [self addSubview: v]; }
}
- (CGFloat)cornerRadius { return _cornerRadius; }
- (void)setCornerRadius:(CGFloat)r { _cornerRadius = r; [self wsdPublish]; [self setNeedsDisplay: YES]; }
- (NSColor *)tintColor { return _tintColor; }
- (void)setTintColor:(NSColor *)c { [_tintColor release]; _tintColor = [c retain]; [self setNeedsDisplay: YES]; }
- (NSInteger)style { return _style; }
- (void)setStyle:(NSInteger)s { _style = s; [self wsdPublish]; }
- (int)wsdSlotIn:(NSWindow *)w
{
	NSMutableIndexSet *used = objc_getAssociatedObject(w, &kSlots);
	if (!used) { used = [NSMutableIndexSet indexSet]; objc_setAssociatedObject(w, &kSlots, used, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
	for (int i = 0; i < 16; i++) if (![used containsIndex: i]) { [used addIndex: i]; return i; }
	return -1;
}
- (void)wsdRelease
{
	if (_slot >= 0 && _slotWindow)
	{
		[(NSMutableIndexSet *)objc_getAssociatedObject(_slotWindow, &kSlots) removeIndex: _slot];
		id srv = GSCurrentServer();
		if ([srv respondsToSelector: @selector(wsdGlassSlot:::::)]) [srv wsdGlassSlot: _slot : (int)[_slotWindow windowNumber] : NSZeroRect : 0 : 0];
	}
	_slot = -1; [_slotWindow release]; _slotWindow = nil;
}
/* tell the window server where the glass is */
- (void)wsdPublish
{
	NSWindow *w = [self window];
	if (!w) { [self wsdRelease]; return; }
	if (_slotWindow != w) { [self wsdRelease]; _slot = [self wsdSlotIn: w]; _slotWindow = [w retain]; }
	if (_slot < 0) return;
	if ([w isOpaque]) { [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; }
	NSRect r = [self convertRect: [self bounds] toView: nil];
	r.origin.y = [[w contentView] frame].size.height - NSMaxY(r) + ([w frame].size.height - [[w contentView] frame].size.height);   /* from the bottom left of the window to the top left */
	id srv = GSCurrentServer(); if (getenv("WSD_GLASS_DEBUG")) NSLog(@"glass slot %d win %d rect %@ srv %@", _slot, (int)[w windowNumber], NSStringFromRect(r), srv);
	if ([srv respondsToSelector: @selector(wsdGlassSlot:::::)]) [srv wsdGlassSlot: _slot : (int)[w windowNumber] : r : (int)_cornerRadius : _style == WsdGlassClear ? 2 : 1];
}
- (void)viewDidMoveToWindow { [self wsdPublish]; [super viewDidMoveToWindow]; }
- (void)setFrame:(NSRect)f { [super setFrame: f]; [self wsdPublish]; }
- (void)setFrameSize:(NSSize)s { [super setFrameSize: s]; [self wsdPublish]; }
- (void)setFrameOrigin:(NSPoint)p { [super setFrameOrigin: p]; [self wsdPublish]; }
- (void)drawRect:(NSRect)r
{
	if (!_tintColor) return;
	[_tintColor set];
	[[NSBezierPath bezierPathWithRoundedRect: [self bounds] xRadius: _cornerRadius yRadius: _cornerRadius] fill];
}
- (void)dealloc { [self wsdRelease]; [_contentView release]; [_tintColor release]; [super dealloc]; }
@end

/* the container groups glass views so that they melt together: the compositor already melts shapes that touch; spacing is the distance at which they start to (kept for the layout of the views) */
@interface NSGlassEffectContainerView : NSView { NSView *_contentView; CGFloat _spacing; } @end
@implementation NSGlassEffectContainerView
- (NSView *)contentView { return _contentView; }
- (void)setContentView:(NSView *)v { if (v == _contentView) return; [_contentView removeFromSuperview]; [_contentView release]; _contentView = [v retain]; if (v) { [v setFrame: [self bounds]]; [v setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [self addSubview: v]; } }
- (CGFloat)spacing { return _spacing; }
- (void)setSpacing:(CGFloat)s { _spacing = s; }
- (void)dealloc { [_contentView release]; [super dealloc]; }
@end
