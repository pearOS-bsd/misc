/*
 * NSUserInterfaceCompressionOptions.m — 1:1 (core). See the header for evidence.
 *
 * Backed by an immutable identifier set (_identifiers). containsOptions: is a
 * superset test, intersectsOptions: a non-empty-intersection test,
 * optionsByAddingOptions:/optionsByRemovingOptions: are set union/minus. The
 * four standard options are single-identifier singletons; standardOptions is
 * their union.
 */
#import "NSUserInterfaceCompressionOptions.h"

static NSString * const kBreakEqualWidths = @"NSUserInterfaceCompressionOptionsBreakEqualWidthsIdentifier";
static NSString * const kHideImages       = @"NSUserInterfaceCompressionOptionsHideImagesIdentifier";
static NSString * const kHideText         = @"NSUserInterfaceCompressionOptionsHideTextIdentifier";
static NSString * const kReduceMetrics    = @"NSUserInterfaceCompressionOptionsReduceMetricsIdentifier";

@implementation NSUserInterfaceCompressionOptions {
    NSSet<NSString *> *_identifiers;
}

- (instancetype)_initWithSet:(NSSet *)set
{
    self = [super init];
    if (self) { _identifiers = [set copy] ?: [NSSet set]; }
    return self;
}

- (instancetype)init { return [self _initWithSet:[NSSet set]]; }
- (instancetype)initWithIdentifier:(NSString *)identifier
{
    return [self _initWithSet:(identifier ? [NSSet setWithObject:identifier] : [NSSet set])];
}
- (instancetype)initWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [self _initWithSet:(identifiers ? [NSSet setWithArray:identifiers] : [NSSet set])];
}

+ (NSUserInterfaceCompressionOptions *)breakEqualWidthsOption { return [[self alloc] initWithIdentifier:kBreakEqualWidths]; }
+ (NSUserInterfaceCompressionOptions *)hideImagesOption { return [[self alloc] initWithIdentifier:kHideImages]; }
+ (NSUserInterfaceCompressionOptions *)hideTextOption { return [[self alloc] initWithIdentifier:kHideText]; }
+ (NSUserInterfaceCompressionOptions *)reduceMetricsOption { return [[self alloc] initWithIdentifier:kReduceMetrics]; }
+ (NSUserInterfaceCompressionOptions *)standardOptions
{
    return [[self alloc] initWithIdentifiers:@[kBreakEqualWidths, kHideImages, kHideText, kReduceMetrics]];
}

- (BOOL)isEmpty { return _identifiers.count == 0; }

- (BOOL)containsOptions:(NSUserInterfaceCompressionOptions *)options
{
    return [options->_identifiers isSubsetOfSet:_identifiers];
}
- (BOOL)intersectsOptions:(NSUserInterfaceCompressionOptions *)options
{
    return [_identifiers intersectsSet:options->_identifiers];
}
- (NSUserInterfaceCompressionOptions *)optionsByAddingOptions:(NSUserInterfaceCompressionOptions *)options
{
    NSMutableSet *s = [_identifiers mutableCopy];
    [s unionSet:options->_identifiers];
    return [[NSUserInterfaceCompressionOptions alloc] _initWithSet:s];
}
- (NSUserInterfaceCompressionOptions *)optionsByRemovingOptions:(NSUserInterfaceCompressionOptions *)options
{
    NSMutableSet *s = [_identifiers mutableCopy];
    [s minusSet:options->_identifiers];
    return [[NSUserInterfaceCompressionOptions alloc] _initWithSet:s];
}

- (id)copyWithZone:(NSZone *)zone { return [[NSUserInterfaceCompressionOptions alloc] _initWithSet:_identifiers]; }
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSUserInterfaceCompressionOptions class]]) return NO;
    return [_identifiers isEqualToSet:((NSUserInterfaceCompressionOptions *)object)->_identifiers];
}
- (NSUInteger)hash { return _identifiers.hash; }

@end
