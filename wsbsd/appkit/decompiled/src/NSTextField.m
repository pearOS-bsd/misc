/*
 * NSTextField.m — 1:1 reimplementation of AppKit's NSTextField (core).
 * Evidence ../evidence/textfield. Each accessor loads NSControl._cell and
 * tail-calls the cell (e.g. isEditable 0x184f3d8a4, isBezeled 0x184f2d8f4).
 */
#import "NSTextField.h"

@implementation NSTextField

+ (Class)cellClass { return [NSTextFieldCell class]; }

- (NSTextFieldCell *)textCell { return (NSTextFieldCell *)self.cell; }

- (NSString *)stringValue { return [self.textCell stringValue]; }
- (void)setStringValue:(NSString *)stringValue { [self.textCell setStringValue:stringValue]; }

/* -[NSTextField isEditable] 0x184f3d8a4 / setEditable: 0x184f2ee90 -> cell
 * (the setter also prepares the field editor via 0x18804d9f0 — stage2). */
- (BOOL)isEditable { return [self.textCell isEditable]; }
- (void)setEditable:(BOOL)editable { [self.textCell setEditable:editable]; }

- (BOOL)isSelectable { return [self.textCell isSelectable]; }
- (void)setSelectable:(BOOL)selectable { [self.textCell setSelectable:selectable]; }

/* -[NSTextField isBezeled] 0x184f2d8f4 -> cell */
- (BOOL)isBezeled { return [self.textCell isBezeled]; }
- (void)setBezeled:(BOOL)bezeled { [self.textCell setBezeled:bezeled]; }

- (BOOL)isBordered { return [self.textCell isBordered]; }
- (void)setBordered:(BOOL)bordered { [self.textCell setBordered:bordered]; }

/* +[NSTextField labelWithString:] — a non-editable, non-selectable, borderless,
 * non-bezeled text field showing the string. (Font/colour defaults are stage2.) */
+ (instancetype)labelWithString:(NSString *)stringValue
{
    NSTextField *label = [[self alloc] initWithFrame:CGRectZero];
    label.editable = NO;
    label.selectable = NO;
    label.bezeled = NO;
    label.bordered = NO;
    label.stringValue = stringValue;
    return label;
}

@end
