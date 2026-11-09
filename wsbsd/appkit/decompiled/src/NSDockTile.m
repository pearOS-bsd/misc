/*
 * NSDockTile.m — 1:1 (core). See NSDockTile.h for the interface evidence.
 *
 * Tracks the content view, badge label, showsApplicationBadge flag (_dFlags b0),
 * the tile size (default 128x128) and the owner. -display marks the tile for a
 * refresh; actually drawing it into the Dock through the private dock context,
 * and querying the live tile size from the Dock, are stage2.
 */
#import "NSDockTile.h"

@implementation NSDockTile {
    __weak id _owner;
    NSView *_contentView;
    NSString *_badgeLabel;
    BOOL _showsAppBadge;         /* _dFlags b0 */
    CGSize _dockTileSize;
    BOOL _needsDisplay;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _dockTileSize = CGSizeMake(128, 128); }
    return self;
}

- (instancetype)_initWithOwner:(id)owner
{
    self = [self init];
    if (self) _owner = owner;
    return self;
}

- (NSView *)contentView { return _contentView; }
- (void)setContentView:(NSView *)v { _contentView = v; }
- (NSString *)badgeLabel { return _badgeLabel; }
- (void)setBadgeLabel:(NSString *)v { _badgeLabel = [v copy]; _needsDisplay = YES; }
- (BOOL)showsApplicationBadge { return _showsAppBadge; }
- (void)setShowsApplicationBadge:(BOOL)v { _showsAppBadge = v; }
- (CGSize)size { return _dockTileSize; }   /* stage2: query the Dock */
- (id)owner { return _owner; }

- (void)display { _needsDisplay = NO; } /* stage2: render into the dock context */

@end
