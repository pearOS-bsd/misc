/* The Touch Bar of AppKit: NSTouchBar, its items, the responder chain that finds the bar of the key window, and a host that shows the bar in a window at the bottom of the screen (the emulation of the hardware
 * strip, 1085 x 30 pt like the real one). Implemented in sdk/src/TouchBar.m as categories on GNUstep's empty classes. Inventory of the real classes: docs/touchbar. */
#ifndef WSBSD_TOUCHBAR_H
#define WSBSD_TOUCHBAR_H
#import <AppKit/AppKit.h>

typedef NSString *NSTouchBarItemIdentifier;
@class NSTouchBar, NSTouchBarItem;
@protocol NSTouchBarDelegate <NSObject>
@optional
- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier;
@end
@protocol NSTouchBarProvider <NSObject>
@property (strong, readonly) NSTouchBar *touchBar;
@end

extern NSString *const NSTouchBarItemIdentifierFixedSpaceSmall, *const NSTouchBarItemIdentifierFixedSpaceLarge, *const NSTouchBarItemIdentifierFlexibleSpace, *const NSTouchBarItemIdentifierOtherItemsProxy,
	*const NSTouchBarItemIdentifierCharacterPicker, *const NSTouchBarItemIdentifierTextFormat, *const NSTouchBarItemIdentifierTextAlignment, *const NSTouchBarItemIdentifierTextColorPicker, *const NSTouchBarItemIdentifierTextStyle,
	*const NSTouchBarItemIdentifierTextList, *const NSTouchBarItemIdentifierTextHighlight, *const NSTouchBarItemIdentifierCandidateList;

@interface NSTouchBar (WsbsdTouchBar)
@property (assign) id<NSTouchBarDelegate> delegate;
@property (copy) NSString *customizationIdentifier;
@property (copy) NSArray<NSTouchBarItemIdentifier> *customizationAllowedItemIdentifiers, *customizationRequiredItemIdentifiers, *defaultItemIdentifiers;
@property (copy, readonly) NSArray<NSTouchBarItemIdentifier> *itemIdentifiers;
- (void)_wsSaveItems:(NSArray *)ids;
@property (copy) NSTouchBarItemIdentifier principalItemIdentifier, escapeKeyReplacementItemIdentifier;
@property (copy) NSSet<NSTouchBarItem *> *templateItems;
@property (readonly, getter=isVisible) BOOL visible;
- (NSTouchBarItem *)itemForIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (BOOL)isAutomaticCustomizeTouchBarMenuItemEnabled;
@end

@interface NSTouchBarItem (WsbsdTouchBar)
- (instancetype)initWithIdentifier:(NSTouchBarItemIdentifier)identifier;
@property (readonly, copy) NSTouchBarItemIdentifier identifier;
@property float visibilityPriority;
@property (readonly, strong) NSView *view;
@property (readonly, strong) NSViewController *viewController;
@property (readonly, copy) NSString *customizationLabel;
@property (readonly, getter=isVisible) BOOL visible;
@end
enum { NSTouchBarItemPriorityHigh = 1000, NSTouchBarItemPriorityNormal = 0, NSTouchBarItemPriorityLow = -1000 };

@interface NSCustomTouchBarItem (WsbsdTouchBar)
@property (strong) NSView *view;
@property (strong) NSViewController *viewController;
@property (copy) NSString *customizationLabel;
@end

@interface NSButtonTouchBarItem (WsbsdTouchBar)
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)identifier title:(NSString *)title target:(id)target action:(SEL)action;
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)identifier image:(NSImage *)image target:(id)target action:(SEL)action;
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)identifier title:(NSString *)title image:(NSImage *)image target:(id)target action:(SEL)action;
@property (copy) NSString *title;
@property (strong) NSImage *image;
@property (strong) NSColor *bezelColor;
@property (weak) id target;
@property SEL action;
@property (getter=isEnabled) BOOL enabled;
@property (copy) NSString *customizationLabel;
@end

@interface NSGroupTouchBarItem (WsbsdTouchBar)
+ (instancetype)groupItemWithIdentifier:(NSTouchBarItemIdentifier)identifier items:(NSArray<NSTouchBarItem *> *)items;
@property (strong) NSTouchBar *groupTouchBar;
@property (copy) NSString *customizationLabel;
@end

