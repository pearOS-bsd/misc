/*
 * NSSharingService.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSSharingService : NSObject {
 *       @"NSSharingServiceReserved" _reserved;   // opaque state
 *   }
 *   @property (T@"NSString",R,C) title;  (T@"NSImage",R) image/alternateImage;
 *   @property (T@"NSString",C) menuItemTitle;  (T@"NSArray",C) recipients;
 *   @property (T@"NSString",C) subject;  (weak) delegate;
 *   -initWithTitle:image:alternateImage:handler: -canPerformWithItems:
 *   -performWithItems:
 *
 * A custom sharing service built from a title, images and a handler block. The
 * core stores those plus the editable recipients/subject/menuItemTitle and
 * invokes the handler from performWithItems:. The built-in system services
 * (sharingServiceNamed:) and their real share sheets are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSharingService : NSObject

- (instancetype)initWithTitle:(NSString *)title
                        image:(nullable id)image
               alternateImage:(nullable id)alternateImage
                      handler:(void (^)(void))block;

@property (nullable, weak) id delegate;
@property (readonly, copy) NSString *title;
@property (nullable, readonly) id image;
@property (nullable, readonly) id alternateImage;
@property (nullable, copy) NSString *menuItemTitle;
@property (nullable, copy) NSArray *recipients;
@property (nullable, copy) NSString *subject;

- (BOOL)canPerformWithItems:(nullable NSArray *)items;
- (void)performWithItems:(NSArray *)items;

@end

NS_ASSUME_NONNULL_END
