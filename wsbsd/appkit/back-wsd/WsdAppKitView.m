/* NSView and NSWindow methods of macOS's AppKit that GNUstep lacks (found with tools/appkit_probe.m against the selectors of the SDK's headers). The state they keep lives in associated objects;
 * what has no meaning on this system (touch events, Core Image filters on views, full screen of a view) answers as AppKit does when the feature is off. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#define GET(k) objc_getAssociatedObject(self, &k)
#define SET(k, v) objc_setAssociatedObject(self, &k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC)
static char kWantsLayer, kLayer, kAreas, kGestures, kInsets, kPrepared, kClips, kConc, kIntoLayer, kLayerCI, kCompact, kTouches, kResting, kCompFilter, kBGFilters, kContentFilters, kHActive, kVActive;
static NSNumber *B(BOOL v) { return [NSNumber numberWithBool: v]; }
@implementation NSView (WsdAppKit)
- (NSEdgeInsets)alignmentRectInsets { return NSEdgeInsetsMake(0, 0, 0, 0); }
- (NSRect)alignmentRectForFrame:(NSRect)f { NSEdgeInsets i = [self alignmentRectInsets]; return NSMakeRect(f.origin.x + i.left, f.origin.y + i.bottom, f.size.width - i.left - i.right, f.size.height - i.top - i.bottom); }
- (NSRect)frameForAlignmentRect:(NSRect)r { NSEdgeInsets i = [self alignmentRectInsets]; return NSMakeRect(r.origin.x - i.left, r.origin.y - i.bottom, r.size.width + i.left + i.right, r.size.height + i.top + i.bottom); }
- (NSPoint)convertPointToBacking:(NSPoint)p { return p; }
- (NSPoint)convertPointFromBacking:(NSPoint)p { return p; }
- (NSSize)convertSizeToBacking:(NSSize)s { return s; }
- (NSSize)convertSizeFromBacking:(NSSize)s { return s; }
- (NSRect)convertRectToBacking:(NSRect)r { return r; }
- (NSRect)convertRectFromBacking:(NSRect)r { return r; }
- (NSPoint)convertPointToLayer:(NSPoint)p { return p; }
- (NSPoint)convertPointFromLayer:(NSPoint)p { return p; }
- (NSSize)convertSizeToLayer:(NSSize)s { return s; }
- (NSSize)convertSizeFromLayer:(NSSize)s { return s; }
- (NSRect)convertRectToLayer:(NSRect)r { return r; }
- (NSRect)convertRectFromLayer:(NSRect)r { return r; }
- (void)translateRectsNeedingDisplayInRect:(NSRect)clip by:(NSSize)delta { [self setNeedsDisplayInRect: clip]; }
- (NSRect)focusRingMaskBounds { return [self bounds]; }
- (void)drawFocusRingMask { NSRectFill([self bounds]); }
@end
/* placeholders: they answer the selector (so that applications that call it run) but keep a value or answer a constant; nothing renders or reacts. Not counted as implemented. */
@implementation NSView (WsdAppKitPlaceholder)
+ (BOOL)requiresConstraintBasedLayout { return NO; }
+ (BOOL)isCompatibleWithResponsiveScrolling { return NO; }
- (BOOL)wantsLayer { return [GET(kWantsLayer) boolValue]; }
- (void)setWantsLayer:(BOOL)v { SET(kWantsLayer, B(v)); if (!v) SET(kLayer, nil); }
- (id)layer { id l = GET(kLayer); if (!l && [self wantsLayer]) { l = [self makeBackingLayer]; SET(kLayer, l); } return l; }
- (void)setLayer:(id)l { SET(kLayer, l); if (l) SET(kWantsLayer, B(YES)); }
- (id)makeBackingLayer { Class c = NSClassFromString(@"CALayer"); return c ? [[[c alloc] init] autorelease] : nil; }
- (BOOL)wantsUpdateLayer { return NO; }
- (void)updateLayer {}
- (BOOL)canDrawSubviewsIntoLayer { return [GET(kIntoLayer) boolValue]; }
- (void)setCanDrawSubviewsIntoLayer:(BOOL)v { SET(kIntoLayer, B(v)); }
- (BOOL)canDrawConcurrently { return [GET(kConc) boolValue]; }
- (void)setCanDrawConcurrently:(BOOL)v { SET(kConc, B(v)); }
- (BOOL)layerUsesCoreImageFilters { return [GET(kLayerCI) boolValue]; }
- (void)setLayerUsesCoreImageFilters:(BOOL)v { SET(kLayerCI, B(v)); }
- (BOOL)clipsToBounds { id v = GET(kClips); return v ? [v boolValue] : NO; }
- (void)setClipsToBounds:(BOOL)v { SET(kClips, B(v)); }
- (id)compositingFilter { return GET(kCompFilter); }
- (void)setCompositingFilter:(id)f { SET(kCompFilter, f); }
- (NSArray *)backgroundFilters { return GET(kBGFilters) ?: [NSArray array]; }
- (void)setBackgroundFilters:(NSArray *)f { SET(kBGFilters, f); }
- (NSArray *)contentFilters { return GET(kContentFilters) ?: [NSArray array]; }
- (void)setContentFilters:(NSArray *)f { SET(kContentFilters, f); }
- (BOOL)allowsVibrancy { return NO; }
- (void)viewWillDraw {}
- (void)viewDidChangeBackingProperties {}
- (void)viewDidChangeEffectiveAppearance {}
- (void)viewDidChangeEffectiveCornerRadii {}
- (NSArray *)trackingAreas { return GET(kAreas) ?: [NSArray array]; }
- (void)addTrackingArea:(id)a { NSMutableArray *m = [NSMutableArray arrayWithArray: [self trackingAreas]]; if (![m containsObject: a]) [m addObject: a]; SET(kAreas, m); }
- (void)removeTrackingArea:(id)a { NSMutableArray *m = [NSMutableArray arrayWithArray: [self trackingAreas]]; [m removeObject: a]; SET(kAreas, m); }
- (void)updateTrackingAreas {}
- (NSArray *)gestureRecognizers { return GET(kGestures) ?: [NSArray array]; }
- (void)setGestureRecognizers:(NSArray *)g { SET(kGestures, g); }
- (void)addGestureRecognizer:(id)g { NSMutableArray *m = [NSMutableArray arrayWithArray: [self gestureRecognizers]]; if (![m containsObject: g]) [m addObject: g]; SET(kGestures, m); }
- (void)removeGestureRecognizer:(id)g { NSMutableArray *m = [NSMutableArray arrayWithArray: [self gestureRecognizers]]; [m removeObject: g]; SET(kGestures, m); }
- (NSSize)fittingSize { return [self frame].size; }
- (void)invalidateIntrinsicContentSize {}
- (CGFloat)lastBaselineOffsetFromBottom { return 0; }
- (BOOL)hasAmbiguousLayout { return NO; }
- (void)exerciseAmbiguityInLayout {}
- (NSEdgeInsets)safeAreaInsets { return NSEdgeInsetsMake(0, 0, 0, 0); }
- (NSEdgeInsets)additionalSafeAreaInsets { NSValue *v = GET(kInsets); NSEdgeInsets e = NSEdgeInsetsMake(0, 0, 0, 0); if (v) [v getValue: &e]; return e; }
- (void)setAdditionalSafeAreaInsets:(NSEdgeInsets)e { SET(kInsets, [NSValue valueWithBytes: &e objCType: @encode(NSEdgeInsets)]); }
- (NSRect)safeAreaRect { return [self bounds]; }
- (NSRect)preparedContentRect { NSValue *v = GET(kPrepared); return v ? [v rectValue] : [self visibleRect]; }
- (void)setPreparedContentRect:(NSRect)r { SET(kPrepared, [NSValue valueWithRect: r]); }
- (void)prepareContentInRect:(NSRect)r { [self setPreparedContentRect: r]; }
- (void)prepareForReuse {}
- (BOOL)prefersCompactControlSizeMetrics { return [GET(kCompact) boolValue]; }
- (void)setPrefersCompactControlSizeMetrics:(BOOL)v { SET(kCompact, B(v)); }
- (BOOL)isHorizontalContentSizeConstraintActive { id v = GET(kHActive); return v ? [v boolValue] : YES; }
- (void)setHorizontalContentSizeConstraintActive:(BOOL)v { SET(kHActive, B(v)); }
- (BOOL)isVerticalContentSizeConstraintActive { id v = GET(kVActive); return v ? [v boolValue] : YES; }
- (void)setVerticalContentSizeConstraintActive:(BOOL)v { SET(kVActive, B(v)); }
- (BOOL)acceptsTouchEvents { return [GET(kTouches) boolValue]; }
- (void)setAcceptsTouchEvents:(BOOL)v { SET(kTouches, B(v)); }
- (BOOL)wantsRestingTouches { return [GET(kResting) boolValue]; }
- (void)setWantsRestingTouches:(BOOL)v { SET(kResting, B(v)); }
- (BOOL)isInFullScreenMode { return NO; }
- (BOOL)enterFullScreenMode:(NSScreen *)s withOptions:(NSDictionary *)o { return NO; }
- (void)exitFullScreenModeWithOptions:(NSDictionary *)o {}
- (id)enclosingMenuItem { return nil; }
- (id)inputContext { return nil; }
- (BOOL)isDrawingFindIndicator { return NO; }
- (void)willOpenMenu:(NSMenu *)m withEvent:(NSEvent *)e {}
- (void)didCloseMenu:(NSMenu *)m withEvent:(NSEvent *)e {}
- (void)noteFocusRingMaskChanged {}
@end


