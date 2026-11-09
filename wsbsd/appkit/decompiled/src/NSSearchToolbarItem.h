/*
 * NSSearchToolbarItem.h — 1:1 reimplementation (core). NSToolbarItem subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSSearchToolbarItem : NSToolbarItem <NSSearchFieldDelegate, …> {
 *       B _isEditing;  B _resignsFirstResponderWithCancel;
 *       d _preferredWidthForSearchField;  @"NSObject<…>" _delegate; …
 *   }
 *   @property (T@"NSSearchField",&) searchField;
 *   @property (TB,V_resignsFirstResponderWithCancel) resignsFirstResponderWithCancel;
 *   @property (Td,V_preferredWidthForSearchField) preferredWidthForSearchField;
 *   -isEditing -beginEditing -endEditing
 *
 * A toolbar item hosting a search field. The core tracks the search field (lazily
 * created), the cancel-resign flag (default YES), the preferred width and the
 * editing state. The collapse-to-button representation and first-responder
 * editing transitions are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSToolbarItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSearchToolbarItem : NSToolbarItem

@property (strong) id searchField;   /* NSSearchField */
@property BOOL resignsFirstResponderWithCancel;
@property CGFloat preferredWidthForSearchField;
@property (readonly, getter=isEditing) BOOL editing;

- (void)beginEditing;
- (void)endEditing;

@end

NS_ASSUME_NONNULL_END
