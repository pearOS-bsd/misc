/* CAFilter: a filter type with its input values; the renderer reads the values by key (inputRadius, inputAmount, inputColorMatrix ...). */
#import <QuartzCore/CAFilter.h>

NSString *const kCAFilterGaussianBlur = @"gaussianBlur", *const kCAFilterColorSaturate = @"colorSaturate", *const kCAFilterColorBrightness = @"colorBrightness", *const kCAFilterColorContrast = @"colorContrast",
	*const kCAFilterColorMatrix = @"colorMatrix", *const kCAFilterColorInvert = @"colorInvert", *const kCAFilterColorHueRotate = @"colorHueRotate", *const kCAFilterMultiplyColor = @"multiplyColor",
	*const kCAFilterLuminanceToAlpha = @"luminanceToAlpha", *const kCAFilterVibrantDark = @"vibrantDark", *const kCAFilterVibrantLight = @"vibrantLight";

@implementation CAFilter { NSString *_type, *_name; BOOL _enabled; NSMutableDictionary *_values; }
@synthesize name = _name, type = _type;
+ (NSArray *)filterTypes
{
	return @[kCAFilterGaussianBlur, kCAFilterColorSaturate, kCAFilterColorBrightness, kCAFilterColorContrast, kCAFilterColorMatrix, kCAFilterColorInvert, kCAFilterColorHueRotate, kCAFilterMultiplyColor,
	         kCAFilterLuminanceToAlpha, kCAFilterVibrantDark, kCAFilterVibrantLight];
}
+ (instancetype)filterWithType:(NSString *)type { return [[self alloc] initWithType:type]; }
+ (instancetype)filterWithName:(NSString *)name { return [[self alloc] initWithName:name]; }
- (instancetype)initWithType:(NSString *)type
{
	if (![[CAFilter filterTypes] containsObject:type]) return nil;
	if ((self = [super init])) { _type = [type copy]; _name = [type copy]; _enabled = YES; _values = [NSMutableDictionary new]; }
	return self;
}
- (instancetype)initWithName:(NSString *)name { return [self initWithType:name]; }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)e { _enabled = e; }
- (NSArray *)inputKeys
{
	if ([_type isEqual:kCAFilterGaussianBlur]) return @[@"inputQuality", @"inputRadius", @"inputBounds", @"inputHardEdges", @"inputNormalizeEdges", @"inputNormalizeEdgesTransparent", @"inputDither", @"inputLinear", @"inputIntermediateBitDepth"];
	if ([_type isEqual:kCAFilterColorSaturate] || [_type isEqual:kCAFilterColorBrightness] || [_type isEqual:kCAFilterColorContrast]) return @[@"inputAmount"];
	if ([_type isEqual:kCAFilterColorMatrix]) return @[@"inputColorMatrix", @"inputPremultipliedValues"];
	if ([_type isEqual:kCAFilterColorHueRotate]) return @[@"inputAngle", @"inputHSVSpace"];
	if ([_type isEqual:kCAFilterMultiplyColor]) return @[@"inputColor"];
	if ([_type isEqual:kCAFilterLuminanceToAlpha]) return @[@"inputPremultipliedValues"];
	if ([_type isEqual:kCAFilterVibrantDark] || [_type isEqual:kCAFilterVibrantLight]) return @[@"inputColor0", @"inputColor1", @"inputReversed"];
	return @[];
}
- (NSArray *)outputKeys { return @[]; }
- (void)setDefaults {}
- (void)setValue:(id)v forKey:(NSString *)k
{
	if ([k isEqual:@"name"] || [k isEqual:@"enabled"]) { [super setValue:v forKey:k]; return; }
	if (v) _values[k] = v; else [_values removeObjectForKey:k];
}
- (id)valueForKey:(NSString *)k { if ([k isEqual:@"name"] || [k isEqual:@"type"] || [k isEqual:@"enabled"]) return [super valueForKey:k]; return _values[k]; }
- (void)setValue:(id)v forUndefinedKey:(NSString *)k { [self setValue:v forKey:k]; }
- (id)valueForUndefinedKey:(NSString *)k { return _values[k]; }
- (id)copyWithZone:(NSZone *)z { CAFilter *f = [[CAFilter alloc] initWithType:_type]; f->_name = [_name copy]; f->_enabled = _enabled; f->_values = [_values mutableCopy]; return f; }
- (id)mutableCopyWithZone:(NSZone *)z { return [self copyWithZone:z]; }
- (NSString *)description { return [NSString stringWithFormat:@"<CAFilter %@ %@>", _type, _values]; }
@end
