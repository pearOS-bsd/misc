/*
 * NSPredicateEditor.m — behavioral-1:1 core. See the header.
 */

#import "NSPredicateEditor.h"

@implementation NSPredicateEditor {
    NSArray<NSPredicateEditorRowTemplate *> *_rowTemplates;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        /* default: one compound row template with types [And(1), Or(2), Not(0)]
           (measured). */
        NSPredicateEditorRowTemplate *compound =
            [[NSPredicateEditorRowTemplate alloc] initWithCompoundTypes:@[@1, @2, @0]];
        _rowTemplates = @[compound];
    }
    return self;
}

- (NSArray<NSPredicateEditorRowTemplate *> *)rowTemplates { return _rowTemplates; }
- (void)setRowTemplates:(NSArray<NSPredicateEditorRowTemplate *> *)t { _rowTemplates = [t copy] ?: @[]; }

@end
