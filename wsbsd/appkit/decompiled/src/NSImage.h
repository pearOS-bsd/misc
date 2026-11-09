/*
 * NSImage.h — 1:1 reimplementation (core). NSObject (class cluster-ish).
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSImage : NSObject <NSCopying, NSSecureCoding, …> {
 *       @"NSString" _name;  {CGSize} _size;  @"<NSImageRepProvider>" _reps;
 *       {NSEdgeInsets} _capInsets;  q _resizingMode;  @"NSColor" _tintColor;
 *       {?="scalable"b1 … "sizeWasExplicitlySet"b1 … "isTemplate"b1 …} _flags;
 *   }
 *   +imageNamed: -initWithSize: -name -setName: -size -setSize:
 *   -representations -addRepresentation: -isTemplate -setTemplate:
 *
 * Holds the image name, explicit/derived size, the representation list and the
 * template flag (_flags bit). When the size was never set explicitly it is
 * derived from the largest representation. setName:/imageNamed: use the process
 * named-image registry; loading named images from bundles / asset catalogs and
 * all drawing/caching are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/* Representations expose a size; the real type is NSImageRep. */
@protocol NSImageRepSizing <NSObject>
- (CGSize)size;
@end

@interface NSImage : NSObject <NSCopying>

- (instancetype)initWithSize:(CGSize)size;
+ (nullable NSImage *)imageNamed:(NSString *)name;

@property CGSize size;
- (nullable NSString *)name;
- (BOOL)setName:(nullable NSString *)name;

- (BOOL)isTemplate;
- (void)setTemplate:(BOOL)flag;

- (NSArray *)representations;
- (void)addRepresentation:(id<NSImageRepSizing>)imageRep;
- (void)addRepresentations:(NSArray<id<NSImageRepSizing>> *)imageReps;
- (void)removeRepresentation:(id<NSImageRepSizing>)imageRep;

@end

NS_ASSUME_NONNULL_END