static char wSubtitle, wTitleVis, wTBTransparent, wTBSep, wToolbarStyle, wRepURL, wTabMode, wTabId, wMovable, wRestorable, wSharing, wAnimBeh, wVC, wColorSpace, wPrevents, wMaxFS, wMinFS, wBorder, wOrdIdx, wAppearanceSource, wTBAcc, wConc, wLogin;
@implementation NSWindow (WsdAppKit)
+ (NSArray *)windowNumbersWithOptions:(NSInteger)o { NSMutableArray *a = [NSMutableArray array]; for (NSWindow *w in [NSApp windows]) [a addObject: [NSNumber numberWithInteger: [w windowNumber]]]; return a; }
- (BOOL)hasTitleBar { return ([self styleMask] & NSTitledWindowMask) != 0; }
- (BOOL)hasCloseBox { return ([self styleMask] & NSClosableWindowMask) != 0; }
- (BOOL)isMiniaturizable { return ([self styleMask] & NSMiniaturizableWindowMask) != 0; }
- (BOOL)isResizable { return ([self styleMask] & NSResizableWindowMask) != 0; }
- (BOOL)isZoomable { return [self isResizable]; }
- (BOOL)isFloatingPanel { return [self isKindOfClass: [NSPanel class]] && [(NSPanel *)self isFloatingPanel]; }
- (BOOL)isModalPanel { return [NSApp modalWindow] == self; }
- (void)endSheet:(NSWindow *)sheet { [NSApp endSheet: sheet]; }
- (void)endSheet:(NSWindow *)sheet returnCode:(NSInteger)rc { [NSApp endSheet: sheet returnCode: rc]; }
- (NSURL *)representedURL { return GET(wRepURL); }
- (void)setRepresentedURL:(NSURL *)u { SET(wRepURL, u); if ([u isFileURL]) [self setRepresentedFilename: [u path]]; }
- (id)contentViewController { return GET(wVC); }
- (void)setContentViewController:(id)vc { SET(wVC, vc); if ([vc respondsToSelector: @selector(view)]) [self setContentView: [vc view]]; }
- (NSRect)contentLayoutRect { return [[self contentView] frame]; }
- (NSPoint)convertPointToScreen:(NSPoint)p { return [self convertBaseToScreen: p]; }
- (NSPoint)convertPointFromScreen:(NSPoint)p { return [self convertScreenToBase: p]; }
- (NSRect)convertRectToScreen:(NSRect)r { NSPoint o = [self convertBaseToScreen: r.origin]; return NSMakeRect(o.x, o.y, r.size.width, r.size.height); }
- (NSRect)convertRectFromScreen:(NSRect)r { NSPoint o = [self convertScreenToBase: r.origin]; return NSMakeRect(o.x, o.y, r.size.width, r.size.height); }
- (NSPoint)convertPointToBacking:(NSPoint)p { return p; }
- (NSPoint)convertPointFromBacking:(NSPoint)p { return p; }
- (NSRect)convertRectToBacking:(NSRect)r { return r; }
- (NSRect)convertRectFromBacking:(NSRect)r { return r; }
- (NSRect)backingAlignedRect:(NSRect)r options:(NSUInteger)o { return NSIntegralRect(r); }
- (NSInteger)occlusionState { return [self isVisible] ? 2 : 0; }
- (void)toggleFullScreen:(id)s { [self zoom: s]; }
- (BOOL)isOnActiveSpace { return [self isVisible]; }
- (NSRect)cascadingReferenceFrame { return [self frame]; }
@end
/* placeholders: they answer the selector (so that applications that call it run) but keep a value or answer a constant; nothing renders or reacts. Not counted as implemented. */
@implementation NSWindow (WsdAppKitPlaceholder)
+ (BOOL)allowsAutomaticWindowTabbing { return NO; }
+ (void)setAllowsAutomaticWindowTabbing:(BOOL)v {}
+ (NSInteger)userTabbingPreference { return 1; }
- (BOOL)isMovable { id v = GET(wMovable); return v ? [v boolValue] : YES; }
- (void)setMovable:(BOOL)v { SET(wMovable, B(v)); }
- (BOOL)isSheet { return [self isKindOfClass: [NSPanel class]] && [(id)self respondsToSelector: @selector(sheetParent)] && NO; }
- (NSArray *)sheets { return [NSArray array]; }
- (NSString *)subtitle { return GET(wSubtitle) ?: @""; }
- (void)setSubtitle:(NSString *)s { SET(wSubtitle, s); }
- (NSInteger)titleVisibility { return [GET(wTitleVis) integerValue]; }
- (void)setTitleVisibility:(NSInteger)v { SET(wTitleVis, [NSNumber numberWithInteger: v]); }
- (BOOL)titlebarAppearsTransparent { return [GET(wTBTransparent) boolValue]; }
- (void)setTitlebarAppearsTransparent:(BOOL)v { SET(wTBTransparent, B(v)); }
- (NSInteger)titlebarSeparatorStyle { return [GET(wTBSep) integerValue]; }
- (void)setTitlebarSeparatorStyle:(NSInteger)v { SET(wTBSep, [NSNumber numberWithInteger: v]); }
- (NSInteger)toolbarStyle { return [GET(wToolbarStyle) integerValue]; }
- (void)setToolbarStyle:(NSInteger)v { SET(wToolbarStyle, [NSNumber numberWithInteger: v]); }
- (NSInteger)tabbingMode { return [GET(wTabMode) integerValue]; }
- (void)setTabbingMode:(NSInteger)v { SET(wTabMode, [NSNumber numberWithInteger: v]); }
- (NSString *)tabbingIdentifier { return GET(wTabId) ?: @""; }
- (void)setTabbingIdentifier:(NSString *)s { SET(wTabId, s); }
- (NSArray *)tabbedWindows { return nil; }
- (id)tabGroup { return nil; }
- (id)tab { return nil; }
- (void)addTabbedWindow:(NSWindow *)w ordered:(NSInteger)o { [w orderFront: nil]; }
- (void)mergeAllWindows:(id)s {}
- (void)moveTabToNewWindow:(id)s {}
- (void)selectNextTab:(id)s {}
- (void)selectPreviousTab:(id)s {}
- (void)toggleTabBar:(id)s {}
- (void)toggleTabOverview:(id)s {}
- (BOOL)isRestorable { id v = GET(wRestorable); return v ? [v boolValue] : YES; }
- (void)setRestorable:(BOOL)v { SET(wRestorable, B(v)); }
- (Class)restorationClass { return Nil; }
- (void)setRestorationClass:(Class)c {}
- (void)disableSnapshotRestoration {}
- (void)enableSnapshotRestoration {}
- (NSInteger)sharingType { return [GET(wSharing) integerValue]; }
- (void)setSharingType:(NSInteger)v { SET(wSharing, [NSNumber numberWithInteger: v]); }
- (NSInteger)animationBehavior { return [GET(wAnimBeh) integerValue]; }
- (void)setAnimationBehavior:(NSInteger)v { SET(wAnimBeh, [NSNumber numberWithInteger: v]); }
- (NSColorSpace *)colorSpace { return GET(wColorSpace) ?: [NSColorSpace sRGBColorSpace]; }
- (void)setColorSpace:(NSColorSpace *)c { SET(wColorSpace, c); }
- (BOOL)canRepresentDisplayGamut:(NSInteger)g { return g == 1; }
- (BOOL)preventsApplicationTerminationWhenModal { id v = GET(wPrevents); return v ? [v boolValue] : YES; }
- (void)setPreventsApplicationTerminationWhenModal:(BOOL)v { SET(wPrevents, B(v)); }
- (NSSize)maxFullScreenContentSize { NSValue *v = GET(wMaxFS); return v ? [v sizeValue] : NSMakeSize(0, 0); }
- (void)setMaxFullScreenContentSize:(NSSize)s { SET(wMaxFS, [NSValue valueWithSize: s]); }
- (NSSize)minFullScreenContentSize { NSValue *v = GET(wMinFS); return v ? [v sizeValue] : NSMakeSize(0, 0); }
- (void)setMinFullScreenContentSize:(NSSize)s { SET(wMinFS, [NSValue valueWithSize: s]); }
- (CGFloat)contentBorderThicknessForEdge:(NSInteger)e { NSDictionary *d = GET(wBorder); return [d[[NSNumber numberWithInteger: e]] doubleValue]; }
- (void)setContentBorderThickness:(CGFloat)t forEdge:(NSInteger)e { NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary: GET(wBorder) ?: @{}]; d[[NSNumber numberWithInteger: e]] = [NSNumber numberWithDouble: t]; SET(wBorder, d); }
- (BOOL)autorecalculatesContentBorderThicknessForEdge:(NSInteger)e { return NO; }
- (void)setAutorecalculatesContentBorderThickness:(BOOL)f forEdge:(NSInteger)e {}
- (NSInteger)orderedIndex { return [GET(wOrdIdx) integerValue]; }
- (void)setOrderedIndex:(NSInteger)i { SET(wOrdIdx, [NSNumber numberWithInteger: i]); }
- (id)appearanceSource { return GET(wAppearanceSource); }
- (void)setAppearanceSource:(id)s { SET(wAppearanceSource, s); }
- (NSArray *)titlebarAccessoryViewControllers { return GET(wTBAcc) ?: [NSArray array]; }
- (void)setTitlebarAccessoryViewControllers:(NSArray *)a { SET(wTBAcc, a); }
- (void)addTitlebarAccessoryViewController:(id)vc { [self setTitlebarAccessoryViewControllers: [[self titlebarAccessoryViewControllers] arrayByAddingObject: vc]]; }
- (void)insertTitlebarAccessoryViewController:(id)vc atIndex:(NSInteger)i { NSMutableArray *m = [NSMutableArray arrayWithArray: [self titlebarAccessoryViewControllers]]; [m insertObject: vc atIndex: MIN((NSUInteger)i, [m count])]; SET(wTBAcc, m); }
- (void)removeTitlebarAccessoryViewControllerAtIndex:(NSInteger)i { NSMutableArray *m = [NSMutableArray arrayWithArray: [self titlebarAccessoryViewControllers]]; if (i >= 0 && (NSUInteger)i < [m count]) [m removeObjectAtIndex: i]; SET(wTBAcc, m); }
- (BOOL)allowsConcurrentViewDrawing { id v = GET(wConc); return v ? [v boolValue] : YES; }
- (void)setAllowsConcurrentViewDrawing:(BOOL)v { SET(wConc, B(v)); }
- (BOOL)canBecomeVisibleWithoutLogin { return [GET(wLogin) boolValue]; }
- (void)setCanBecomeVisibleWithoutLogin:(BOOL)v { SET(wLogin, B(v)); }
- (id)contentLayoutGuide { return nil; }
- (BOOL)inLiveResize { return NO; }
- (void)disableScreenUpdatesUntilFlush {}
- (void)performWindowDragWithEvent:(NSEvent *)e {}
- (BOOL)hasActiveWindowSharingSession { return NO; }
- (void)visualizeConstraints:(NSArray *)c {}
- (NSInteger)windowTitlebarLayoutDirection { return 0; }
@end

