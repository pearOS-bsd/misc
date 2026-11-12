/*
 * NSCollectionViewCompositionalLayout.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionViewCompositionalLayout.h"

@implementation NSCollectionViewCompositionalLayout {
    NSCollectionLayoutSection *_fixedSection;
    NSCollectionViewCompositionalLayoutSectionProvider _sectionProvider;
    NSCollectionViewCompositionalLayoutConfiguration *_configuration;
}

- (instancetype)initWithSection:(NSCollectionLayoutSection *)section
{
    return [self initWithSection:section
                   configuration:[[NSCollectionViewCompositionalLayoutConfiguration alloc] init]];
}

- (instancetype)initWithSection:(NSCollectionLayoutSection *)section
                  configuration:(NSCollectionViewCompositionalLayoutConfiguration *)configuration
{
    self = [super init];
    if (self) {
        _fixedSection = section;
        _configuration = [configuration copy] ?: [[NSCollectionViewCompositionalLayoutConfiguration alloc] init];
    }
    return self;
}

- (instancetype)initWithSectionProvider:(NSCollectionViewCompositionalLayoutSectionProvider)sectionProvider
{
    return [self initWithSectionProvider:sectionProvider
                           configuration:[[NSCollectionViewCompositionalLayoutConfiguration alloc] init]];
}

- (instancetype)initWithSectionProvider:(NSCollectionViewCompositionalLayoutSectionProvider)sectionProvider
                          configuration:(NSCollectionViewCompositionalLayoutConfiguration *)configuration
{
    self = [super init];
    if (self) {
        _sectionProvider = [sectionProvider copy];
        _configuration = [configuration copy] ?: [[NSCollectionViewCompositionalLayoutConfiguration alloc] init];
    }
    return self;
}

- (NSCollectionViewCompositionalLayoutConfiguration *)configuration { return _configuration; }
- (void)setConfiguration:(NSCollectionViewCompositionalLayoutConfiguration *)c
{
    _configuration = [c copy] ?: [[NSCollectionViewCompositionalLayoutConfiguration alloc] init];
}

/* resolves the section for an index (fixed section, or the provider block). */
- (NSCollectionLayoutSection *)_sectionForIndex:(NSInteger)index environment:(id)environment
{
    if (_fixedSection) return _fixedSection;
    if (_sectionProvider) return _sectionProvider(index, environment);
    return nil;
}

@end
