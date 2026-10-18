/* CAFilter: the filter objects of layers (-filters, -backgroundFilters, -compositingFilter). Not public on Apple's side but used by AppKit and by applications. */
#import <Foundation/Foundation.h>
#import <QuartzCore/CABase.h>

CA_EXTERN NSString *const kCAFilterGaussianBlur, *const kCAFilterColorSaturate, *const kCAFilterColorBrightness, *const kCAFilterColorContrast, *const kCAFilterColorMatrix, *const kCAFilterColorInvert,
	*const kCAFilterColorHueRotate, *const kCAFilterMultiplyColor, *const kCAFilterLuminanceToAlpha, *const kCAFilterVibrantDark, *const kCAFilterVibrantLight;

@interface CAFilter : NSObject <NSCopying, NSMutableCopying>
+ (instancetype)filterWithType:(NSString *)type;
+ (instancetype)filterWithName:(NSString *)name;
+ (NSArray *)filterTypes;
- (instancetype)initWithType:(NSString *)type;
- (instancetype)initWithName:(NSString *)name;
@property(copy) NSString *name;
@property(readonly) NSString *type;
@property(getter=isEnabled) BOOL enabled;
- (NSArray *)inputKeys;
- (NSArray *)outputKeys;
- (void)setDefaults;
@end
