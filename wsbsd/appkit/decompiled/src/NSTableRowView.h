/*
 * NSTableRowView.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTableRowView, the per-row background/selection view in an NSTableView.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTableRowView_interface.txt.
 *
 * NSTableRowView is an NSView (measured). This core reproduces the row state:
 * selected, selectionHighlightStyle (Regular), emphasized, floating,
 * groupRowStyle, targetForDropOperation, draggingDestinationFeedbackStyle,
 * backgroundColor, and the derived interiorBackgroundStyle (Emphasized while
 * selected+emphasized, else Normal). Cell-view layout and selection drawing are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSTableViewSelectionHighlightStyle) {
    NSTableViewSelectionHighlightStyleNone = -1,
    NSTableViewSelectionHighlightStyleRegular = 0,
    NSTableViewSelectionHighlightStyleSourceList = 1,
};

typedef NS_ENUM(NSInteger, NSBackgroundStyle) {
    NSBackgroundStyleNormal = 0,
    NSBackgroundStyleEmphasized = 1,
    NSBackgroundStyleRaised = 2,
    NSBackgroundStyleLowered = 3,
};

@class NSColor;

@interface NSTableRowView : NSView

@property (getter=isSelected) BOOL selected;
@property NSTableViewSelectionHighlightStyle selectionHighlightStyle;
@property (getter=isEmphasized) BOOL emphasized;
@property (getter=isFloating) BOOL floating;
@property (getter=isGroupRowStyle) BOOL groupRowStyle;
@property (readonly) NSInteger numberOfColumns;
@property BOOL targetForDropOperation;
@property NSInteger draggingDestinationFeedbackStyle;
@property (nullable, strong) NSColor *backgroundColor;
@property (readonly) NSBackgroundStyle interiorBackgroundStyle;

@end

NS_ASSUME_NONNULL_END
