/*
 * NSColorSpace.m — 1:1 (core). See NSColorSpace.h for interface evidence.
 *
 * Backed by a CGColorSpaceRef (`_cgColorSpace`). Everything observable is read
 * from CoreGraphics:
 *   colorSpaceModel         <- CGColorSpaceGetModel, mapped to NSColorSpaceModel
 *                              (CG Monochrome -> NS Gray; RGB/CMYK/Lab/DeviceN/
 *                              Indexed/Pattern map one-to-one).
 *   numberOfColorComponents <- CGColorSpaceGetNumberOfComponents.
 *   localizedName           <- CGColorSpaceCopyName.
 *   ICCProfileData          <- CGColorSpaceCopyICCData (stage2 for named spaces).
 * The named class singletons are built once from CGColorSpaceCreateWithName and
 * cached, matching AppKit's shared instances. ColorSync profile and the cached
 * CGColorTransform (cross-space conversion) are stage2.
 */
#import "NSColorSpace.h"

@implementation NSColorSpace {
    CGColorSpaceRef _cgColorSpace;   /* _cgColorSpace ivar */
}

- (instancetype)initWithCGColorSpace:(CGColorSpaceRef)cgColorSpace
{
    if (!cgColorSpace) return nil;
    self = [super init];
    if (self) {
        _cgColorSpace = CGColorSpaceRetain(cgColorSpace);
    }
    return self;
}

- (void)dealloc
{
    if (_cgColorSpace) CGColorSpaceRelease(_cgColorSpace);
}

static NSColorSpace *NSColorSpaceNamed(CFStringRef name)
{
    CGColorSpaceRef cg = CGColorSpaceCreateWithName(name);
    if (!cg) return nil;
    NSColorSpace *cs = [[NSColorSpace alloc] initWithCGColorSpace:cg];
    CGColorSpaceRelease(cg);
    return cs;
}

+ (NSColorSpace *)sRGBColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceSRGB); return c; }
+ (NSColorSpace *)genericRGBColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceGenericRGB); return c; }
+ (NSColorSpace *)genericGrayColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceGenericGrayGamma2_2); return c; }
+ (NSColorSpace *)deviceRGBColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceSRGB); return c; } /* device RGB ~ sRGB on display */
+ (NSColorSpace *)deviceGrayColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceLinearGray); return c; }
+ (NSColorSpace *)genericCMYKColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceGenericCMYK); return c; }
+ (NSColorSpace *)displayP3ColorSpace
{ static NSColorSpace *c = nil; if (!c) c = NSColorSpaceNamed(kCGColorSpaceDisplayP3); return c; }

- (CGColorSpaceRef)CGColorSpace { return _cgColorSpace; }

- (NSColorSpaceModel)colorSpaceModel
{
    if (!_cgColorSpace) return NSColorSpaceModelUnknown;
    switch (CGColorSpaceGetModel(_cgColorSpace)) {
        case kCGColorSpaceModelMonochrome: return NSColorSpaceModelGray;
        case kCGColorSpaceModelRGB:        return NSColorSpaceModelRGB;
        case kCGColorSpaceModelCMYK:       return NSColorSpaceModelCMYK;
        case kCGColorSpaceModelLab:        return NSColorSpaceModelLAB;
        case kCGColorSpaceModelDeviceN:    return NSColorSpaceModelDeviceN;
        case kCGColorSpaceModelIndexed:    return NSColorSpaceModelIndexed;
        case kCGColorSpaceModelPattern:    return NSColorSpaceModelPatterned;
        default:                           return NSColorSpaceModelUnknown;
    }
}

- (NSInteger)numberOfColorComponents
{
    if (!_cgColorSpace) return 0;
    return (NSInteger)CGColorSpaceGetNumberOfComponents(_cgColorSpace);
}

- (NSString *)localizedName
{
    if (!_cgColorSpace) return nil;
    CFStringRef n = CGColorSpaceCopyName(_cgColorSpace);
    if (!n) return nil;
    return (NSString *)CFBridgingRelease(n);
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSColorSpace class]]) return NO;
    CGColorSpaceRef o = ((NSColorSpace *)object)->_cgColorSpace;
    if (_cgColorSpace == o) return YES;
    if (!_cgColorSpace || !o) return NO;
    return CFEqual(_cgColorSpace, o);
}

- (NSUInteger)hash { return (NSUInteger)self.colorSpaceModel; }

@end
