/* More of AppKit's newer API on top of GNUstep: NSScreen (name, colour space, backing conversions, refresh rate), NSSegmentedControl (the per segment calls of the control and its extra properties),
 * NSToolbar (identifiers, removal, centred items), NSTextField (line count, preferred layout width that really shapes the intrinsic size, placeholders), NSLevelIndicator (style, editable, colours),
 * NSView layout guides (safe area, layout margins). State that nothing here draws or acts on is kept and read back. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <math.h>

static void SetAssoc(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static id GetAssoc(id o, const void *k) { return objc_getAssociatedObject(o, k); }

/* ---------------- NSColorSpace / NSScreen ---------------- */
@implementation NSColorSpace (WsdAppKit)
+ (NSColorSpace *)sRGBColorSpace { return [NSColorSpace genericRGBColorSpace]; }
+ (NSColorSpace *)displayP3ColorSpace { return [NSColorSpace genericRGBColorSpace]; }
@end

@implementation NSScreen (WsdAppKit)
+ (BOOL)screensHaveSeparateSpaces { return YES; }
- (NSString *)localizedName { return @"Built-in Display"; }
- (NSColorSpace *)colorSpace { return [NSColorSpace sRGBColorSpace]; }
- (unsigned int)CGDirectDisplayID { return 1; }
- (NSRect)convertRectToBacking:(NSRect)r { CGFloat s = [self backingScaleFactor]; return NSMakeRect(r.origin.x * s, r.origin.y * s, r.size.width * s, r.size.height * s); }
- (NSRect)convertRectFromBacking:(NSRect)r { CGFloat s = [self backingScaleFactor]; return NSMakeRect(r.origin.x / s, r.origin.y / s, r.size.width / s, r.size.height / s); }
- (NSRect)backingAlignedRect:(NSRect)r options:(NSAlignmentOptions)opts
{
	CGFloat s = [self backingScaleFactor]; if (s <= 0) s = 1;
	CGFloat x0 = floor(r.origin.x * s) / s, y0 = floor(r.origin.y * s) / s, x1 = ceil(NSMaxX(r) * s) / s, y1 = ceil(NSMaxY(r) * s) / s;
	if (opts & NSAlignWidthNearest) x1 = round(NSMaxX(r) * s) / s;
	if (opts & NSAlignHeightNearest) y1 = round(NSMaxY(r) * s) / s;
	if (opts & NSAlignMinXNearest) x0 = round(r.origin.x * s) / s;
	if (opts & NSAlignMinYNearest) y0 = round(r.origin.y * s) / s;
	return NSMakeRect(x0, y0, x1 - x0, y1 - y0);
}
- (NSInteger)maximumFramesPerSecond { return 60; }
- (NSTimeInterval)minimumRefreshInterval { return 1.0 / 60.0; }
- (NSTimeInterval)maximumRefreshInterval { return 1.0 / 60.0; }
- (NSTimeInterval)displayUpdateGranularity { return 1.0 / 60.0; }
- (NSTimeInterval)lastDisplayUpdateTimestamp { return [[NSProcessInfo processInfo] systemUptime]; }
- (NSEdgeInsets)safeAreaInsets { return NSEdgeInsetsMake(0, 0, 0, 0); }
- (NSRect)auxiliaryTopLeftArea { return NSZeroRect; }
- (NSRect)auxiliaryTopRightArea { return NSZeroRect; }
- (BOOL)canRepresentDisplayGamut:(NSInteger)gamut { return gamut == 1; }                      /* NSDisplayGamutSRGB only */
- (CGFloat)maximumExtendedDynamicRangeColorComponentValue { return 1.0; }
- (CGFloat)maximumPotentialExtendedDynamicRangeColorComponentValue { return 1.0; }
- (CGFloat)maximumReferenceExtendedDynamicRangeColorComponentValue { return 1.0; }
@end