@interface NSSliderTouchBarItem (WsbsdTouchBar)
@property (strong) NSSlider *slider;
@property double doubleValue;
@property (weak) id target;
@property SEL action;
@property (copy) NSString *customizationLabel;
@end

@interface NSResponder (WsbsdTouchBar)
@property (strong) NSTouchBar *touchBar;
- (NSTouchBar *)makeTouchBar;
@end


/* ---- scrubber ---- */
typedef NS_ENUM(NSInteger, NSScrubberMode) { NSScrubberModeFixed = 0, NSScrubberModeFree = 1 };
typedef NS_ENUM(NSInteger, NSScrubberAlignment) { NSScrubberAlignmentNone = 0, NSScrubberAlignmentLeading, NSScrubberAlignmentTrailing, NSScrubberAlignmentCenter };
typedef NSString *NSScrubberItemIdentifier;
@class NSScrubber, NSScrubberLayout, NSScrubberSelectionStyle, NSScrubberItemView, NSScrubberLayoutAttributes;
@protocol NSScrubberDataSource <NSObject>
- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)scrubber;
- (NSScrubberItemView *)scrubber:(NSScrubber *)scrubber viewForItemAtIndex:(NSInteger)index;
@end
@protocol NSScrubberDelegate <NSObject>
@optional
- (void)scrubber:(NSScrubber *)scrubber didSelectItemAtIndex:(NSInteger)selectedIndex;
- (void)scrubber:(NSScrubber *)scrubber didHighlightItemAtIndex:(NSInteger)highlightedIndex;
- (void)scrubber:(NSScrubber *)scrubber didChangeVisibleRange:(NSRange)visibleRange;
- (void)didBeginInteractingWithScrubber:(NSScrubber *)scrubber;
- (void)didFinishInteractingWithScrubber:(NSScrubber *)scrubber;
- (void)didCancelInteractingWithScrubber:(NSScrubber *)scrubber;
@end
@interface NSScrubberLayoutAttributes (WsbsdTouchBar)
@property NSInteger itemIndex; @property NSRect frame; @property CGFloat alpha;
+ (instancetype)layoutAttributesForItemAtIndex:(NSInteger)index;
@end
@interface NSScrubberLayout (WsbsdTouchBar)
@property (weak) NSScrubber *scrubber;
+ (Class)layoutAttributesClass;
@property (readonly) NSSize scrubberContentSize; @property (readonly) NSRect visibleRect; @property (readonly) BOOL automaticallyMirrorsInRightToLeftLayout;
- (void)invalidateLayout; - (void)prepareLayout;
- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)index;
- (NSSet<NSScrubberLayoutAttributes *> *)layoutAttributesForItemsInRect:(NSRect)rect;
- (BOOL)shouldInvalidateLayoutForSelectionChange; - (BOOL)shouldInvalidateLayoutForHighlightChange; - (BOOL)shouldInvalidateLayoutForChangeFromVisibleRect:(NSRect)from toVisibleRect:(NSRect)to;
@end
@interface NSScrubberFlowLayout : NSScrubberLayout { CGFloat _itemSpacing; NSSize _itemSize; }
@property CGFloat itemSpacing; @property NSSize itemSize;
- (void)invalidateLayoutForItemsAtIndexes:(NSIndexSet *)indexes;
@end
@interface NSScrubberProportionalLayout : NSScrubberLayout { NSInteger _numberOfVisibleItems; }
@property NSInteger numberOfVisibleItems;
- (instancetype)initWithNumberOfVisibleItems:(NSInteger)n;
@end
@interface NSScrubberSelectionStyle : NSObject
+ (NSScrubberSelectionStyle *)outlineOverlayStyle; + (NSScrubberSelectionStyle *)roundedBackgroundStyle;
- (NSScrubberSelectionStyle *)init;
- (NSView *)makeSelectionView;
@end
@interface NSScrubberArrangedView (WsbsdTouchBar)
@property (getter=isSelected) BOOL selected; @property (getter=isHighlighted) BOOL highlighted;
- (void)applyLayoutAttributes:(NSScrubberLayoutAttributes *)la;
@end
@interface NSScrubberTextItemView : NSScrubberItemView { NSTextField *_textField; }
@property (copy) NSString *title; @property (readonly, strong) NSTextField *textField;
@end
@interface NSScrubberImageItemView : NSScrubberItemView { NSImageView *_imageView; }
@property (strong) NSImage *image; @property NSImageAlignment imageAlignment; @property (readonly, strong) NSImageView *imageView;
@end
@interface NSScrubber (WsbsdTouchBar)
@property (weak) id<NSScrubberDataSource> dataSource; @property (weak) id<NSScrubberDelegate> delegate; @property (strong) NSScrubberLayout *scrubberLayout;
@property NSScrubberMode mode; @property (getter=isContinuous) BOOL continuous; @property BOOL floatsSelectionViews; @property NSInteger selectedIndex, highlightedIndex; @property (readonly) NSInteger numberOfItems; @property (readonly) NSRange visibleRange;
@property (strong) NSScrubberSelectionStyle *selectionBackgroundStyle, *selectionOverlayStyle; @property NSScrubberAlignment itemAlignment; @property BOOL showsArrowButtons, showsAdditionalContentIndicators; @property (strong) NSColor *backgroundColor; @property (strong) NSView *backgroundView;
- (void)reloadData; - (void)registerClass:(Class)itemViewClass forItemIdentifier:(NSScrubberItemIdentifier)identifier;
- (NSScrubberItemView *)makeItemWithIdentifier:(NSScrubberItemIdentifier)identifier owner:(id)owner;
- (NSScrubberItemView *)itemViewForItemAtIndex:(NSInteger)index; - (void)scrollItemAtIndex:(NSInteger)index toAlignment:(NSScrubberAlignment)alignment;
- (void)insertItemsAtIndexes:(NSIndexSet *)i; - (void)removeItemsAtIndexes:(NSIndexSet *)i; - (void)reloadItemsAtIndexes:(NSIndexSet *)i; - (void)moveItemAtIndex:(NSInteger)a toIndex:(NSInteger)b;
- (void)performSequentialBatchUpdates:(void (^)(void))updateBlock;
@end

