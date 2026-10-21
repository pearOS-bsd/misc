/* More of AppKit / Foundation that large Mac applications use (found while building TextMate); implemented in sdk/src/AppKitCompat2.m or, where it is part of the AppKit back end, in appkit/back-wsd.
 * Accessibility attributes are kept on the objects (they read back) but nothing reads them: there is no accessibility service. */
#ifndef WSBSD_APPKITCOMPAT2_H
#define WSBSD_APPKITCOMPAT2_H
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NSURL (WsbsdFS)
@property (nonatomic, readonly) const char *fileSystemRepresentation;
@property (nonatomic, readonly) BOOL hasDirectoryPath;
@end

@interface NSImage (WsbsdDrawing)
+ (NSImage *)imageWithSize:(NSSize)size flipped:(BOOL)drawingHandlerShouldBeCalledWithFlippedContext drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler;
@property (nonatomic, copy) NSString *accessibilityDescription;
@end

@interface NSObject (WsbsdAccessibility)
- (id)accessibilityAttributeValue:(NSString *)attribute;
- (id)accessibilityAttributeValue:(NSString *)attribute forParameter:(id)parameter;
- (BOOL)accessibilitySetOverrideValue:(id)value forAttribute:(NSString *)attribute;
@property (nonatomic, copy) NSString *accessibilityLabel;
@property (nonatomic, copy) NSString *accessibilityTitle;
@property (nonatomic, copy) NSString *accessibilityHelp;
@property (nonatomic, copy) NSString *accessibilityIdentifier;
@property (nonatomic, copy) NSString *accessibilityRole;
@property (nonatomic, copy) NSString *accessibilityRoleDescription;
@property (nonatomic, copy) NSString *accessibilitySubrole;
@property (nonatomic, copy) NSString *accessibilityPlaceholderValue;
@property (nonatomic, strong) id accessibilityValue;
@property (nonatomic, getter=isAccessibilityElement) BOOL accessibilityElement;
@end
extern NSString *const NSAccessibilityException;

@interface NSColor (WsbsdCG)
+ (NSColor *)colorWithCGColor:(CGColorRef)cgColor;
@property (nonatomic, readonly) CGColorRef CGColor;
@end

@interface NSEvent (WsbsdMonitors)
+ (id)addLocalMonitorForEventsMatchingMask:(unsigned long long)mask handler:(NSEvent *(^)(NSEvent *event))block;
+ (id)addGlobalMonitorForEventsMatchingMask:(unsigned long long)mask handler:(void (^)(NSEvent *event))block;
+ (void)removeMonitor:(id)eventMonitor;
@end

@interface NSWindow (WsbsdSheets)
- (void)endSheet:(NSWindow *)sheetWindow returnCode:(NSInteger)returnCode;
@end

@interface NSViewController (WsbsdHierarchy)
@property (nonatomic, readonly, copy) NSArray *childViewControllers;
@property (nonatomic, copy) NSString *identifier;
@end

@protocol NSStandardKeyBindingResponding <NSObject> @end
typedef NSString *NSTouchBarItemIdentifier;
#define NSDictionaryOfVariableBindings(...) _NSDictionaryOfVariableBindings(@"" # __VA_ARGS__, __VA_ARGS__, nil)
NSDictionary *_NSDictionaryOfVariableBindings(NSString *commaSeparatedKeysString, id firstValue, ...);
extern NSString *const NSFontFeatureTypeIdentifierKey;
extern NSString *const NSFontFeatureSelectorIdentifierKey;
extern NSString *const NSFontFeatureSettingsAttribute;

