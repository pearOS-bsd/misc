/*
 * NSTableViewRowAction.h — 1:1 reimplementation (core). NSObject <NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTableViewRowAction : NSObject <NSCopying> {
 *       q _style;  @"NSString" _title;  @? _handler;  @"NSColor" _backgroundColor;
 *       @"NSImage" _image;  @"NSMenu" _menu;  B _allowsFullSwipe;
 *   }
 *   +rowActionWithStyle:title:handler: +rowActionWithStyle:title:allowsFullSwipe:handler:
 *   -style -title -handler -backgroundColor -image -allowsFullSwipe
 *
 * A swipe action on a table row. The core stores style, title, the handler
 * block, background colour, image and the allowsFullSwipe flag. The swipe UI and
 * the style-derived default colour (red for Destructive) are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSTableViewRowActionStyle) {
    NSTableViewRowActionStyleRegular = 0,
    NSTableViewRowActionStyleDestructive = 1,
};

@class NSTableViewRowAction;
typedef void (^NSTableViewRowActionHandler)(NSTableViewRowAction *action, NSInteger row);

@interface NSTableViewRowAction : NSObject <NSCopying>

+ (instancetype)rowActionWithStyle:(NSTableViewRowActionStyle)style
                             title:(nullable NSString *)title
                           handler:(NSTableViewRowActionHandler)handler;

@property (readonly) NSTableViewRowActionStyle style;
@property (nullable, copy) NSString *title;
@property (nullable, readonly) NSTableViewRowActionHandler handler;
@property (nullable, strong) id backgroundColor;   /* NSColor */
@property (nullable, strong) id image;             /* NSImage */
@property BOOL allowsFullSwipe;

@end

NS_ASSUME_NONNULL_END
