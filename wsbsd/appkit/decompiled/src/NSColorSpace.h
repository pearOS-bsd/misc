/*
 * NSColorSpace.h — 1:1 reimplementation (core). NSObject <NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSColorSpace : NSObject <NSSecureCoding> {
 *       @ _profile;                                 // NSData (ICC)
 *       {?="colorSpaceID"b8"storageType"b3 …} _flags;
 *       A^{CGColorSpace} _cgColorSpace;             // the backing CGColorSpaceRef
 *       A^{CGColorTransform} _cgColorTransform;
 *   }
 *   @property (Tq,R) numberOfColorComponents;
 *   @property (Tq,R) colorSpaceModel;
 *   @property (T^{CGColorSpace=},R) CGColorSpace;
 *   @property (T@"NSData",R) ICCProfileData;
 *   @property (T@"NSString",R,C) localizedName;
 *   init: -initWithCGColorSpace: -initWithICCProfileData:
 *   named class singletons: +sRGBColorSpace +genericRGBColorSpace
 *     +genericGrayColorSpace +deviceRGBColorSpace +deviceGrayColorSpace
 *     +genericCMYKColorSpace +displayP3ColorSpace …
 *
 * NSColorSpace wraps a CGColorSpaceRef (the `_cgColorSpace` ivar). The model,
 * component count, name and ICC data all come from CoreGraphics, so this core
 * is exact on BSD. The ColorSync profile pointer and the cached CGColorTransform
 * used for cross-space conversion are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSColorSpaceModel) {
    NSColorSpaceModelUnknown = -1,
    NSColorSpaceModelGray = 0,
    NSColorSpaceModelRGB = 1,
    NSColorSpaceModelCMYK = 2,
    NSColorSpaceModelLAB = 3,
    NSColorSpaceModelDeviceN = 4,
    NSColorSpaceModelIndexed = 5,
    NSColorSpaceModelPatterned = 6,
};

@interface NSColorSpace : NSObject

- (nullable instancetype)initWithCGColorSpace:(CGColorSpaceRef)cgColorSpace;

@property (class, readonly, strong) NSColorSpace *sRGBColorSpace;
@property (class, readonly, strong) NSColorSpace *genericRGBColorSpace;
@property (class, readonly, strong) NSColorSpace *genericGrayColorSpace;
@property (class, readonly, strong) NSColorSpace *deviceRGBColorSpace;
@property (class, readonly, strong) NSColorSpace *deviceGrayColorSpace;
@property (class, readonly, strong) NSColorSpace *genericCMYKColorSpace;
@property (class, readonly, strong) NSColorSpace *displayP3ColorSpace;

@property (readonly) NSInteger numberOfColorComponents;
@property (readonly) NSColorSpaceModel colorSpaceModel;
@property (readonly, nullable) CGColorSpaceRef CGColorSpace;
@property (readonly, copy, nullable) NSString *localizedName;

@end

NS_ASSUME_NONNULL_END
