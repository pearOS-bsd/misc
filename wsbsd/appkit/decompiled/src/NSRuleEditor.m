/*
 * NSRuleEditor.m — behavioral-1:1 core. See the header.
 */

#import "NSRuleEditor.h"

@interface _NSRuleEditorRow : NSObject
@property NSRuleEditorRowType type;
@property NSInteger parentRow;   /* -1 for a top-level row */
@end
@implementation _NSRuleEditorRow
@end

@implementation NSRuleEditor {
    __weak id _delegate;
    NSString *_formattingStringsFilename;
    NSDictionary *_formattingDictionary;
    NSRuleEditorNestingMode _nestingMode;
    CGFloat _rowHeight;
    BOOL _editable;
    BOOL _canRemoveAllRows;
    Class _rowClass;
    NSString *_rowTypeKeyPath, *_criteriaKeyPath, *_displayValuesKeyPath;
    NSMutableArray<_NSRuleEditorRow *> *_rows;
    NSIndexSet *_selectedRowIndexes;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _nestingMode = NSRuleEditorNestingModeCompound;   /* measured */
        _rowHeight = 32.0;                                /* measured */
        _editable = YES;                                  /* measured */
        _canRemoveAllRows = YES;                          /* measured */
        _rowClass = [NSMutableDictionary class];          /* measured */
        _rowTypeKeyPath = @"rowType";                     /* measured */
        _criteriaKeyPath = @"criteria";                   /* measured */
        _displayValuesKeyPath = @"displayValues";         /* measured */
        _rows = [NSMutableArray array];
        _selectedRowIndexes = [NSIndexSet indexSet];
    }
    return self;
}

- (id)delegate { return _delegate; }
- (void)setDelegate:(id)d { _delegate = d; }
- (NSString *)formattingStringsFilename { return _formattingStringsFilename; }
- (void)setFormattingStringsFilename:(NSString *)s { _formattingStringsFilename = [s copy]; }
- (NSDictionary *)formattingDictionary { return _formattingDictionary; }
- (void)setFormattingDictionary:(NSDictionary *)d { _formattingDictionary = [d copy]; }
- (NSRuleEditorNestingMode)nestingMode { return _nestingMode; }
- (void)setNestingMode:(NSRuleEditorNestingMode)m { _nestingMode = m; }
- (CGFloat)rowHeight { return _rowHeight; }
- (void)setRowHeight:(CGFloat)h { _rowHeight = h; }
- (BOOL)isEditable { return _editable; }
- (void)setEditable:(BOOL)v { _editable = v; }
- (BOOL)canRemoveAllRows { return _canRemoveAllRows; }
- (void)setCanRemoveAllRows:(BOOL)v { _canRemoveAllRows = v; }
- (NSInteger)numberOfRows { return (NSInteger)_rows.count; }
- (NSIndexSet *)selectedRowIndexes { return _selectedRowIndexes; }
- (Class)rowClass { return _rowClass; }
- (void)setRowClass:(Class)c { _rowClass = c; }
- (NSString *)rowTypeKeyPath { return _rowTypeKeyPath; }
- (void)setRowTypeKeyPath:(NSString *)s { _rowTypeKeyPath = [s copy]; }
- (NSString *)criteriaKeyPath { return _criteriaKeyPath; }
- (void)setCriteriaKeyPath:(NSString *)s { _criteriaKeyPath = [s copy]; }
- (NSString *)displayValuesKeyPath { return _displayValuesKeyPath; }
- (void)setDisplayValuesKeyPath:(NSString *)s { _displayValuesKeyPath = [s copy]; }

- (void)addRow:(id)sender
{
    [self insertRowAtIndex:(NSInteger)_rows.count withType:NSRuleEditorRowTypeSimple asSubrowOfRow:-1 animate:NO];
}

- (void)insertRowAtIndex:(NSInteger)rowIndex
                withType:(NSRuleEditorRowType)rowType
            asSubrowOfRow:(NSInteger)parentRow
                  animate:(BOOL)shouldAnimate
{
    if (rowIndex < 0) rowIndex = 0;
    if (rowIndex > (NSInteger)_rows.count) rowIndex = (NSInteger)_rows.count;
    _NSRuleEditorRow *row = [_NSRuleEditorRow new];
    row.type = rowType;
    row.parentRow = parentRow;
    [_rows insertObject:row atIndex:(NSUInteger)rowIndex];
    /* TODO(stage2): populate the row's criteria/display-value subviews from the delegate. */
}

- (void)removeRowAtIndex:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)_rows.count) return;
    [_rows removeObjectAtIndex:(NSUInteger)rowIndex];
}

- (NSRuleEditorRowType)rowTypeForRow:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)_rows.count) return NSRuleEditorRowTypeSimple;
    return _rows[(NSUInteger)rowIndex].type;
}

- (NSInteger)parentRowForRow:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)_rows.count) return -1;
    return _rows[(NSUInteger)rowIndex].parentRow;
}

- (void)reloadCriteria { /* TODO(stage2): re-query the delegate for the criteria tree. */ }

@end
