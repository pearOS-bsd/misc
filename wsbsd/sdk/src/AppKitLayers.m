/* Layer-backed views: -setWantsLayer:, -layer, -makeBackingLayer on top of QuartzCore of this stack.
 *
 * A view with wantsLayer owns a CALayer. The layers of the layer-backed subviews are its sublayers, in the order of the subviews; frame, bounds, hidden and alpha follow the view.
 * The contents are the picture of the view without its layer-backed subviews (made with -drawRect: unless the view draws itself with -updateLayer), refreshed after -setNeedsDisplay.
 * The topmost layer-backed view of a hierarchy renders the whole layer tree (with its animations, from CARenderPresentation) in place of its own drawing, and a timer asks it to redraw while an animation runs.
 * Implicit animations of the layers of views are off unless the NSAnimationContext allows them (allowsImplicitAnimation), as on a Mac: the layer delegate is the view, and answers NSNull. */
#import <wsbsd/AppKitCompat.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAWsbsd.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSAffineTransform.h>
#import <objc/runtime.h>

static const char kLayerKey, kWantsKey, kPolicyKey, kDirtyKey, kDrawSubKey, kOwnLayerKey;
static NSMutableSet *gLive;       /* views with a layer: for the redraw driver */
static NSTimer *gTimer;

static BOOL IsBacked(NSView *v) { return [objc_getAssociatedObject(v, &kWantsKey) boolValue] || objc_getAssociatedObject(v, &kOwnLayerKey) != nil; }
static NSView *BackedRoot(NSView *v)
{
	NSView *root = nil;
	for (NSView *x = v; x; x = [x superview]) { if (IsBacked(x)) root = x; else if (root) break; }
	return root;
}
static BOOL IsRootBacked(NSView *v) { return IsBacked(v) && !([v superview] && IsBacked([v superview])); }

