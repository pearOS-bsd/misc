/*
 * NSPanel.h — 1:1 reimplementation (core). NSWindow subclass.
 * Evidence ../evidence/panel: all three flags live in the inherited NSWindow
 * _wFlags (isFloatingPanel = bit 22, becomesKeyOnlyIfNeeded = bit 15,
 * worksWhenModal = bit 14). Since our NSWindow keeps _wFlags private, NSPanel
 * holds its own flag word here (observationally identical; TODO(stage2): share
 * the inherited _wFlags).
 */
#import "NSWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPanel : NSWindow
@property (getter=isFloatingPanel) BOOL floatingPanel;
@property BOOL becomesKeyOnlyIfNeeded;
@property BOOL worksWhenModal;
@end

NS_ASSUME_NONNULL_END
