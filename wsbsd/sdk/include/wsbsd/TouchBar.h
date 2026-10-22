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

/* the host: the bar shown now and the window that shows it */
@interface WsbsdTouchBarHost : NSObject
+ (instancetype)sharedHost;
@property (readonly, strong) NSTouchBar *currentTouchBar;
@property (readonly, strong) NSPanel *panel;
- (void)update;
@end
#endif