/* ---- the layer of a view ----------------------------------------------------------------------------------------------------------------------------------------------- */
static CALayer *WsLayer(NSView *self, SEL _cmd)
{
	if (!IsBacked(self)) return nil;
	CALayer *l = objc_getAssociatedObject(self, &kLayerKey);
	if (!l) {
		l = [self makeBackingLayer];
		[l setDelegate: (id)self];
		objc_setAssociatedObject(self, &kLayerKey, l, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(self, &kDirtyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		if (!gLive) gLive = [NSMutableSet new];
		[gLive addObject: [NSValue valueWithNonretainedObject: self]];
		if (!gTimer) gTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: [NSView class] selector: @selector(_wsTick:) userInfo: nil repeats: YES];
	}
	return l;
}
static CALayer *WsMakeBackingLayer(NSView *self, SEL _cmd) { CALayer *l = [CALayer layer]; [l setAnchorPoint: CGPointZero]; return l; }
static BOOL WsWantsLayer(NSView *self, SEL _cmd) { return IsBacked(self); }
static void WsSetWantsLayer(NSView *self, SEL _cmd, BOOL flag)
{
	if (flag == [objc_getAssociatedObject(self, &kWantsKey) boolValue]) return;
	objc_setAssociatedObject(self, &kWantsKey, flag ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if (flag) [self layer];
	else if (!objc_getAssociatedObject(self, &kOwnLayerKey)) { objc_setAssociatedObject(self, &kLayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [gLive removeObject: [NSValue valueWithNonretainedObject: self]]; }
	[self setNeedsDisplay: YES];
}
static void WsSetLayer(NSView *self, SEL _cmd, CALayer *l)
{
	objc_setAssociatedObject(self, &kOwnLayerKey, l, OBJC_ASSOCIATION_RETAIN_NONATOMIC);       /* a layer given by the application: the view hosts it, its contents are the application's */
	objc_setAssociatedObject(self, &kLayerKey, l, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if (l) { if (!gLive) gLive = [NSMutableSet new]; [gLive addObject: [NSValue valueWithNonretainedObject: self]]; }
	[self setNeedsDisplay: YES];
}
static BOOL WsWantsUpdateLayer(NSView *self, SEL _cmd) { return NO; }
static void WsUpdateLayer(NSView *self, SEL _cmd) {}
static NSViewLayerContentsRedrawPolicy WsPolicy(NSView *self, SEL _cmd) { NSNumber *n = objc_getAssociatedObject(self, &kPolicyKey); return n ? [n integerValue] : NSViewLayerContentsRedrawDuringViewResize; }
static void WsSetPolicy(NSView *self, SEL _cmd, NSViewLayerContentsRedrawPolicy p) { objc_setAssociatedObject(self, &kPolicyKey, @(p), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static BOOL WsCanDrawSub(NSView *self, SEL _cmd) { return [objc_getAssociatedObject(self, &kDrawSubKey) boolValue]; }
static void WsSetCanDrawSub(NSView *self, SEL _cmd, BOOL f) { objc_setAssociatedObject(self, &kDrawSubKey, @(f), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
/* the delegate answer that keeps the layers of views still: only an animation context that allows implicit animation animates them */
static id WsActionForLayer(NSView *self, SEL _cmd, CALayer *layer, NSString *event)
{
	if (layer != objc_getAssociatedObject(self, &kLayerKey)) return nil;
	if ([[NSAnimationContext currentContext] allowsImplicitAnimation]) return nil;
	return [NSNull null];
}

/* ---- the picture of a view --------------------------------------------------------------------------------------------------------------------------------------------- */
/* the drawing of a view and of its subviews that are not layer-backed, into the current graphics context: the coordinate system of every view is set up here (the display of GNUstep does it
 * through the window, which a bitmap context does not have) */
static void DrawViewTree(NSView *v, NSRect dirty, BOOL parentFlipped, BOOL top)
{
	if ([v isHidden]) return;
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	[gc saveGraphicsState];
	NSAffineTransform *t = [NSAffineTransform transform];
	NSRect f = [v frame], b = [v bounds];
	if (!top) {
		BOOL fl = [v isFlipped] != parentFlipped;
		[t translateXBy: f.origin.x yBy: fl ? f.origin.y + f.size.height : f.origin.y];
		if (fl) [t scaleXBy: 1 yBy: -1];
	} else if ([v isFlipped]) { [t translateXBy: 0 yBy: b.size.height]; [t scaleXBy: 1 yBy: -1]; }
	if (b.size.width && b.size.height && !top) [t scaleXBy: f.size.width / b.size.width yBy: f.size.height / b.size.height];
	[t translateXBy: -b.origin.x yBy: -b.origin.y];
	[t concat];
	[NSBezierPath clipRect: b];
	[v drawRect: NSIntersectionRect(dirty, b)];
	for (NSView *s in [v subviews]) if (!IsBacked(s)) DrawViewTree(s, [v convertRect: dirty toView: s], [v isFlipped], NO);
	[gc restoreGraphicsState];
}
static CGImageRef WsPictureOfView(NSView *v)
{
	NSRect b = [v bounds]; if (b.size.width < 1 || b.size.height < 1) return NULL;
	/* the view drawn into a bitmap of its own (cacheDisplayInRect: of GNUstep reads the window, which holds what the layers hide) */
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: (NSInteger)ceil(b.size.width) pixelsHigh: (NSInteger)ceil(b.size.height) bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
	                                                           colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 0 bitsPerPixel: 32];
	NSGraphicsContext *gc = rep ? [NSGraphicsContext graphicsContextWithBitmapImageRep: rep] : nil;
	if (gc) {
		[NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext: gc];
		DrawViewTree(v, b, [v isFlipped], YES);
		[gc flushGraphics]; [NSGraphicsContext restoreGraphicsState];
	}
	if (!rep || ![rep bitmapData]) return NULL;
	NSBitmapFormat f = [rep bitmapFormat]; NSInteger spp = [rep samplesPerPixel], bpr = [rep bytesPerRow], w = [rep pixelsWide], h = [rep pixelsHigh];
	if ([rep bitsPerSample] != 8 || spp < 3) return NULL;
	CGBitmapInfo info = spp == 4 ? ((f & NSAlphaNonpremultipliedBitmapFormat ? kCGImageAlphaLast : kCGImageAlphaPremultipliedLast) | ((f & NSAlphaFirstBitmapFormat) ? (kCGImageAlphaFirst - kCGImageAlphaLast) : 0)) : kCGImageAlphaNoneSkipLast;
	if (spp == 4 && (f & NSAlphaFirstBitmapFormat)) info = (f & NSAlphaNonpremultipliedBitmapFormat) ? kCGImageAlphaFirst : kCGImageAlphaPremultipliedFirst;
	CFDataRef data = CFDataCreate(NULL, [rep bitmapData], bpr * h);        /* a copy: the representation goes away with this call */
	CGDataProviderRef dp = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGImageRef img = CGImageCreate(w, h, 8, 8 * spp, bpr, cs, info, dp, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(cs); CGDataProviderRelease(dp); CFRelease(data);
	return img;
}
static void WsLayerRefreshContents(NSView *v)
{
	CALayer *l = objc_getAssociatedObject(v, &kLayerKey);
	if (!l || objc_getAssociatedObject(v, &kOwnLayerKey)) return;
	if (![objc_getAssociatedObject(v, &kDirtyKey) boolValue]) return;
	objc_setAssociatedObject(v, &kDirtyKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if ([v wantsUpdateLayer]) { [v updateLayer]; return; }
	CGImageRef img = WsPictureOfView(v);
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	[l setContents: (__bridge id)img];
	[CATransaction commit];
	if (img) CGImageRelease(img);
}

/* ---- keeping the layer tree in line with the views ------------------------------------------------------------------------------------------------------------------ */
static void WsSyncTree(NSView *v)
{
	CALayer *l = [v layer]; if (!l) return;
	CALayerSetContextRoot(l, IsRootBacked(v));
	if (objc_getAssociatedObject(v, &kOwnLayerKey)) return;
	[CATransaction begin]; [CATransaction setDisableActions: ![[NSAnimationContext currentContext] allowsImplicitAnimation]];
	[l setBounds: NSRectToCGRect([v bounds])];
	if (IsRootBacked(v)) [l setPosition: CGPointZero];
	else {
		NSRect f = [v frame];
		[(CALayer *)objc_getAssociatedObject([v superview], &kLayerKey) setGeometryFlipped: [[v superview] isFlipped]];
		[l setPosition: CGPointMake(f.origin.x, f.origin.y)];
	}
	[l setHidden: [v isHidden]];
	[l setOpacity: (float)[v alphaValue]];
	NSMutableArray *subs = [NSMutableArray array];
	for (NSView *s in [v subviews]) if (IsBacked(s)) { WsSyncTree(s); CALayer *sl = [s layer]; if (sl) [subs addObject: sl]; }
	NSArray *cur = [l sublayers];
	BOOL same = cur.count == subs.count;
	for (NSUInteger i = 0; same && i < cur.count; i++) if (cur[i] != subs[i]) same = NO;
	if (!same) [l setSublayers: subs];
	WsLayerRefreshContents(v);
	[CATransaction commit];
}

/* ---- drawing: the topmost layer-backed view draws the tree ------------------------------------------------------------------------------------------------------- */
static IMP origDisplayRect;
static void WsDisplayRectIgnoringOpacity(NSView *self, SEL _cmd, NSRect rect, NSGraphicsContext *ctx)
{
	if (IsBacked(self)) {
		if (!IsRootBacked(self)) return;                    /* drawn as a layer of the tree of the topmost layer-backed view */
		if (ctx && ctx != [[self window] graphicsContext]) goto original;        /* a bitmap or printing context: the plain drawing */
		WsSyncTree(self);
		/* focus on the view: the display of GNUstep notes the rectangle drawn for the flush of the window, which drawing through CoreGraphics alone does not */
		if (![self lockFocusIfCanDraw]) return;
		CGContextRef cg = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
		if (cg) {
			CGContextSaveGState(cg);
			CGContextClipToRect(cg, NSRectToCGRect(rect));
			CARenderPresentation([self layer], cg, 0, NO);
			CGContextRestoreGState(cg);
			[self unlockFocus];
			return;
		}
		[self unlockFocus];
	}
original:
	((void (*)(id, SEL, NSRect, id))origDisplayRect)(self, _cmd, rect, ctx);
}

static IMP origNeedsDisplay, origNeedsDisplayRect, origSetFrame, origSetHidden, origSetAlpha;
static void Dirty(NSView *self, BOOL own)
{
	if (own && IsBacked(self)) objc_setAssociatedObject(self, &kDirtyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	NSView *r = BackedRoot(self); if (r && r != self) [r setNeedsDisplay: YES];
}
static void WsSetNeedsDisplay(NSView *self, SEL _cmd, BOOL f) { if (f) Dirty(self, YES); ((void (*)(id, SEL, BOOL))origNeedsDisplay)(self, _cmd, f); }
static void WsSetNeedsDisplayInRect(NSView *self, SEL _cmd, NSRect rc) { Dirty(self, YES); ((void (*)(id, SEL, NSRect))origNeedsDisplayRect)(self, _cmd, rc); }
static void WsSetFrame(NSView *self, SEL _cmd, NSRect f) { ((void (*)(id, SEL, NSRect))origSetFrame)(self, _cmd, f); Dirty(self, YES); }
static void WsSetHidden(NSView *self, SEL _cmd, BOOL h) { ((void (*)(id, SEL, BOOL))origSetHidden)(self, _cmd, h); Dirty(self, NO); }
static void WsSetAlpha(NSView *self, SEL _cmd, CGFloat a) { ((void (*)(id, SEL, CGFloat))origSetAlpha)(self, _cmd, a); Dirty(self, NO); }

/* ---- the redraw driver: 60 Hz while any layer tree has an animation running, and once after a change of a layer ---------------------------------------------------------- */
static BOOL gChanged;
static void WsTick(void)
{
	for (NSValue *val in [gLive allObjects]) {
		NSView *v = [val nonretainedObjectValue];
		if (!v || !IsRootBacked(v) || ![v window]) continue;
		if (gChanged || CALayerTreeHasActiveAnimations([v layer])) { [CATransaction flush]; [v setNeedsDisplay: YES]; }        /* the flush also brings the presentation layers up to date */
	}
	gChanged = NO;
}

@implementation NSView (WsbsdLayers)
+ (void)load
{
	struct { SEL sel; IMP imp; const char *enc; } t[] = {
		{ @selector(wantsLayer), (IMP)WsWantsLayer, "c@:" }, { @selector(setWantsLayer:), (IMP)WsSetWantsLayer, "v@:c" }, { @selector(layer), (IMP)WsLayer, "@@:" },
		{ @selector(setLayer:), (IMP)WsSetLayer, "v@:@" }, { @selector(makeBackingLayer), (IMP)WsMakeBackingLayer, "@@:" }, { @selector(wantsUpdateLayer), (IMP)WsWantsUpdateLayer, "c@:" },
		{ @selector(updateLayer), (IMP)WsUpdateLayer, "v@:" }, { @selector(layerContentsRedrawPolicy), (IMP)WsPolicy, "q@:" }, { @selector(setLayerContentsRedrawPolicy:), (IMP)WsSetPolicy, "v@:q" },
		{ @selector(canDrawSubviewsIntoLayer), (IMP)WsCanDrawSub, "c@:" }, { @selector(setCanDrawSubviewsIntoLayer:), (IMP)WsSetCanDrawSub, "v@:c" },
		{ @selector(actionForLayer:forKey:), (IMP)WsActionForLayer, "@@:@@" } };
	for (size_t i = 0; i < sizeof t / sizeof t[0]; i++) {
		Method m = class_getInstanceMethod(objc_getClass("NSView"), t[i].sel);
		class_replaceMethod(objc_getClass("NSView"), t[i].sel, t[i].imp, m ? method_getTypeEncoding(m) : t[i].enc);
	}
	Class c = objc_getClass("NSView");      /* no message to the class here: +initialize of AppKit must not run inside +load */
	struct { SEL sel; IMP imp; IMP *orig; } h[] = {
		{ @selector(displayRectIgnoringOpacity:inContext:), (IMP)WsDisplayRectIgnoringOpacity, &origDisplayRect }, { @selector(setNeedsDisplay:), (IMP)WsSetNeedsDisplay, &origNeedsDisplay },
		{ @selector(setNeedsDisplayInRect:), (IMP)WsSetNeedsDisplayInRect, &origNeedsDisplayRect }, { @selector(setFrame:), (IMP)WsSetFrame, &origSetFrame },
		{ @selector(setHidden:), (IMP)WsSetHidden, &origSetHidden }, { @selector(setAlphaValue:), (IMP)WsSetAlpha, &origSetAlpha } };
	for (size_t i = 0; i < sizeof h / sizeof h[0]; i++) {
		Method m = class_getInstanceMethod(c, h[i].sel);
		if (m) { *h[i].orig = method_getImplementation(m); method_setImplementation(m, h[i].imp); }
	}
	CALayerSetChangeObserver(^(CALayer *l) { gChanged = YES; });
}
+ (void)_wsTick:(NSTimer *)t { WsTick(); }
@end
