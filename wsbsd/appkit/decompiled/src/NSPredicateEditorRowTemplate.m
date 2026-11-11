/*
 * NSPredicateEditorRowTemplate.m — behavioral-1:1 core.
 * See NSPredicateEditorRowTemplate.h (templateViews + exact match weighting
 * are stage2; the 0-vs-positive match contract and predicate building are here).
 */

#import "NSPredicateEditorRowTemplate.h"

typedef NS_ENUM(NSInteger, NSPredicateEditorRowTemplateType) {
    kRowComparison = 0,
    kRowCompound   = 1,
};

@implementation NSPredicateEditorRowTemplate {
    NSPredicateEditorRowTemplateType _type;
    NSArray<NSExpression *> *_leftExpressions;
    NSArray<NSExpression *> *_rightExpressions;
    NSAttributeType _rightAttributeType;
    NSComparisonPredicateModifier _modifier;
    NSArray<NSNumber *> *_operators;
    NSUInteger _options;
    NSArray<NSNumber *> *_compoundTypes;
}

- (instancetype)initWithLeftExpressions:(NSArray<NSExpression *> *)leftExpressions
                        rightExpressions:(NSArray<NSExpression *> *)rightExpressions
                                modifier:(NSComparisonPredicateModifier)modifier
                               operators:(NSArray<NSNumber *> *)operators
                                 options:(NSUInteger)options
{
    self = [super init];
    if (self) {
        _type = kRowComparison;
        _leftExpressions = [leftExpressions copy] ?: @[];
        _rightExpressions = [rightExpressions copy] ?: @[];
        _modifier = modifier;
        _operators = [operators copy] ?: @[];
        _options = options;
    }
    return self;
}

- (instancetype)initWithLeftExpressions:(NSArray<NSExpression *> *)leftExpressions
           rightExpressionAttributeType:(NSAttributeType)attributeType
                                modifier:(NSComparisonPredicateModifier)modifier
                               operators:(NSArray<NSNumber *> *)operators
                                 options:(NSUInteger)options
{
    self = [self initWithLeftExpressions:leftExpressions rightExpressions:@[] modifier:modifier operators:operators options:options];
    if (self) _rightAttributeType = attributeType;
    return self;
}

- (instancetype)initWithCompoundTypes:(NSArray<NSNumber *> *)compoundTypes
{
    self = [super init];
    if (self) {
        _type = kRowCompound;
        _compoundTypes = [compoundTypes copy] ?: @[];
    }
    return self;
}

- (instancetype)init { return [self initWithCompoundTypes:@[@(NSAndPredicateType), @(NSOrPredicateType), @(NSNotPredicateType)]]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; /* stage2 */ }
- (void)encodeWithCoder:(NSCoder *)coder { /* TODO(stage2) */ }

- (NSArray *)leftExpressions { return _leftExpressions; }
- (NSArray *)rightExpressions { return _rightExpressions; }
- (NSAttributeType)rightExpressionAttributeType { return _rightAttributeType; }
- (NSComparisonPredicateModifier)modifier { return _modifier; }
- (NSArray<NSNumber *> *)operators { return _operators; }
- (NSUInteger)options { return _options; }
- (NSArray<NSNumber *> *)compoundTypes { return _compoundTypes; }
- (NSArray<NSView *> *)templateViews { return @[]; /* stage2: build the row views */ }

/* --- predicate matching --- */

- (double)matchForPredicate:(NSPredicate *)predicate
{
    if (_type == kRowCompound) {
        if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
            NSCompoundPredicateType t = [(NSCompoundPredicate *)predicate compoundPredicateType];
            for (NSNumber *n in _compoundTypes)
                if ((NSCompoundPredicateType)n.unsignedIntegerValue == t) return 0.5; /* measured */
        }
        return 0.0;
    }

    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *cp = (NSComparisonPredicate *)predicate;
        BOOL leftOK = NO;
        for (NSExpression *e in _leftExpressions)
            if ([e isEqual:cp.leftExpression]) { leftOK = YES; break; }
        if (!leftOK) return 0.0;   /* measured: unknown left expression -> 0 */

        BOOL opOK = NO;
        for (NSNumber *n in _operators)
            if ((NSPredicateOperatorType)n.unsignedIntegerValue == cp.predicateOperatorType) { opOK = YES; break; }
        BOOL modOK = (cp.comparisonPredicateModifier == _modifier);

        /* Positive score when the left expression matches; operator/modifier
         * agreement raises it. (Exact AppKit weighting is stage2.) */
        return 0.5 + (opOK ? 0.25 : 0.0) + (modOK ? 0.25 : 0.0);
    }
    return 0.0;
}

/* --- predicate building --- */

- (NSPredicate *)predicateWithSubpredicates:(NSArray<NSPredicate *> *)subpredicates
{
    if (_type == kRowCompound) {
        NSCompoundPredicateType t = _compoundTypes.count ? (NSCompoundPredicateType)[_compoundTypes[0] unsignedIntegerValue] : NSAndPredicateType;
        return [[NSCompoundPredicate alloc] initWithType:t subpredicates:(subpredicates ?: @[])];
    }
    /* comparison template: build from the first available selections. */
    NSExpression *lhs = _leftExpressions.firstObject ?: [NSExpression expressionForConstantValue:@""];
    NSExpression *rhs = _rightExpressions.firstObject ?: [NSExpression expressionForConstantValue:@""];
    NSPredicateOperatorType op = _operators.count ? (NSPredicateOperatorType)[_operators[0] unsignedIntegerValue] : NSEqualToPredicateOperatorType;
    return [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs
                                                     modifier:_modifier type:op options:_options];
}

- (NSArray<NSPredicate *> *)displayableSubpredicatesOfPredicate:(NSPredicate *)predicate
{
    if (_type == kRowCompound && [predicate isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *cp = (NSCompoundPredicate *)predicate;
        for (NSNumber *n in _compoundTypes)
            if ((NSCompoundPredicateType)n.unsignedIntegerValue == cp.compoundPredicateType)
                return cp.subpredicates;
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSPredicateEditorRowTemplate *c;
    if (_type == kRowCompound) {
        c = [[[self class] alloc] initWithCompoundTypes:_compoundTypes];
    } else {
        c = [[[self class] alloc] initWithLeftExpressions:_leftExpressions rightExpressions:_rightExpressions
                                                 modifier:_modifier operators:_operators options:_options];
        c->_rightAttributeType = _rightAttributeType;
    }
    return c;
}

@end
