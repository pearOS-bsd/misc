/*
 * NSDraggingSession.m — behavioral-1:1 core. See NSDraggingSession.h.
 */

#import "NSDraggingSession.h"

@implementation NSDraggingSession {
    NSPasteboard *_pboard;
    NSArray<NSDraggingItem *> *_localItemObjects;
    NSInteger _sequenceNumber;
    NSDraggingFormation _draggingFormation;
    BOOL _animatesToStartingPositionsOnCancelOrFail;
    NSInteger _draggingLeaderIndex;
    NSPoint _draggingLocation;
}

/* internal: AppKit builds the session when a drag begins. */
- (instancetype)_initWithPasteboard:(NSPasteboard *)pasteboard
                              items:(NSArray<NSDraggingItem *> *)items
                     sequenceNumber:(NSInteger)sequenceNumber
{
    self = [super init];
    if (self) {
        _pboard = pasteboard;
        _localItemObjects = [items copy] ?: @[];
        _sequenceNumber = sequenceNumber;
        _draggingFormation = NSDraggingFormationDefault;
        _animatesToStartingPositionsOnCancelOrFail = YES;   /* documented default */
        _draggingLeaderIndex = 0;
    }
    return self;
}

- (NSDraggingFormation)draggingFormation { return _draggingFormation; }
- (void)setDraggingFormation:(NSDraggingFormation)f { _draggingFormation = f; }
- (BOOL)animatesToStartingPositionsOnCancelOrFail { return _animatesToStartingPositionsOnCancelOrFail; }
- (void)setAnimatesToStartingPositionsOnCancelOrFail:(BOOL)v { _animatesToStartingPositionsOnCancelOrFail = v; }
- (NSInteger)draggingLeaderIndex { return _draggingLeaderIndex; }
- (void)setDraggingLeaderIndex:(NSInteger)i { _draggingLeaderIndex = i; }
- (NSInteger)draggingSequenceNumber { return _sequenceNumber; }
- (NSPasteboard *)draggingPasteboard { return _pboard; }
- (NSPoint)draggingLocation { return _draggingLocation; }
- (void)setDraggingLocation:(NSPoint)p { _draggingLocation = p; }
- (NSInteger)numberOfDraggedItems { return (NSInteger)_localItemObjects.count; }
- (NSArray<NSDraggingItem *> *)localItemObjects { return _localItemObjects; }

- (void)enumerateDraggingItemsWithOptions:(NSDraggingItemEnumerationOptions)enumOpts
                                  forView:(NSView *)view
                                  classes:(NSArray *)classArray
                            searchOptions:(NSDictionary *)searchOptions
                               usingBlock:(void (^)(NSDraggingItem *, NSInteger, BOOL *))block
{
    if (!block) return;
    BOOL stop = NO;
    NSInteger idx = 0;
    for (NSDraggingItem *item in _localItemObjects) {
        /* TODO(stage2): filter by classArray/searchOptions against each item's
         * pasteboard contents; here every local item is enumerated. */
        block(item, idx++, &stop);
        if (stop) break;
    }
}

@end
