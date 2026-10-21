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

/* types and names of newer AppKit that were missing (TextMate build) */
typedef NSUInteger NSTableColumnResizingOptions;
typedef NS_ENUM(NSInteger, NSWindowTitleVisibility) { NSWindowTitleVisible = 0, NSWindowTitleHidden = 1 };
typedef NSUInteger NSMenuProperties;
enum { NSMenuPropertyItemTitle = 1 << 0, NSMenuPropertyItemAttributedTitle = 1 << 1, NSMenuPropertyItemKeyEquivalent = 1 << 2, NSMenuPropertyItemImage = 1 << 3, NSMenuPropertyItemEnabled = 1 << 4, NSMenuPropertyItemAccessibilityDescription = 1 << 5 };
@interface NSObject (WsbsdMenuDelegateProperties)
- (NSMenuProperties)propertiesToUpdate;
@end
extern NSString *const NSImageBinding;
typedef uint64_t CGEventFlags;
enum { kCGEventFlagMaskAlphaShift = 0x10000, kCGEventFlagMaskShift = 0x20000, kCGEventFlagMaskControl = 0x40000, kCGEventFlagMaskAlternate = 0x80000, kCGEventFlagMaskCommand = 0x100000,
       kCGEventFlagMaskHelp = 0x400000, kCGEventFlagMaskSecondaryFn = 0x800000, kCGEventFlagMaskNumericPad = 0x200000 };
extern const CFStringRef kUTTypeFileURL;
@interface NSStringDrawingContext : NSObject
@property (nonatomic) CGFloat minimumScaleFactor, minimumTrackingAdjustment;
@property (nonatomic, readonly) CGFloat actualScaleFactor, actualTrackingAdjustment;
@property (nonatomic, readonly) NSRect totalBounds;
@end
@interface NSString (WsbsdDrawingContext)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(NSStringDrawingContext *)context;
@end
@interface NSAttributedString (WsbsdDrawingContext)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSStringDrawingOptions)options context:(NSStringDrawingContext *)context;
@end
@interface NSWorkspace (WsbsdFileViewer)
- (void)activateFileViewerSelectingURLs:(NSArray *)fileURLs;
@end
#import <AppKit/NSTitlebarAccessoryViewController.h>   /* the class is GNUstep's */
@interface NSWindow (WsbsdTitlebarAccessories)
@property (nonatomic, readonly, copy) NSArray *titlebarAccessoryViewControllers;
- (void)addTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController *)childViewController;
- (void)insertTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController *)childViewController atIndex:(NSInteger)index;
- (void)removeTitlebarAccessoryViewControllerAtIndex:(NSInteger)index;
@end

/* more names (TextMate build) */
#ifndef NSVisualEffectMaterialHeaderView
#define NSVisualEffectMaterialHeaderView ((NSVisualEffectMaterial)10)
#define NSVisualEffectMaterialToolTip ((NSVisualEffectMaterial)17)
#endif
NSValue *NSAccessibilityFrameInView(NSView *parentView, NSRect frame);
extern NSString *const NSImageNameApplicationIcon;
extern NSString *const NSProgressFileOperationKindKey, *const NSProgressFileOperationKindDownloading, *const NSProgressFileOperationKindCopying;
@interface NSView (WsbsdFitting)
@property (nonatomic, readonly) NSSize fittingSize;
- (void)updateTrackingAreas;
@end
@interface NSResponder (WsbsdRestoration)
- (void)invalidateRestorableState;
@end
#define O_EVTONLY O_RDONLY

/* Foundation / AppKit odds and ends (TextMate build) */
#ifndef NSEventMaskMouseEntered
#define NSEventMaskMouseEntered (1ULL << NSEventTypeMouseEntered)
#define NSEventMaskMouseExited (1ULL << NSEventTypeMouseExited)
#endif
typedef uint16_t CGKeyCode;
enum { NSFileManagerItemReplacementUsingNewMetadataOnly = 1 << 0, NSFileManagerItemReplacementWithoutDeletingBackupItem = 1 << 1 };
typedef NSUInteger NSFileManagerItemReplacementOptions;
@interface NSIndexSet (WsbsdTests)
- (NSIndexSet *)indexesPassingTest:(BOOL (^)(NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)opts passingTest:(BOOL (^)(NSUInteger idx, BOOL *stop))predicate;
@end
@interface NSFileManager (WsbsdReplace)
- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)replaceItemAtURL:(NSURL *)originalItemURL withItemAtURL:(NSURL *)newItemURL backupItemName:(NSString *)backupItemName options:(NSFileManagerItemReplacementOptions)options resultingItemURL:(NSURL **)resultingURL error:(NSError **)error;
@end
@interface NSUserDefaults (WsbsdSuite)
- (instancetype)initWithSuiteName:(NSString *)suitename;
@end
@interface NSApplication (WsbsdHelpMenu)
@property (nonatomic, strong) NSMenu *helpMenu;
@property (nonatomic, readonly, strong) NSAppearance *effectiveAppearance;
@end
@interface NSMenu (WsbsdFont)
@property (nonatomic, strong) NSFont *font;
@end
typedef NS_ENUM(NSInteger, NSWindowAnimationBehavior) { NSWindowAnimationBehaviorDefault = 0, NSWindowAnimationBehaviorNone = 2, NSWindowAnimationBehaviorDocumentWindow = 3, NSWindowAnimationBehaviorUtilityWindow = 4, NSWindowAnimationBehaviorAlertPanel = 5 };
@interface NSWindow (WsbsdAnimationBehavior)
@property (nonatomic) NSWindowAnimationBehavior animationBehavior;
@end
@interface NSTableView (WsbsdGroupRows)
@property (nonatomic) BOOL floatsGroupRows;
@end
@interface NSOutlineView (WsbsdItemAnimation)
- (void)insertItemsAtIndexes:(NSIndexSet *)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions;
- (void)removeItemsAtIndexes:(NSIndexSet *)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)animationOptions;
- (void)moveItemAtIndex:(NSInteger)fromIndex inParent:(id)oldParent toIndex:(NSInteger)toIndex inParent:(id)newParent;
@end

@protocol NSSearchFieldDelegate <NSTextFieldDelegate> @optional
- (void)searchFieldDidStartSearching:(NSSearchField *)sender;
- (void)searchFieldDidEndSearching:(NSSearchField *)sender;
@end
@protocol NSTouchBarDelegate <NSObject> @end
@interface NSTitlebarAccessoryViewController (WsbsdHidden)
@property (nonatomic, getter=isHidden) BOOL hidden;
@end
@interface NSFileManager (WsbsdLinks)
- (BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)destURL error:(NSError **)error;
- (BOOL)getRelationship:(NSInteger *)outRelationship ofDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domainMask toItemAtURL:(NSURL *)url error:(NSError **)error;
@end
#endif
