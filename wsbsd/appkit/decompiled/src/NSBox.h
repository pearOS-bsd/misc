/*
 * NSBox.h — 1:1 reimplementation of AppKit's NSBox (core).
 *
 * NSView container. Evidence ../evidence/box: a packed _bFlags word at ivar
 * 0x91c holds borderType (bits 0-1), titlePosition (bits 2-4), isTransparent
 * (bit 9) and boxType (bits 10-12). The title comes from a _titleCell at 0x918
 * and borderWidth/cornerRadius from auxiliary storage (both kept plainly here;
 * TODO(stage2): the title cell and aux storage, plus drawing).
 */
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSBoxType) {
    NSBoxPrimary   = 0,
    NSBoxSecondary = 1,   /* deprecated */
    NSBoxSeparator = 2,
    NSBoxOldStyle  = 3,   /* deprecated */
    NSBoxCustom    = 4,
};

typedef NS_ENUM(NSUInteger, NSTitlePosition) {
    NSNoTitle     = 0,
    NSAboveTop    = 1,
    NSAtTop       = 2,
    NSBelowTop    = 3,
    NSAboveBottom = 4,
    NSAtBottom    = 5,
    NSBelowBottom = 6,
};

typedef NS_ENUM(NSUInteger, NSBorderType) {
    NSNoBorder     = 0,
    NSLineBorder   = 1,
    NSBezelBorder  = 2,
    NSGrooveBorder = 3,
};

@interface NSBox : NSView

@property NSBoxType boxType;
@property NSBorderType borderType;
@property NSTitlePosition titlePosition;
@property (copy) NSString *title;
@property CGFloat borderWidth;
@property CGFloat cornerRadius;
@property (getter=isTransparent) BOOL transparent;

@end

NS_ASSUME_NONNULL_END