/* implemented in appkit/back-wsd/WsdMoreAppKit.m */
@interface NSColorSpace (WsbsdMore)
+ (NSColorSpace *)sRGBColorSpace;
+ (NSColorSpace *)displayP3ColorSpace;
@end
@interface NSScreen (WsbsdMore)
+ (BOOL)screensHaveSeparateSpaces;
@property (nonatomic, readonly, copy) NSString *localizedName;
@property (nonatomic, readonly) NSColorSpace *colorSpace;
@property (nonatomic, readonly) unsigned int CGDirectDisplayID;
@property (nonatomic, readonly) NSInteger maximumFramesPerSecond;
@property (nonatomic, readonly) NSTimeInterval minimumRefreshInterval, maximumRefreshInterval, displayUpdateGranularity, lastDisplayUpdateTimestamp;
@property (nonatomic, readonly) NSEdgeInsets safeAreaInsets;
@property (nonatomic, readonly) NSRect auxiliaryTopLeftArea, auxiliaryTopRightArea;
- (NSRect)convertRectToBacking:(NSRect)rect;
- (NSRect)convertRectFromBacking:(NSRect)rect;
- (NSRect)backingAlignedRect:(NSRect)rect options:(NSAlignmentOptions)options;
- (BOOL)canRepresentDisplayGamut:(NSInteger)gamut;
@end
@interface NSSegmentedControl (WsbsdMore)
- (NSInteger)tagForSegment:(NSInteger)segment;
- (void)setTag:(NSInteger)tag forSegment:(NSInteger)segment;
- (NSInteger)indexOfSelectedItem;
- (double)doubleValueForSelectedSegment;
- (NSTextAlignment)alignmentForSegment:(NSInteger)segment;
- (void)setAlignment:(NSTextAlignment)alignment forSegment:(NSInteger)segment;
- (BOOL)showsMenuIndicatorForSegment:(NSInteger)segment;
- (void)setShowsMenuIndicator:(BOOL)shows forSegment:(NSInteger)segment;
@property (nonatomic) NSInteger segmentDistribution, borderShape, role;
@property (nonatomic, getter=isSpringLoaded) BOOL springLoaded;
@property (nonatomic, strong) NSColor *selectedSegmentBezelColor;
@end
@interface NSToolbar (WsbsdMore)
@property (nonatomic, readonly, copy) NSArray *itemIdentifiers;
- (void)removeItemWithItemIdentifier:(NSString *)itemIdentifier;
- (void)setItemIdentifiers:(NSArray *)identifiers;
@property (nonatomic, copy) NSArray *centeredItemIdentifiers;
@property (nonatomic, copy) NSString *centeredItemIdentifier;
@property (nonatomic) BOOL allowsDisplayModeCustomization, allowsExtensionItems;
@property (nonatomic, strong) NSView *fullScreenAccessoryView;
@property (nonatomic) CGFloat fullScreenAccessoryViewMinHeight, fullScreenAccessoryViewMaxHeight;
@end
@interface NSTextField (WsbsdMore)
@property (nonatomic) NSInteger maximumNumberOfLines;
@property (nonatomic) CGFloat preferredMaxLayoutWidth;
@property (nonatomic, copy) NSArray *placeholderStrings, *placeholderAttributedStrings;
@property (nonatomic) NSInteger lineBreakStrategy, borderShape;
@property (nonatomic) BOOL allowsDefaultTighteningForTruncation, resolvesNaturalAlignmentWithBaseWritingDirection;
@property (nonatomic, getter=isAutomaticTextCompletionEnabled) BOOL automaticTextCompletionEnabled;
@end
@interface NSControl (WsbsdLineBreak)
@property (nonatomic) NSLineBreakMode lineBreakMode;
@end
@interface NSLevelIndicator (WsbsdMore)
@property (nonatomic) NSLevelIndicatorStyle levelIndicatorStyle;
@property (nonatomic, getter=isEditable) BOOL editable;
@property (nonatomic, strong) NSColor *fillColor, *warningFillColor, *criticalFillColor;
@property (nonatomic) BOOL drawsTieredCapacityLevels;
@property (nonatomic) NSInteger placeholderVisibility;
@property (nonatomic, strong) NSImage *ratingImage, *ratingPlaceholderImage;
@end
@interface NSView (WsbsdGuides)
@property (nonatomic, readonly, strong) NSLayoutGuide *safeAreaLayoutGuide;
@property (nonatomic, readonly, strong) NSLayoutGuide *layoutMarginsGuide;
@end
#endif
