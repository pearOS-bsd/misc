/*
 * NSPathControlItem.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSPathControlItem : NSObject {
 *       @"NSPathComponentCell" _cell;
 *   }
 *   @property (T@"NSString",C) title;  (T@"NSAttributedString",C) attributedTitle;
 *   @property (T@"NSImage",&) image;  (T@"NSURL",R) URL;
 *   -setURL: -setTitle: -setAttributedTitle: -image -setImage:
 *
 * One component of an NSPathControl's path. The real item stores everything in a
 * backing NSPathComponentCell; this core keeps the title/attributedTitle (kept
 * in sync), image and URL directly. The component cell and its drawing are
 * stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSPathControlItem : NSObject

@property (copy) NSString *title;
@property (copy) NSAttributedString *attributedTitle;
@property (nullable, strong) id image;   /* NSImage */
@property (nullable, strong) NSURL *URL;

@end

NS_ASSUME_NONNULL_END
