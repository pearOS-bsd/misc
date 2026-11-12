/*
 * NSBrowser.h — 1:1 reimplementation (behavioral core) of AppKit's NSBrowser,
 * the column (Miller) browser control.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSBrowser_interface.txt.
 *
 * NSBrowser is an NSControl (measured). This core reproduces the configuration
 * surface and the column cursor: the display flags (all defaults measured),
 * pathSeparator "/", takesTitleFromPreviousColumn, and the loaded-column model
 * (loadColumnZero / addColumn / setLastColumn: / lastColumn / selectedColumn /
 * numberOfVisibleColumns). The per-column matrix content comes from the delegate
 * data source and the drawing is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSControl.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSBrowser : NSControl

@property (nullable, weak) id delegate;

@property NSInteger maxVisibleColumns;
@property CGFloat minColumnWidth;
@property BOOL hasHorizontalScroller;
@property BOOL allowsMultipleSelection;
@property BOOL allowsEmptySelection;
@property BOOL allowsBranchSelection;
@property (getter=separatesColumns) BOOL separatesColumns;
@property (getter=isTitled) BOOL titled;
@property BOOL reusesColumns;
@property (copy) NSString *pathSeparator;
@property BOOL takesTitleFromPreviousColumn;

@property (readonly) NSInteger lastColumn;
@property (readonly) NSInteger selectedColumn;
@property (readonly) NSInteger numberOfVisibleColumns;

- (void)loadColumnZero;
- (void)addColumn;
- (void)setLastColumn:(NSInteger)column;
- (void)selectRow:(NSInteger)row inColumn:(NSInteger)column;
- (void)reloadColumn:(NSInteger)column;

@end

NS_ASSUME_NONNULL_END