/* ---------------- NSSegmentedControl ---------------- */
static char kSegAlign, kSegMenu, kSegProps;
@implementation NSSegmentedControl (WsdAppKit)
- (NSInteger)tagForSegment:(NSInteger)s { return [(NSSegmentedCell *)[self cell] tagForSegment: s]; }
- (void)setTag:(NSInteger)tag forSegment:(NSInteger)s { [(NSSegmentedCell *)[self cell] setTag: tag forSegment: s]; }
- (NSInteger)indexOfSelectedItem { return [self selectedSegment]; }
- (double)doubleValueForSelectedSegment { NSInteger s = [self selectedSegment]; return s < 0 ? 0 : (double)[self tagForSegment: s]; }
- (NSTextAlignment)alignmentForSegment:(NSInteger)s { NSDictionary *d = GetAssoc(self, &kSegAlign); return d[@(s)] ? (NSTextAlignment)[d[@(s)] integerValue] : NSTextAlignmentCenter; }
- (void)setAlignment:(NSTextAlignment)a forSegment:(NSInteger)s
{
	NSMutableDictionary *d = [[GetAssoc(self, &kSegAlign) mutableCopy] autorelease]; if (!d) d = [NSMutableDictionary dictionary]; d[@(s)] = @(a); SetAssoc(self, &kSegAlign, d); [self setNeedsDisplay: YES];
}
- (BOOL)showsMenuIndicatorForSegment:(NSInteger)s { NSDictionary *d = GetAssoc(self, &kSegMenu); return [d[@(s)] boolValue]; }
- (void)setShowsMenuIndicator:(BOOL)b forSegment:(NSInteger)s
{
	NSMutableDictionary *d = [[GetAssoc(self, &kSegMenu) mutableCopy] autorelease]; if (!d) d = [NSMutableDictionary dictionary]; d[@(s)] = @(b); SetAssoc(self, &kSegMenu, d); [self setNeedsDisplay: YES];
}
static id SegProp(id o, NSString *k) { return [GetAssoc(o, &kSegProps) objectForKey: k]; }
static void SetSegProp(id o, NSString *k, id v)
{
	NSMutableDictionary *d = [[GetAssoc(o, &kSegProps) mutableCopy] autorelease]; if (!d) d = [NSMutableDictionary dictionary]; if (v) d[k] = v; else [d removeObjectForKey: k]; SetAssoc(o, &kSegProps, d);
}
- (NSInteger)segmentDistribution { return [SegProp(self, @"dist") integerValue]; }
- (void)setSegmentDistribution:(NSInteger)v { SetSegProp(self, @"dist", @(v)); [self setNeedsDisplay: YES]; }
- (NSInteger)borderShape { return [SegProp(self, @"shape") integerValue]; }
- (void)setBorderShape:(NSInteger)v { SetSegProp(self, @"shape", @(v)); }
- (NSInteger)role { return [SegProp(self, @"role") integerValue]; }
- (void)setRole:(NSInteger)v { SetSegProp(self, @"role", @(v)); }
- (BOOL)isSpringLoaded { return [SegProp(self, @"spring") boolValue]; }
- (void)setSpringLoaded:(BOOL)b { SetSegProp(self, @"spring", @(b)); }
- (NSColor *)selectedSegmentBezelColor { return SegProp(self, @"bezel"); }
- (void)setSelectedSegmentBezelColor:(NSColor *)c { SetSegProp(self, @"bezel", c); [self setNeedsDisplay: YES]; }
@end

