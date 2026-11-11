/* test_nspredicateeditorrowtemplate.m — behaviour checks for the row template core */
#import "../src/NSPredicateEditorRowTemplate.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSExpression *lhs = [NSExpression expressionForKeyPath:@"name"];
        NSPredicateEditorRowTemplate *t =
            [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[lhs]
                                            rightExpressionAttributeType:NSStringAttributeType
                                                                modifier:NSDirectPredicateModifier
                                                               operators:@[@(NSEqualToPredicateOperatorType), @(NSContainsPredicateOperatorType)]
                                                                 options:NSCaseInsensitivePredicateOption];
        /* stored config */
        CHECK(t.modifier == NSDirectPredicateModifier, "modifier stored");
        CHECK(t.options == NSCaseInsensitivePredicateOption, "options stored");
        CHECK(t.rightExpressionAttributeType == NSStringAttributeType, "rightExpressionAttributeType stored (700)");
        CHECK(t.operators.count == 2 && t.leftExpressions.count == 1, "operators/left stored");
        CHECK(t.rightExpressions.count == 0, "rightExpressions empty for type-based init");
        CHECK(t.templateViews.count == 0, "templateViews stage2 empty");

        /* match: known left + known operator -> positive; unknown left -> 0 */
        NSPredicate *match = [NSPredicate predicateWithFormat:@"name == 'Ada'"];
        CHECK([t matchForPredicate:match] > 0.0, "matching predicate scores positive");
        NSPredicate *nomatch = [NSPredicate predicateWithFormat:@"age == 5"];
        CHECK([t matchForPredicate:nomatch] == 0.0, "unknown left expression scores 0");
        /* operator match raises the score above left-only */
        NSPredicate *wrongOp = [NSPredicate predicateWithFormat:@"name BEGINSWITH 'A'"];
        CHECK([t matchForPredicate:match] > [t matchForPredicate:wrongOp], "operator agreement raises score");

        /* comparison template builds a comparison predicate */
        NSExpression *r = [NSExpression expressionForConstantValue:@"x"];
        NSPredicateEditorRowTemplate *t2 =
            [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[lhs] rightExpressions:@[r]
                                                                modifier:NSDirectPredicateModifier
                                                               operators:@[@(NSEqualToPredicateOperatorType)]
                                                                 options:0];
        NSPredicate *built = [t2 predicateWithSubpredicates:@[]];
        CHECK([built isKindOfClass:[NSComparisonPredicate class]], "comparison template builds a comparison predicate");

        /* compound template */
        NSPredicateEditorRowTemplate *ct =
            [[NSPredicateEditorRowTemplate alloc] initWithCompoundTypes:@[@(NSAndPredicateType), @(NSOrPredicateType)]];
        CHECK(ct.compoundTypes.count == 2, "compoundTypes stored");
        NSPredicate *sub = [NSPredicate predicateWithFormat:@"name == 'A'"];
        NSCompoundPredicate *andp = (NSCompoundPredicate *)[NSCompoundPredicate andPredicateWithSubpredicates:@[sub, sub]];
        CHECK([ct matchForPredicate:andp] == 0.5, "compound match scores 0.5 (measured)");
        NSArray *disp = [ct displayableSubpredicatesOfPredicate:andp];
        CHECK(disp.count == 2, "displayableSubpredicates returns the subpredicates");
        CHECK([ct matchForPredicate:match] == 0.0, "compound template does not match a comparison predicate");
        CHECK([ct displayableSubpredicatesOfPredicate:match] == nil, "non-matching -> nil subpredicates");

        /* predicateWithSubpredicates builds a compound predicate of the first type */
        NSPredicate *compound = [ct predicateWithSubpredicates:@[sub, sub]];
        CHECK([compound isKindOfClass:[NSCompoundPredicate class]]
              && [(NSCompoundPredicate *)compound compoundPredicateType] == NSAndPredicateType,
              "compound template builds AND of subpredicates");

        /* copy preserves type + config */
        NSPredicateEditorRowTemplate *cp = [t copy];
        CHECK(cp.operators.count == 2 && cp.rightExpressionAttributeType == NSStringAttributeType, "copy preserves config");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
