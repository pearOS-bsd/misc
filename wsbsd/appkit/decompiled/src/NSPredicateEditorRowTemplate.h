/*
 * NSPredicateEditorRowTemplate.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSPredicateEditorRowTemplate (the row template that NSPredicateEditor
 * uses to render and parse a predicate).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPredicateEditorRowTemplate_interface.txt. Real ivars:
 * _templateType, _predicateOptions, _predicateModifier, _leftAttributeType,
 * _rightAttributeType, _views, and _ptFlags (left/right wildcard bits).
 *
 * Measured on this Mac: the initializers store their expressions / attribute
 * type / modifier / operators / options; matchForPredicate: returns 0 when the
 * predicate's left expression is not in the template and a positive score when
 * the left expression and operator match (the exact weighting — e.g. 0.729 — is
 * an internal heuristic, reproduced here only as the 0-vs-positive contract);
 * a compound template matches a compound predicate whose type it carries (score
 * 0.5) and exposes its subpredicates; predicateWithSubpredicates: builds the
 * predicate. templateViews (the NSPopUpButton/NSTextField row) is TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSView;

/* NSAttributeType is a CoreData enum (NSUInteger-backed); mirror the subset we
 * need so the template does not pull in CoreData. NSStringAttributeType=700. */
#ifndef CoreData_NSAttributeType_defined
typedef NS_ENUM(NSUInteger, NSAttributeType) {
    NSUndefinedAttributeType     = 0,
    NSInteger16AttributeType     = 100,
    NSInteger32AttributeType     = 200,
    NSInteger64AttributeType     = 300,
    NSDecimalAttributeType       = 400,
    NSDoubleAttributeType        = 500,
    NSFloatAttributeType         = 600,
    NSStringAttributeType        = 700,
    NSBooleanAttributeType       = 800,
    NSDateAttributeType          = 900,
};
#endif

@interface NSPredicateEditorRowTemplate : NSObject <NSCoding, NSCopying>

- (instancetype)initWithLeftExpressions:(NSArray<NSExpression *> *)leftExpressions
                        rightExpressions:(NSArray<NSExpression *> *)rightExpressions
                                modifier:(NSComparisonPredicateModifier)modifier
                               operators:(NSArray<NSNumber *> *)operators
                                 options:(NSUInteger)options;

- (instancetype)initWithLeftExpressions:(NSArray<NSExpression *> *)leftExpressions
           rightExpressionAttributeType:(NSAttributeType)attributeType
                                modifier:(NSComparisonPredicateModifier)modifier
                               operators:(NSArray<NSNumber *> *)operators
                                 options:(NSUInteger)options;

- (instancetype)initWithCompoundTypes:(NSArray<NSNumber *> *)compoundTypes;

@property (readonly, copy) NSArray<NSView *> *templateViews;
@property (readonly, copy) NSArray<NSExpression *> *leftExpressions;
@property (readonly, copy) NSArray<NSExpression *> *rightExpressions;
@property (readonly) NSAttributeType rightExpressionAttributeType;
@property (readonly) NSComparisonPredicateModifier modifier;
@property (readonly, copy) NSArray<NSNumber *> *operators;
@property (readonly) NSUInteger options;
@property (readonly, copy) NSArray<NSNumber *> *compoundTypes;

- (double)matchForPredicate:(NSPredicate *)predicate;
- (NSPredicate *)predicateWithSubpredicates:(NSArray<NSPredicate *> *)subpredicates;
- (nullable NSArray<NSPredicate *> *)displayableSubpredicatesOfPredicate:(NSPredicate *)predicate;

@end

NS_ASSUME_NONNULL_END