/* ---------------- NSToolbar ---------------- */
static char kTBProps;
@implementation NSToolbar (WsdAppKit)
- (NSArray *)itemIdentifiers { NSMutableArray *a = [NSMutableArray array]; for (NSToolbarItem *i in [self items]) [a addObject: [i itemIdentifier]]; return a; }
- (void)removeItemWithItemIdentifier:(NSString *)ident
{
	NSArray *items = [self items];
	for (NSInteger i = (NSInteger)[items count] - 1; i >= 0; i--) if ([[[items objectAtIndex: (NSUInteger)i] itemIdentifier] isEqual: ident]) [self removeItemAtIndex: i];
}
- (void)setItemIdentifiers:(NSArray *)ids
{
	for (NSInteger i = (NSInteger)[[self items] count] - 1; i >= 0; i--) [self removeItemAtIndex: i];
	NSInteger at = 0; for (NSString *ident in ids) [self insertItemWithItemIdentifier: ident atIndex: at++];
}
static id TBProp(id o, NSString *k) { return [GetAssoc(o, &kTBProps) objectForKey: k]; }
static void SetTBProp(id o, NSString *k, id v)
{
	NSMutableDictionary *d = [[GetAssoc(o, &kTBProps) mutableCopy] autorelease]; if (!d) d = [NSMutableDictionary dictionary]; if (v) d[k] = v; else [d removeObjectForKey: k]; SetAssoc(o, &kTBProps, d);
}
- (NSArray *)centeredItemIdentifiers { return TBProp(self, @"centered") ?: [NSArray array]; }
- (void)setCenteredItemIdentifiers:(NSArray *)a { SetTBProp(self, @"centered", [[a copy] autorelease]); }
- (NSString *)centeredItemIdentifier { return [[self centeredItemIdentifiers] firstObject]; }
- (void)setCenteredItemIdentifier:(NSString *)i { [self setCenteredItemIdentifiers: i ? [NSArray arrayWithObject: i] : nil]; }
- (BOOL)allowsDisplayModeCustomization { NSNumber *n = TBProp(self, @"dmc"); return n ? [n boolValue] : YES; }
- (void)setAllowsDisplayModeCustomization:(BOOL)b { SetTBProp(self, @"dmc", @(b)); }
- (BOOL)allowsExtensionItems { return [TBProp(self, @"ext") boolValue]; }
- (void)setAllowsExtensionItems:(BOOL)b { SetTBProp(self, @"ext", @(b)); }
- (NSView *)fullScreenAccessoryView { return TBProp(self, @"fsav"); }
- (void)setFullScreenAccessoryView:(NSView *)v { SetTBProp(self, @"fsav", v); }
- (CGFloat)fullScreenAccessoryViewMinHeight { NSNumber *n = TBProp(self, @"fsmin"); return n ? [n doubleValue] : 0; }
- (void)setFullScreenAccessoryViewMinHeight:(CGFloat)h { SetTBProp(self, @"fsmin", @(h)); }
- (CGFloat)fullScreenAccessoryViewMaxHeight { NSNumber *n = TBProp(self, @"fsmax"); return n ? [n doubleValue] : 0; }
- (void)setFullScreenAccessoryViewMaxHeight:(CGFloat)h { SetTBProp(self, @"fsmax", @(h)); }
@end

