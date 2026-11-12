/*
 * NSTableHeaderCell.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTableHeaderCell, the NSTextFieldCell that draws a table column header.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTableHeaderCell_interface.txt.
 *
 * NSTableHeaderCell is an NSTextFieldCell (measured). Beyond the inherited text
 * cell it adds the sort-indicator geometry: sortIndicatorRectForBounds: returns
 * a 9x9 rect at the trailing edge (8pt inset), vertically centered — reproduced
 * from the measured {0,0,80,20} -> {{63,6},{9,9}}. The actual indicator drawing
 * (drawSortIndicatorWithFrame:inView:ascending:priority:) is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTableHeaderCell : NSTextFieldCell

- (instancetype)initTextCell:(NSString *)string;

- (CGRect)sortIndicatorRectForBounds:(CGRect)rect;
- (void)drawSortIndicatorWithFrame:(CGRect)cellFrame
                            inView:(nullable id)controlView
                         ascending:(BOOL)ascending
                          priority:(NSInteger)priority;

@end

NS_ASSUME_NONNULL_END
