/*
 * NSCollectionViewUpdateItem.m — 1:1 (core). See the header for the evidence.
 *
 * initWithOldIndexPath:newIndexPath: stores the two paths and infers the action:
 *   old && !new            -> Delete
 *   !old && new            -> Insert
 *   old && new, equal      -> Reload
 *   old && new, different  -> Move
 *   neither                -> None
 * The batch-update animation is stage2.
 */
#import "NSCollectionViewUpdateItem.h"

@implementation NSCollectionViewUpdateItem {
    NSIndexPath *_initialIndexPath;
    NSIndexPath *_finalIndexPath;
    NSCollectionUpdateAction _updateAction;
}

- (instancetype)initWithOldIndexPath:(NSIndexPath *)oldIndexPath
                        newIndexPath:(NSIndexPath *)newIndexPath
{
    self = [super init];
    if (self) {
        _initialIndexPath = oldIndexPath;
        _finalIndexPath = newIndexPath;
        if (oldIndexPath && !newIndexPath)      _updateAction = NSCollectionUpdateActionDelete;
        else if (!oldIndexPath && newIndexPath) _updateAction = NSCollectionUpdateActionInsert;
        else if (oldIndexPath && newIndexPath)
            _updateAction = [oldIndexPath isEqual:newIndexPath] ? NSCollectionUpdateActionReload
                                                               : NSCollectionUpdateActionMove;
        else                                    _updateAction = NSCollectionUpdateActionNone;
    }
    return self;
}

- (NSIndexPath *)indexPathBeforeUpdate { return _initialIndexPath; }
- (NSIndexPath *)indexPathAfterUpdate { return _finalIndexPath; }
- (NSCollectionUpdateAction)updateAction { return _updateAction; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[NSCollectionViewUpdateItem alloc] initWithOldIndexPath:_initialIndexPath
                                                      newIndexPath:_finalIndexPath];
}

@end
