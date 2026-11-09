/*
 * NSCursor.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/cursor: hotSpot @0x8 (NSPoint), image @0x20;
 * currentCursor and the set/push/pop stack are process globals guarded by the
 * AppKit lock and pushed to the window server — the server side is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
@class NSImage;

NS_ASSUME_NONNULL_BEGIN

@interface NSCursor : NSObject
- (instancetype)initWithImage:(nullable id)image hotSpot:(CGPoint)hotSpot;
@property (nullable, readonly, strong) id image;
@property (readonly) CGPoint hotSpot;
@property (class, readonly, strong) NSCursor *currentCursor;
- (void)set;
- (void)push;
+ (void)pop;
@end

NS_ASSUME_NONNULL_END