/* ---------------- NSTextField ---------------- */
static char kTFProps;
static id TFProp(id o, NSString *k) { return [GetAssoc(o, &kTFProps) objectForKey: k]; }
static void SetTFProp(id o, NSString *k, id v)
{
	NSMutableDictionary *d = [[GetAssoc(o, &kTFProps) mutableCopy] autorelease]; if (!d) d = [NSMutableDictionary dictionary]; if (v) d[k] = v; else [d removeObjectForKey: k]; SetAssoc(o, &kTFProps, d);
}
@implementation NSTextField (WsdAppKit)
- (NSInteger)maximumNumberOfLines { return [TFProp(self, @"lines") integerValue]; }
- (void)setMaximumNumberOfLines:(NSInteger)n
{
	SetTFProp(self, @"lines", @(n));
	if (n == 1) { [[self cell] setWraps: NO]; [[self cell] setLineBreakMode: NSLineBreakByTruncatingTail]; } else if (n != 1) [[self cell] setWraps: YES];
	[self invalidateIntrinsicContentSize]; [self setNeedsDisplay: YES];
}
- (CGFloat)preferredMaxLayoutWidth { return [TFProp(self, @"pmlw") doubleValue]; }
- (void)setPreferredMaxLayoutWidth:(CGFloat)w { SetTFProp(self, @"pmlw", @(w)); [self invalidateIntrinsicContentSize]; }
- (NSSize)intrinsicContentSize                                                                     /* a wrapping label with a preferred width is as tall as its text needs at that width */
{
	CGFloat w = [self preferredMaxLayoutWidth]; NSCell *c = [self cell];
	if (w > 0 && [c wraps]) {
		NSSize s = [[c attributedStringValue] boundingRectWithSize: NSMakeSize(w, 100000) options: NSStringDrawingUsesLineFragmentOrigin].size; s.height = ceil(s.height); NSInteger n = [self maximumNumberOfLines];   /* the cell's own cellSizeForBounds: ignores the width */
		if (n > 0) { CGFloat line = [[c font] defaultLineHeightForFont]; CGFloat max = line * n + (s.height - ceil(s.height / (line > 0 ? line : 1)) * line); if (s.height > max && line > 0) s.height = max; }
		return NSMakeSize(w, s.height);
	}
	return c ? [c cellSize] : NSMakeSize(-1, -1);
}
- (NSArray *)placeholderStrings { return TFProp(self, @"phs") ?: ([self placeholderString] ? [NSArray arrayWithObject: [self placeholderString]] : [NSArray array]); }
- (void)setPlaceholderStrings:(NSArray *)a { SetTFProp(self, @"phs", [[a copy] autorelease]); if ([a count]) [self setPlaceholderString: [a objectAtIndex: 0]]; }
- (NSArray *)placeholderAttributedStrings { return TFProp(self, @"phas") ?: ([self placeholderAttributedString] ? [NSArray arrayWithObject: [self placeholderAttributedString]] : [NSArray array]); }
- (void)setPlaceholderAttributedStrings:(NSArray *)a { SetTFProp(self, @"phas", [[a copy] autorelease]); if ([a count]) [self setPlaceholderAttributedString: [a objectAtIndex: 0]]; }
- (NSInteger)lineBreakStrategy { return [TFProp(self, @"lbs") integerValue]; }
- (void)setLineBreakStrategy:(NSInteger)v { SetTFProp(self, @"lbs", @(v)); }
- (BOOL)allowsDefaultTighteningForTruncation { return [TFProp(self, @"tight") boolValue]; }
- (void)setAllowsDefaultTighteningForTruncation:(BOOL)b { SetTFProp(self, @"tight", @(b)); }
- (BOOL)isAutomaticTextCompletionEnabled { NSNumber *n = TFProp(self, @"atc"); return n ? [n boolValue] : YES; }
- (void)setAutomaticTextCompletionEnabled:(BOOL)b { SetTFProp(self, @"atc", @(b)); }
- (BOOL)resolvesNaturalAlignmentWithBaseWritingDirection { return [TFProp(self, @"rna") boolValue]; }
- (void)setResolvesNaturalAlignmentWithBaseWritingDirection:(BOOL)b { SetTFProp(self, @"rna", @(b)); }
- (NSInteger)borderShape { return [TFProp(self, @"shape") integerValue]; }
- (void)setBorderShape:(NSInteger)v { SetTFProp(self, @"shape", @(v)); }
@end

