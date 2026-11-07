/*
 * NSColorWell.h — 1:1 reimplementation (core). NSControl subclass.
 * Evidence ../evidence/cwell: _color @0x728, _cwFlags @0x724 (isActive = bit 0,
 * isBordered = bit 1). color is an NSColor (cluster) → stage2 id. activate:/
 * deactivate flip the active bit; the NSColorPanel interaction is stage2.
 */
#import "NSControl.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSColorWell : NSControl
@property (nullable, strong) id color;   /* NSColor (cluster) — stage2 */
@property (getter=isActive, readonly) BOOL active;
@property (getter=isBordered) BOOL bordered;
- (void)activate:(BOOL)exclusive;
- (void)deactivate;
@end

NS_ASSUME_NONNULL_END
