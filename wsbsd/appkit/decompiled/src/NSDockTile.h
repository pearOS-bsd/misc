/*
 * NSDockTile.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSDockTile : NSObject {
 *       @ _owner;  ^v _dockContextRef;  @"NSView" _contentView;  @"NSView" _frameView;
 *       @"NSString" _badgeLabel;  {?="showsAppBadge"b1 …} _dFlags;
 *       {CGSize} _dockTileSize;  …
 *   }
 *   -contentView -setContentView: -badgeLabel -setBadgeLabel:
 *   -showsApplicationBadge -setShowsApplicationBadge: -size -owner -display
 *
 * Represents a window's or app's Dock tile. The core tracks the content view,
 * badge label, the showsAppBadge flag (_dFlags b0), the tile size and owner.
 * -display pushes the tile to the Dock via the dock context — that push and the
 * live tile size from the Dock are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSView;

@interface NSDockTile : NSObject

@property (nullable, strong) NSView *contentView;
@property (nullable, copy) NSString *badgeLabel;
@property BOOL showsApplicationBadge;
@property (readonly) CGSize size;
@property (nullable, readonly, weak) id owner;

- (void)display;

@end

NS_ASSUME_NONNULL_END
