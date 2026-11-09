/*
 * NSUserInterfaceCompressionOptions.h — 1:1 reimplementation (core).
 * NSObject <NSSecureCoding, NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSUserInterfaceCompressionOptions : NSObject <NSCopying, …> {
 *       @"NSSet" _identifiers;
 *   }
 *   @property (TB,R,GisEmpty) empty;
 *   +standardOptions +breakEqualWidthsOption +hideImagesOption +hideTextOption
 *   +reduceMetricsOption -initWithIdentifier: -containsOptions: -intersectsOptions:
 *   -optionsByAddingOptions: -optionsByRemovingOptions:
 *
 * An immutable set of compression-option identifiers with set algebra. The
 * standard options are single-identifier singletons; standardOptions is their
 * union. Exact per-control compression behaviour is stage2; the set model is
 * exact.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSUserInterfaceCompressionOptions : NSObject <NSCopying>

- (instancetype)initWithIdentifier:(NSString *)identifier;
- (instancetype)initWithIdentifiers:(NSArray<NSString *> *)identifiers;

@property (class, readonly, copy) NSUserInterfaceCompressionOptions *standardOptions;
@property (class, readonly, copy) NSUserInterfaceCompressionOptions *breakEqualWidthsOption;
@property (class, readonly, copy) NSUserInterfaceCompressionOptions *hideImagesOption;
@property (class, readonly, copy) NSUserInterfaceCompressionOptions *hideTextOption;
@property (class, readonly, copy) NSUserInterfaceCompressionOptions *reduceMetricsOption;

@property (readonly, getter=isEmpty) BOOL empty;

- (BOOL)containsOptions:(NSUserInterfaceCompressionOptions *)options;
- (BOOL)intersectsOptions:(NSUserInterfaceCompressionOptions *)options;
- (NSUserInterfaceCompressionOptions *)optionsByAddingOptions:(NSUserInterfaceCompressionOptions *)options;
- (NSUserInterfaceCompressionOptions *)optionsByRemovingOptions:(NSUserInterfaceCompressionOptions *)options;

@end

NS_ASSUME_NONNULL_END
