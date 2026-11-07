/*
 * NSActionCell.h — 1:1 reimplementation of AppKit's NSActionCell.
 *
 * Adds the real target/action/tag storage that NSCell only stubs, plus the
 * cached controlView. Shape from ../reference (NSActionCell section of the
 * AppKit dump); logic from ../evidence/nsactioncell. Addresses cited in the .m.
 */
#import "NSCell.h"

@class NSView;

NS_ASSUME_NONNULL_BEGIN

@interface NSActionCell : NSCell

@property (nullable, assign) id target;     /* non-retained, as in AppKit */
@property (nullable) SEL action;
@property NSInteger tag;
@property (nullable, weak) NSView *controlView;

@end

NS_ASSUME_NONNULL_END
