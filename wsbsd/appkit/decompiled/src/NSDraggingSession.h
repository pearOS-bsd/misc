/*
 * NSDraggingSession.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSDraggingSession, the object returned by -beginDraggingSessionWithItems:….
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSDraggingSession_interface.txt. Real ivars: _pboard, _source,
 * _localItemObjects, _offset, _startLocation, _state, _isDragging, …
 *
 * There is no public initializer (AppKit constructs it when a drag begins); this
 * core adds an internal `_initWith…` so the value model is testable. The live
 * drag tracking loop, slide-back and composite drag image are TODO(stage2).
 * animatesToStartingPositionsOnCancelOrFail defaults YES, draggingFormation
 * defaults Default(0) (documented).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSPasteboard, NSView, NSDraggingItem;

typedef NS_ENUM(NSInteger, NSDraggingFormation) {
    NSDraggingFormationDefault = 0,
    NSDraggingFormationNone    = 1,
    NSDraggingFormationPile    = 2,
    NSDraggingFormationStack   = 3,
    NSDraggingFormationList    = 4,
};

typedef NS_OPTIONS(NSUInteger, NSDraggingItemEnumerationOptions) {
    NSDraggingItemEnumerationConcurrent             = 1 << 0,
    NSDraggingItemEnumerationClearNonenumeratedImages = 1 << 16,
};

@interface NSDraggingSession : NSObject

@property NSDraggingFormation draggingFormation;                   /* default Default */
@property BOOL animatesToStartingPositionsOnCancelOrFail;          /* default YES */
@property NSInteger draggingLeaderIndex;                           /* default 0 */
@property (readonly) NSInteger draggingSequenceNumber;
@property (readonly, strong) NSPasteboard *draggingPasteboard;
@property NSPoint draggingLocation;
@property (readonly) NSInteger numberOfDraggedItems;

- (void)enumerateDraggingItemsWithOptions:(NSDraggingItemEnumerationOptions)enumOpts
                                  forView:(nullable NSView *)view
                                  classes:(NSArray *)classArray
                            searchOptions:(NSDictionary *)searchOptions
                               usingBlock:(void (^)(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
