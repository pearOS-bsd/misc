/*
 * NSText.h — 1:1 reimplementation (behavioral core) of AppKit's NSText, the
 * abstract text-editing view and superclass of NSTextView.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSText_interface.txt.
 *
 * NSText is an NSView (measured). This core reproduces the text + configuration
 * model: string (with setString: / replaceCharactersInRange:withString:),
 * selectedRange (clamped to the string), the editable/selectable/richText/
 * fieldEditor/usesFontPanel/drawsBackground flags, the resizable flags,
 * alignment (Natural default), backgroundColor/textColor/font and the delegate —
 * all defaults measured. Glyph layout, drawing and the editing UI are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef NSTextAlignment_ENUM_DEFINED
#define NSTextAlignment_ENUM_DEFINED
typedef NS_ENUM(NSInteger, NSTextAlignment) {
    NSTextAlignmentLeft = 0,
    NSTextAlignmentCenter = 1,
    NSTextAlignmentRight = 2,
    NSTextAlignmentJustified = 3,
    NSTextAlignmentNatural = 4,
};
#endif

@class NSColor, NSFont;

@interface NSText : NSView

@property (copy) NSString *string;
@property NSRange selectedRange;

@property (getter=isEditable) BOOL editable;
@property (getter=isSelectable) BOOL selectable;
@property (getter=isRichText) BOOL richText;
@property (getter=isFieldEditor) BOOL fieldEditor;
@property BOOL usesFontPanel;
@property BOOL drawsBackground;
@property (getter=isHorizontallyResizable) BOOL horizontallyResizable;
@property (getter=isVerticallyResizable) BOOL verticallyResizable;
@property NSTextAlignment alignment;
@property (nullable, strong) NSColor *backgroundColor;
@property (nullable, strong) NSColor *textColor;
@property (nullable, strong) NSFont *font;
@property (nullable, weak) id delegate;

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)aString;
- (void)scrollRangeToVisible:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
