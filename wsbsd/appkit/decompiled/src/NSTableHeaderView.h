/*
 * NSTableHeaderView.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTableHeaderView, the clickable column-header bar of an NSTableView.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTableHeaderView_interface.txt.
 *
 * NSTableHeaderView is an NSView (measured). This core reproduces the stored
 * tableView link and the interaction read-outs (draggedColumn/resizedColumn -1,
 * draggedDistance 0 when idle — measured). columnAtPoint: / headerRectOfColumn:
 * need the table's column geometry, so they are TODO(stage2) and return
 * -1 / CGRectZero without a table.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTableView;

@interface NSTableHeaderView : NSView

@property (nullable, weak) NSTableView *tableView;
@property (readonly) NSInteger draggedColumn;
@property (readonly) CGFloat draggedDistance;
@property (readonly) NSInteger resizedColumn;

- (NSInteger)columnAtPoint:(CGPoint)point;
- (CGRect)headerRectOfColumn:(NSInteger)column;

@end

NS_ASSUME_NONNULL_END
