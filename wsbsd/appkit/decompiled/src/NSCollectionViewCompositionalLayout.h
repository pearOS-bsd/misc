/*
 * NSCollectionViewCompositionalLayout.h — 1:1 reimplementation (behavioral core)
 * of AppKit's NSCollectionViewCompositionalLayout, the top-level descriptive
 * collection-view layout built from NSCollectionLayoutSections.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionViewCompositionalLayout_interface.txt.
 *
 * NSCollectionViewCompositionalLayout is an NSCollectionViewLayout (measured).
 * This core reproduces the four initialisers (storing the fixed section or the
 * per-section provider block) and the auto-created configuration (non-nil —
 * measured). The attribute/frame solving is the layout engine's job (stage2).
 */

#import <Foundation/Foundation.h>
#import "NSCollectionViewLayout.h"
#import "NSCollectionLayoutSection.h"
#import "NSCollectionViewCompositionalLayoutConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@class NSCollectionLayoutEnvironment;
typedef NSCollectionLayoutSection * _Nullable (^NSCollectionViewCompositionalLayoutSectionProvider)(NSInteger section, id _Nullable environment);

@interface NSCollectionViewCompositionalLayout : NSCollectionViewLayout

- (instancetype)initWithSection:(NSCollectionLayoutSection *)section;
- (instancetype)initWithSection:(NSCollectionLayoutSection *)section
                  configuration:(NSCollectionViewCompositionalLayoutConfiguration *)configuration;
- (instancetype)initWithSectionProvider:(NSCollectionViewCompositionalLayoutSectionProvider)sectionProvider;
- (instancetype)initWithSectionProvider:(NSCollectionViewCompositionalLayoutSectionProvider)sectionProvider
                          configuration:(NSCollectionViewCompositionalLayoutConfiguration *)configuration;

@property (copy) NSCollectionViewCompositionalLayoutConfiguration *configuration;

@end

NS_ASSUME_NONNULL_END