/* ---------------- NSLevelIndicator ---------------- */
static char kLIProps;
static id LIProp(id o, NSString *k) { return [GetAssoc(o, &kLIProps) objectForKey: k]; }
static void SetLIProp(id o, NSString *k, id v)
{
	NSMutableDictionary *d = [[GetAssoc(o, &kLIProps) mutableCopy] autorelease]; if (!d) d = [NSMutableDictionary dictionary]; if (v) d[k] = v; else [d removeObjectForKey: k]; SetAssoc(o, &kLIProps, d);
}
@implementation NSLevelIndicator (WsdAppKit)
- (NSLevelIndicatorStyle)levelIndicatorStyle { return [(NSLevelIndicatorCell *)[self cell] levelIndicatorStyle]; }
- (void)setLevelIndicatorStyle:(NSLevelIndicatorStyle)s { [(NSLevelIndicatorCell *)[self cell] setLevelIndicatorStyle: s]; [self setNeedsDisplay: YES]; }
- (BOOL)isEditable { return [(NSLevelIndicatorCell *)[self cell] isEditable]; }
- (void)setEditable:(BOOL)b { [(NSLevelIndicatorCell *)[self cell] setEditable: b]; }
- (NSColor *)fillColor { return LIProp(self, @"fill"); }
- (void)setFillColor:(NSColor *)c { SetLIProp(self, @"fill", c); [self setNeedsDisplay: YES]; }
- (NSColor *)warningFillColor { return LIProp(self, @"warn"); }
- (void)setWarningFillColor:(NSColor *)c { SetLIProp(self, @"warn", c); [self setNeedsDisplay: YES]; }
- (NSColor *)criticalFillColor { return LIProp(self, @"crit"); }
- (void)setCriticalFillColor:(NSColor *)c { SetLIProp(self, @"crit", c); [self setNeedsDisplay: YES]; }
- (BOOL)drawsTieredCapacityLevels { NSNumber *n = LIProp(self, @"tier"); return n ? [n boolValue] : YES; }
- (void)setDrawsTieredCapacityLevels:(BOOL)b { SetLIProp(self, @"tier", @(b)); [self setNeedsDisplay: YES]; }
- (NSInteger)placeholderVisibility { return [LIProp(self, @"phv") integerValue]; }
- (void)setPlaceholderVisibility:(NSInteger)v { SetLIProp(self, @"phv", @(v)); }
- (NSImage *)ratingImage { return LIProp(self, @"rate"); }
- (void)setRatingImage:(NSImage *)i { SetLIProp(self, @"rate", i); [self setNeedsDisplay: YES]; }
- (NSImage *)ratingPlaceholderImage { return LIProp(self, @"ratep"); }
- (void)setRatingPlaceholderImage:(NSImage *)i { SetLIProp(self, @"ratep", i); [self setNeedsDisplay: YES]; }
@end

/* ---------------- NSView layout guides ---------------- */
static char kSafeGuide, kMarginGuide;
@interface NSView (WsdLayoutGuidesPrivate) - (NSLayoutGuide *)wsdPinnedGuide:(const void *)key insets:(NSEdgeInsets)in; @end
@implementation NSView (WsdLayoutGuides)
- (NSLayoutGuide *)wsdPinnedGuide:(const void *)key insets:(NSEdgeInsets)in                         /* a guide whose edges follow the view's, inset */
{
	NSLayoutGuide *g = GetAssoc(self, key); if (g) return g;
	g = [[[NSLayoutGuide alloc] init] autorelease]; [self addLayoutGuide: g];
	[[g leadingAnchor] constraintEqualToAnchor: [self leadingAnchor] constant: in.left].active = YES;
	[[g trailingAnchor] constraintEqualToAnchor: [self trailingAnchor] constant: -in.right].active = YES;
	[[g topAnchor] constraintEqualToAnchor: [self topAnchor] constant: in.top].active = YES;
	[[g bottomAnchor] constraintEqualToAnchor: [self bottomAnchor] constant: -in.bottom].active = YES;
	SetAssoc(self, key, g); return g;
}
- (NSLayoutGuide *)safeAreaLayoutGuide { return [self wsdPinnedGuide: &kSafeGuide insets: NSEdgeInsetsMake(0, 0, 0, 0)]; }       /* no notch, no hidden title bar: the whole view */
- (NSLayoutGuide *)layoutMarginsGuide { return [self wsdPinnedGuide: &kMarginGuide insets: NSEdgeInsetsMake(0, 0, 0, 0)]; }
@end