/* ---- more items ---- */
typedef NS_ENUM(NSInteger, NSPickerTouchBarItemSelectionMode) { NSPickerTouchBarItemSelectionModeSelectOne = 0, NSPickerTouchBarItemSelectionModeSelectAny = 1, NSPickerTouchBarItemSelectionModeMomentary = 2 };
typedef NS_ENUM(NSInteger, NSPickerTouchBarItemControlRepresentation) { NSPickerTouchBarItemControlRepresentationAutomatic = 0, NSPickerTouchBarItemControlRepresentationExpanded = 1, NSPickerTouchBarItemControlRepresentationCollapsed = 2 };
@interface NSPickerTouchBarItem (WsbsdTouchBar)
+ (instancetype)pickerTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)identifier labels:(NSArray<NSString *> *)labels selectionMode:(NSPickerTouchBarItemSelectionMode)mode target:(id)target action:(SEL)action;
+ (instancetype)pickerTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)identifier images:(NSArray<NSImage *> *)images selectionMode:(NSPickerTouchBarItemSelectionMode)mode target:(id)target action:(SEL)action;
@property NSInteger selectedIndex; @property (strong) NSColor *selectionColor; @property NSPickerTouchBarItemSelectionMode selectionMode; @property NSPickerTouchBarItemControlRepresentation controlRepresentation; @property NSInteger numberOfOptions;
@property (copy) NSString *collapsedRepresentationLabel; @property (strong) NSImage *collapsedRepresentationImage; @property (weak) id target; @property SEL action; @property (getter=isEnabled) BOOL enabled; @property (copy) NSString *customizationLabel;
- (void)setImage:(NSImage *)image atIndex:(NSInteger)index; - (NSImage *)imageAtIndex:(NSInteger)index; - (void)setLabel:(NSString *)label atIndex:(NSInteger)index; - (NSString *)labelAtIndex:(NSInteger)index;
- (void)setEnabled:(BOOL)enabled atIndex:(NSInteger)index; - (BOOL)isEnabledAtIndex:(NSInteger)index;
@end
@interface NSPopoverTouchBarItem (WsbsdTouchBar)
@property (strong) NSTouchBar *popoverTouchBar, *pressAndHoldTouchBar; @property (strong) NSView *collapsedRepresentation; @property (strong) NSImage *collapsedRepresentationImage; @property (copy) NSString *collapsedRepresentationLabel; @property BOOL showsCloseButton; @property (copy) NSString *customizationLabel;
- (void)showPopover:(id)sender; - (void)dismissPopover:(id)sender; - (NSGestureRecognizer *)makeStandardActivatePopoverGestureRecognizer;
@end
@interface NSStepperTouchBarItem (WsbsdTouchBar)
+ (instancetype)stepperTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)identifier formatter:(NSFormatter *)formatter;
@property double maxValue, minValue, increment, value; @property (weak) id target; @property SEL action; @property (copy) NSString *customizationLabel;
@end
@interface NSColorPickerTouchBarItem (WsbsdTouchBar)
+ (instancetype)colorPickerWithIdentifier:(NSTouchBarItemIdentifier)identifier; + (instancetype)textColorPickerWithIdentifier:(NSTouchBarItemIdentifier)identifier; + (instancetype)strokeColorPickerWithIdentifier:(NSTouchBarItemIdentifier)identifier; + (instancetype)colorPickerWithIdentifier:(NSTouchBarItemIdentifier)identifier buttonImage:(NSImage *)image;
@property (strong) NSColor *color; @property BOOL showsAlpha; @property (strong) NSColorList *colorList; @property (weak) id target; @property SEL action; @property (getter=isEnabled) BOOL enabled; @property (copy) NSString *customizationLabel;
@end
@class NSSharingServicePickerTouchBarItem, NSCandidateListTouchBarItem;
@protocol NSSharingServicePickerTouchBarItemDelegate <NSObject>
@optional
- (NSArray *)itemsForSharingServicePickerTouchBarItem:(NSSharingServicePickerTouchBarItem *)pickerTouchBarItem;
@end
@protocol NSCandidateListTouchBarItemDelegate <NSObject>
@optional
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem beginSelectingCandidateAtIndex:(NSInteger)index;
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem changeSelectionFromCandidateAtIndex:(NSInteger)previousIndex toIndex:(NSInteger)index;
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem endSelectingCandidateAtIndex:(NSInteger)index;
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem changedCandidateListVisibility:(BOOL)isVisible;
@end
@interface NSSharingServicePickerTouchBarItem (WsbsdTouchBar)
@property (weak) id delegate; @property (getter=isEnabled) BOOL enabled; @property (strong) NSImage *buttonImage; @property (copy) NSString *buttonTitle; @property (copy) NSString *customizationLabel;
@end
@interface NSCandidateListTouchBarItem (WsbsdTouchBar)
@property (weak) id delegate; @property (getter=isCandidateListVisible, readonly) BOOL candidateListVisible; @property (copy) void (^updateWithInsertionPointVisibility)(BOOL); @property (strong) NSView *client; @property (copy) NSString *customizationLabel;
- (void)setCandidates:(NSArray *)candidates forSelectedRange:(NSRange)selectedRange inString:(NSString *)originalString;
@end
@interface NSGroupTouchBarItem (WsbsdTouchBarAlert)
+ (instancetype)alertStyleGroupItemWithIdentifier:(NSTouchBarItemIdentifier)identifier;
@end

/* the system side of the bar */
@interface NSTouchBar (WsbsdSystemModal)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar placement:(long long)placement systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)touchBar;
@end
@interface NSTouchBarItem (WsbsdSystemTray)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item; + (void)removeSystemTrayItem:(NSTouchBarItem *)item;
@end
@interface NSApplication (WsbsdTouchBar)
- (void)toggleTouchBarCustomizationPalette:(id)sender; - (BOOL)isTouchBarCustomizationPaletteVisible;
@end

/* the host: the bar shown now and the window that shows it */
@interface WsbsdTouchBarHost : NSObject
+ (instancetype)sharedHost;
@property (readonly, strong) NSTouchBar *currentTouchBar;
@property (readonly, strong) NSPanel *panel;
- (void)update;
- (void)invalidate;   /* the bar is built again at the next update */
- (void)_showPalette:(NSTouchBar *)target;
- (void)showSystemSlider:(int)which;   /* 0 brightness, 1 volume */
+ (void)_presentBar:(NSTouchBar *)bar closeButton:(BOOL)close;
+ (void)_dismissBar:(NSTouchBar *)bar;
@end
#endif
