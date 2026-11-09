/*
 * NSTextAlternatives.m — 1:1 (core). See NSTextAlternatives.h for the evidence.
 *
 * A value object: the primary string, the immutable list of alternatives and
 * the low-confidence flag. Posting NSTextAlternativesSelectedNotification when
 * the user chooses an alternative is stage2.
 */
#import "NSTextAlternatives.h"

@implementation NSTextAlternatives {
    NSString *_primaryString;
    NSArray<NSString *> *_alternativeStrings;
    BOOL _isLowConfidence;
}

- (instancetype)initWithPrimaryString:(NSString *)primaryString
                   alternativeStrings:(NSArray<NSString *> *)alternativeStrings
{
    self = [super init];
    if (self) {
        _primaryString = [primaryString copy] ?: @"";
        _alternativeStrings = [alternativeStrings copy] ?: @[];
    }
    return self;
}

- (NSString *)primaryString { return _primaryString; }
- (NSArray<NSString *> *)alternativeStrings { return _alternativeStrings; }
- (BOOL)isLowConfidence { return _isLowConfidence; }
- (void)setLowConfidence:(BOOL)v { _isLowConfidence = v; }

@end
