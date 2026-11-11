/*
 * NSScrubber.h — 1:1 reimplementation (behavioral core) of AppKit's NSScrubber
 * (: NSView), the Touch Bar scrubber control.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubber_interface.txt. Real ivars include the backing
 * NSScrollView, the scrub/scroll/press gesture recognizers, arrow buttons and a
 * packed flags word (continuous/isInteracting/…).
 *
 * Defaults MEASURED on this Mac: selectedIndex/highlightedIndex = -1,
 * numberOfItems = 0, mode Fixed(0), itemAlignment None(0), showsArrowButtons /
 * continuous / floatsSelectionViews = NO, tag 0, backgroundColor = semantic
 * controlBackgroundColor.
 *
 * This core reproduces the data/selection value model: dataSource/delegate,
 * reloadData → numberOfItems, selectedIndex (clamped), the config properties and
 * the data-source item-view vending. The NSScrollView item layout, gesture
 * scrubbing, arrow buttons, selection background/overlay rendering, item reuse
 * and batch animations are TODO(stage2).
 */

#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

@class NSColor, NSScrubberSelectionStyle, NSScrubberLayout;
@protocol NSScrubberDataSource, NSScrubberDelegate;

typedef NS_ENUM(NSInteger, NSScrubberMode) {
    NSScrubberModeFixed = 0,
    NSScrubberModeFree  = 1,
};

typedef NS_ENUM(NSInteger, NSScrubberAlignment) {
    NSScrubberAlignmentNone     = 0,
    NSScrubberAlignmentLeading  = 1,
    NSScrubberAlignmentTrailing = 2,
    NSScrubberAlignmentCenter   = 3,
};

@interface NSScrubber : NSView

@property (nullable, weak) id<NSScrubberDataSource> dataSource;
@property (nullable, weak) id<NSScrubberDelegate> delegate;
@property (nullable, strong) NSScrubberLayout *scrubberLayout;

@property (readonly) NSInteger numberOfItems;
@property (readonly) NSInteger highlightedIndex;
@property NSInteger selectedIndex;                 /* default -1 */
@property NSInteger tag;

@property NSScrubberMode mode;                     /* default Fixed */
@property NSScrubberAlignment itemAlignment;       /* default None */
@property (getter=isContinuous) BOOL continuous;   /* default NO */
@property BOOL floatsSelectionViews;               /* default NO */
@property BOOL showsArrowButtons;                  /* default NO */
@property BOOL showsAdditionalContentIndicators;

@property (nullable, copy) NSColor *backgroundColor;
@property (nullable, strong) NSView *backgroundView;
@property (nullable, strong) NSScrubberSelectionStyle *selectionBackgroundStyle;
@property (nullable, strong) NSScrubberSelectionStyle *selectionOverlayStyle;

- (void)reloadData;
- (nullable NSView *)itemViewForItemAtIndex:(NSInteger)index;
- (void)scrollItemAtIndex:(NSInteger)index toAlignment:(NSScrubberAlignment)alignment;

@end

@protocol NSScrubberDataSource <NSObject>
@required
- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)scrubber;
- (NSView *)scrubber:(NSScrubber *)scrubber viewForItemAtIndex:(NSInteger)index;
@end

@protocol NSScrubberDelegate <NSObject>
@optional
- (void)scrubber:(NSScrubber *)scrubber didSelectItemAtIndex:(NSInteger)selectedIndex;
- (void)scrubber:(NSScrubber *)scrubber didHighlightItemAtIndex:(NSInteger)highlightedIndex;
@end

NS_ASSUME_NONNULL_END
