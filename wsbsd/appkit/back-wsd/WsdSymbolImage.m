/* SF Symbols as NSImage: +imageWithSystemSymbolName:accessibilityDescription:, NSImageSymbolConfiguration (point size, weight, scale, palette / hierarchical colours) and
 * -imageWithSymbolConfiguration:. The image draws the symbol's vector glyph from the system's CoreGlyphs catalogue (WsdFilePanel.m's decoder, coreui/bvg.c) each time it is drawn, so it is
 * sharp at every size and takes the colour of a template (labelColor unless a configuration gives colours). Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

NSSize WsdSymbolSize(NSString *name, CGFloat pointSize, int weight);
BOOL WsdSymbolDraw(NSString *name, NSRect cell, CGFloat pointSize, int weight, NSColor *tint);

@interface NSImageSymbolConfiguration : NSObject <NSCopying> { @public CGFloat pointSize; double weight; NSInteger scale; NSArray *palette; NSColor *hierarchical; BOOL hasSize, hasWeight, hasScale; } @end
@implementation NSImageSymbolConfiguration
+ (id)configurationWithPointSize:(CGFloat)p weight:(double)w { NSImageSymbolConfiguration *c = [[[self alloc] init] autorelease]; c->pointSize = p; c->hasSize = YES; c->weight = w; c->hasWeight = YES; return c; }
+ (id)configurationWithPointSize:(CGFloat)p weight:(double)w scale:(NSInteger)s { NSImageSymbolConfiguration *c = [self configurationWithPointSize: p weight: w]; c->scale = s; c->hasScale = YES; return c; }
+ (id)configurationWithScale:(NSInteger)s { NSImageSymbolConfiguration *c = [[[self alloc] init] autorelease]; c->scale = s; c->hasScale = YES; return c; }
+ (id)configurationWithTextStyle:(NSString *)style { NSImageSymbolConfiguration *c = [[[self alloc] init] autorelease]; c->pointSize = [NSFont systemFontSize]; c->hasSize = YES; if ([style isEqual: @"NSFontTextStyleLargeTitle"]) c->pointSize = 26; else if ([style isEqual: @"NSFontTextStyleTitle1"]) c->pointSize = 22; else if ([style isEqual: @"NSFontTextStyleTitle2"]) c->pointSize = 17; else if ([style isEqual: @"NSFontTextStyleTitle3"]) c->pointSize = 15; else if ([style isEqual: @"NSFontTextStyleHeadline"]) c->pointSize = 13; else if ([style isEqual: @"NSFontTextStyleSubheadline"]) c->pointSize = 11; else if ([style isEqual: @"NSFontTextStyleCallout"]) c->pointSize = 12; else if ([style isEqual: @"NSFontTextStyleFootnote"]) c->pointSize = 10; else if ([style isEqual: @"NSFontTextStyleCaption1"] || [style isEqual: @"NSFontTextStyleCaption2"]) c->pointSize = 10; return c; }
+ (id)configurationWithPaletteColors:(NSArray *)colors { NSImageSymbolConfiguration *c = [[[self alloc] init] autorelease]; c->palette = [colors copy]; return c; }
+ (id)configurationWithHierarchicalColor:(NSColor *)color { NSImageSymbolConfiguration *c = [[[self alloc] init] autorelease]; c->hierarchical = [color retain]; return c; }
+ (id)configurationPreferringMonochrome { return [[[self alloc] init] autorelease]; }
+ (id)configurationPreferringMulticolor { return [[[self alloc] init] autorelease]; }
- (id)configurationByApplyingConfiguration:(NSImageSymbolConfiguration *)o
{
	NSImageSymbolConfiguration *c = [[self copy] autorelease];
	if (o->hasSize) { c->pointSize = o->pointSize; c->hasSize = YES; }
	if (o->hasWeight) { c->weight = o->weight; c->hasWeight = YES; }
	if (o->hasScale) { c->scale = o->scale; c->hasScale = YES; }
	if (o->palette) { [c->palette release]; c->palette = [o->palette retain]; }
	if (o->hierarchical) { [c->hierarchical release]; c->hierarchical = [o->hierarchical retain]; }
	return c;
}
- (id)configurationByApplyingPaletteColors:(NSArray *)colors { return [self configurationByApplyingConfiguration: [NSImageSymbolConfiguration configurationWithPaletteColors: colors]]; }
- (id)copyWithZone:(NSZone *)z { NSImageSymbolConfiguration *c = [[NSImageSymbolConfiguration allocWithZone: z] init]; c->pointSize = pointSize; c->weight = weight; c->scale = scale; c->palette = [palette retain]; c->hierarchical = [hierarchical retain]; c->hasSize = hasSize; c->hasWeight = hasWeight; c->hasScale = hasScale; return c; }
- (void)dealloc { [palette release]; [hierarchical release]; [super dealloc]; }
@end

static int WeightIndex(double w) { static const double v[] = { -0.8, -0.6, -0.4, 0.0, 0.23, 0.3, 0.4, 0.56, 0.62 }; int best = 3; for (int i = 0; i < 9; i++) if (fabs(w - v[i]) < fabs(w - v[best])) best = i; return best + 1; }

@interface WsdSymbolImage : NSImage { NSString *_sym; NSImageSymbolConfiguration *_config; NSString *_desc; } - (id)initWithSymbol:(NSString *)n config:(NSImageSymbolConfiguration *)c; @end
@implementation WsdSymbolImage
- (CGFloat)wsdPoints { CGFloat p = (_config && _config->hasSize) ? _config->pointSize : 13; NSInteger s = (_config && _config->hasScale) ? _config->scale : 2; return p * (s == 1 ? 0.85 : s == 3 ? 1.3 : 1.0); }
- (int)wsdWeight { return (_config && _config->hasWeight) ? WeightIndex(_config->weight) : 4; }
- (id)initWithSymbol:(NSString *)n config:(NSImageSymbolConfiguration *)c
{
	CGFloat p = (c && c->hasSize) ? c->pointSize : 13; NSInteger s = (c && c->hasScale) ? c->scale : 2; p *= (s == 1 ? 0.85 : s == 3 ? 1.3 : 1.0);
	NSSize sz = WsdSymbolSize(n, p, (c && c->hasWeight) ? WeightIndex(c->weight) : 4);
	if (sz.width <= 0) { [self release]; return nil; }
	if ((self = [super initWithSize: NSMakeSize(ceil(sz.width), ceil(sz.height))])) { _sym = [n copy]; _config = [c retain]; [self setTemplate: YES]; }
	return self;
}
- (NSString *)wsdSymbolName { return _sym; }
- (NSImageSymbolConfiguration *)symbolConfiguration { return _config; }
- (NSString *)accessibilityDescription { return _desc; }
- (void)setAccessibilityDescription:(NSString *)d { [_desc release]; _desc = [d copy]; }
- (void)wsdDrawIn:(NSRect)dst fraction:(CGFloat)f
{
	NSColor *tint = _config && [_config->palette count] ? [_config->palette objectAtIndex: 0] : _config && _config->hierarchical ? _config->hierarchical : [NSColor labelColor];
	if (f < 1) tint = [tint colorWithAlphaComponent: [tint alphaComponent] * f];
	NSSize own = [self size]; CGFloat p = [self wsdPoints] * (own.width > 0 ? dst.size.width / own.width : 1);
	WsdSymbolDraw(_sym, dst, p, [self wsdWeight], tint);
}
- (void)drawInRect:(NSRect)r fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsdDrawIn: r fraction: f]; }
- (void)drawInRect:(NSRect)r fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f respectFlipped:(BOOL)flip hints:(NSDictionary *)h { [self wsdDrawIn: r fraction: f]; }   /* what the cells (NSButtonCell, NSImageCell, NSCell) call */
- (void)drawInRect:(NSRect)r { [self wsdDrawIn: r fraction: 1]; }
- (void)drawAtPoint:(NSPoint)p fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsdDrawIn: NSMakeRect(p.x, p.y, [self size].width, [self size].height) fraction: f]; }
- (void)compositeToPoint:(NSPoint)p operation:(NSCompositingOperation)op { [self wsdDrawIn: NSMakeRect(p.x, p.y, [self size].width, [self size].height) fraction: 1]; }
- (void)compositeToPoint:(NSPoint)p operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsdDrawIn: NSMakeRect(p.x, p.y, [self size].width, [self size].height) fraction: f]; }
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
- (void)dealloc { [_sym release]; [_config release]; [_desc release]; [super dealloc]; }
@end

@implementation NSImage (WsdSymbols)
+ (NSImage *)imageWithSystemSymbolName:(NSString *)n accessibilityDescription:(NSString *)d
{
	WsdSymbolImage *i = [[WsdSymbolImage alloc] initWithSymbol: n config: nil];
	[i setAccessibilityDescription: d]; return [i autorelease];
}
+ (NSImage *)imageWithSystemSymbolName:(NSString *)n variableValue:(double)v accessibilityDescription:(NSString *)d { return [self imageWithSystemSymbolName: n accessibilityDescription: d]; }
- (NSImage *)imageWithSymbolConfiguration:(NSImageSymbolConfiguration *)c
{
	if (![self isKindOfClass: [WsdSymbolImage class]]) return self;
	WsdSymbolImage *s = (WsdSymbolImage *)self;
	NSImageSymbolConfiguration *m = [s symbolConfiguration] ? [[s symbolConfiguration] configurationByApplyingConfiguration: c] : c;
	WsdSymbolImage *i = [[WsdSymbolImage alloc] initWithSymbol: [s wsdSymbolName] config: m];
	[i setAccessibilityDescription: [s accessibilityDescription]]; return [i autorelease];
}
- (NSImageSymbolConfiguration *)symbolConfiguration { return nil; }
@end
