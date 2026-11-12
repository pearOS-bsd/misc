/*
 * NSRuleEditor.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSRuleEditor, the rule-row editor control (base for NSPredicateEditor).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSRuleEditor_interface.txt.
 *
 * NSRuleEditor is an NSControl (measured). This core reproduces the
 * configuration surface (nestingMode=Compound, rowHeight=32, editable=YES,
 * canRemoveAllRows=YES, the three key paths, rowClass=NSMutableDictionary — all
 * measured) and the row model (addRow:/insertRowAtIndex:withType:asSubrowOfRow:
 * animate:/removeRowAtIndex:/numberOfRows/rowTypeForRow:). The criteria/display-
 * value population from the delegate data source and the row subviews are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSControl.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSRuleEditorNestingMode) {
    NSRuleEditorNestingModeSingle = 0,
    NSRuleEditorNestingModeList = 1,
    NSRuleEditorNestingModeCompound = 2,
    NSRuleEditorNestingModeSimple = 3,
};

typedef NS_ENUM(NSUInteger, NSRuleEditorRowType) {
    NSRuleEditorRowTypeSimple = 0,
    NSRuleEditorRowTypeCompound = 1,
};

@interface NSRuleEditor : NSControl

@property (nullable, weak) id delegate;
@property (nullable, copy) NSString *formattingStringsFilename;
@property (nullable, copy) NSDictionary *formattingDictionary;
@property NSRuleEditorNestingMode nestingMode;
@property CGFloat rowHeight;
@property (getter=isEditable) BOOL editable;
@property BOOL canRemoveAllRows;
@property (readonly) NSInteger numberOfRows;
@property (readonly, copy) NSIndexSet *selectedRowIndexes;
@property Class rowClass;
@property (copy) NSString *rowTypeKeyPath;
@property (copy) NSString *criteriaKeyPath;
@property (copy) NSString *displayValuesKeyPath;

- (void)addRow:(nullable id)sender;
- (void)insertRowAtIndex:(NSInteger)rowIndex
                withType:(NSRuleEditorRowType)rowType
            asSubrowOfRow:(NSInteger)parentRow
                  animate:(BOOL)shouldAnimate;
- (void)removeRowAtIndex:(NSInteger)rowIndex;
- (NSRuleEditorRowType)rowTypeForRow:(NSInteger)rowIndex;
- (NSInteger)parentRowForRow:(NSInteger)rowIndex;
- (void)reloadCriteria;

@end

NS_ASSUME_NONNULL_END
