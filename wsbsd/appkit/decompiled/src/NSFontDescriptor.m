/*
 * NSFontDescriptor.m — 1:1 (core). See NSFontDescriptor.h for interface evidence.
 *
 * All state is the `_attributes` dictionary. postscriptName/pointSize read the
 * name/size keys; symbolicTraits reads attributes[traits][symbolicTrait].
 * The fontDescriptorBy…/With… methods return a NEW descriptor with the given
 * attribute merged in — descriptors are immutable, matching AppKit. Matching
 * against installed fonts is stage2.
 */
#import "NSFontDescriptor.h"

@implementation NSFontDescriptor {
    NSDictionary *_attributes;
}

- (instancetype)_initWithAttributes:(NSDictionary *)attributes
{
    self = [super init];
    if (self) _attributes = [attributes copy] ?: @{};
    return self;
}

+ (NSFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary *)attributes
{ return [[self alloc] _initWithAttributes:attributes]; }

+ (NSFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size
{
    return [self fontDescriptorWithFontAttributes:@{
        NSFontNameAttribute: fontName ?: @"",
        NSFontSizeAttribute: @(size),
    }];
}

- (NSDictionary *)fontAttributes { return _attributes; }
- (id)objectForKey:(NSString *)attribute { return _attributes[attribute]; }

- (NSString *)postscriptName
{
    id n = _attributes[NSFontNameAttribute];
    return [n isKindOfClass:[NSString class]] ? n : nil;
}

- (CGFloat)pointSize
{
    id s = _attributes[NSFontSizeAttribute];
    return [s respondsToSelector:@selector(doubleValue)] ? [s doubleValue] : 0.0;
}

- (NSFontSymbolicTraits)symbolicTraits
{
    id traits = _attributes[NSFontTraitsAttribute];
    if (![traits isKindOfClass:[NSDictionary class]]) return 0;
    id sym = traits[NSFontSymbolicTrait];
    return [sym respondsToSelector:@selector(unsignedIntValue)] ? [sym unsignedIntValue] : 0;
}

- (NSFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary *)attributes
{
    NSMutableDictionary *merged = [_attributes mutableCopy];
    [merged addEntriesFromDictionary:attributes];
    return [NSFontDescriptor fontDescriptorWithFontAttributes:merged];
}

- (NSFontDescriptor *)fontDescriptorWithSymbolicTraits:(NSFontSymbolicTraits)symbolicTraits
{
    return [self fontDescriptorByAddingAttributes:@{
        NSFontTraitsAttribute: @{ NSFontSymbolicTrait: @(symbolicTraits) },
    }];
}

- (NSFontDescriptor *)fontDescriptorWithSize:(CGFloat)newPointSize
{ return [self fontDescriptorByAddingAttributes:@{ NSFontSizeAttribute: @(newPointSize) }]; }

- (NSFontDescriptor *)fontDescriptorWithFace:(NSString *)newFace
{ return [self fontDescriptorByAddingAttributes:@{ (NSString *)kCTFontStyleNameAttribute: newFace }]; }

- (NSFontDescriptor *)fontDescriptorWithFamily:(NSString *)newFamily
{ return [self fontDescriptorByAddingAttributes:@{ NSFontFamilyAttribute: newFamily }]; }

- (id)copyWithZone:(NSZone *)zone { return self; } /* immutable */

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSFontDescriptor class]]) return NO;
    return [((NSFontDescriptor *)object)->_attributes isEqualToDictionary:_attributes];
}

- (NSUInteger)hash { return _attributes.hash; }

@end
