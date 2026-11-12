/*
 * NSTableRowView.m — behavioral-1:1 core. See the header.
 */

#import "NSTableRowView.h"

@implementation NSTableRowView {
    BOOL _selected;
    NSTableViewSelectionHighlightStyle _selectionHighlightStyle;
    BOOL _emphasized;
    BOOL _floating;
    BOOL _groupRowStyle;
    BOOL _targetForDropOperation;
    NSInteger _draggingDestinationFeedbackStyle;
    NSColor *_backgroundColor;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;  /* measured (0) */
        /* selected/emphasized/floating/groupRowStyle/targetForDrop NO,
           draggingDestinationFeedbackStyle 0 (measured). */
    }
    return self;
}

- (BOOL)isSelected { return _selected; }
- (void)setSelected:(BOOL)v { _selected = v; }
- (NSTableViewSelectionHighlightStyle)selectionHighlightStyle { return _selectionHighlightStyle; }
- (void)setSelectionHighlightStyle:(NSTableViewSelectionHighlightStyle)s { _selectionHighlightStyle = s; }
- (BOOL)isEmphasized { return _emphasized; }
- (void)setEmphasized:(BOOL)v { _emphasized = v; }
- (BOOL)isFloating { return _floating; }
- (void)setFloating:(BOOL)v { _floating = v; }
- (BOOL)isGroupRowStyle { return _groupRowStyle; }
- (void)setGroupRowStyle:(BOOL)v { _groupRowStyle = v; }
- (NSInteger)numberOfColumns { return 0; }   /* populated by the table (stage2) */
- (BOOL)targetForDropOperation { return _targetForDropOperation; }
- (void)setTargetForDropOperation:(BOOL)v { _targetForDropOperation = v; }
- (NSInteger)draggingDestinationFeedbackStyle { return _draggingDestinationFeedbackStyle; }
- (void)setDraggingDestinationFeedbackStyle:(NSInteger)v { _draggingDestinationFeedbackStyle = v; }
- (NSColor *)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(NSColor *)c { _backgroundColor = c; }

- (NSBackgroundStyle)interiorBackgroundStyle
{
    /* a selected, emphasized row draws its cell contents emphasized. */
    return (_selected && _emphasized) ? NSBackgroundStyleEmphasized : NSBackgroundStyleNormal;
}

@end
