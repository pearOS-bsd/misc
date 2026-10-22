/* More of the modern AppKit / Foundation surface that applications name: declarations of what the back-end already implements without a header (tracking areas, intrinsic size), the Apple event classes
 * GNUstep ships as empty shells, touch bar properties, accessibility element properties, and small additions. Implemented in sdk/src/AppKitCompat3.m, always as categories (the classes themselves are GNUstep's). */
#ifndef WSBSD_APPKITCOMPAT3_H
#define WSBSD_APPKITCOMPAT3_H
#import <AppKit/AppKit.h>
#include <wsbsd/CGEvent.h>
@class NSDraggingItem;
#ifdef __cplusplus
extern "C" {
#endif
CGPathRef CGPathCreateWithRoundedRect(CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight, const CGAffineTransform *transform);
#ifdef __cplusplus
}
#endif
#ifndef NSEventMaskOtherMouseDown
#define NSEventMaskOtherMouseDown NSOtherMouseDownMask
#define NSEventMaskOtherMouseUp NSOtherMouseUpMask
#define NSEventMaskOtherMouseDragged NSOtherMouseDraggedMask
#define NSEventMaskMouseEntered NSMouseEnteredMask
#define NSEventMaskMouseExited NSMouseExitedMask
#define NSEventMaskCursorUpdate NSCursorUpdateMask
#endif
typedef struct { NSInteger majorVersion, minorVersion, patchVersion; } NSOperatingSystemVersion;
@interface NSProcessInfo (WsbsdVersion)
@property (readonly) NSOperatingSystemVersion operatingSystemVersion;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;
@end

/* views */
@interface NSView (WsbsdCompat3)
@property (readonly, copy) NSArray *trackingAreas;
- (void)addTrackingArea:(NSTrackingArea *)trackingArea;
- (void)removeTrackingArea:(NSTrackingArea *)trackingArea;
- (void)updateTrackingAreas;
- (void)invalidateIntrinsicContentSize;
- (NSArray *)constraints;
@property (nonatomic) NSRect frame, bounds;
@property (nonatomic, copy) NSString *identifier;
@end
@interface NSMenuItem (WsbsdCompat3)
@property (nonatomic, readonly) NSMenuItem *parentItem;
@property (nonatomic, strong) NSView *view;
@property (nonatomic) BOOL allowsKeyEquivalentWhenHidden;
@property (nonatomic) SEL action;
@end
@interface NSMenu (WsbsdCompat3)
- (void)cancelTracking;
@end
@interface NSValue (WsbsdProperties)
@property (readonly) NSRange rangeValue;
@property (readonly) NSPoint pointValue;
@property (readonly) NSSize sizeValue;
@property (readonly) NSRect rectValue;
@end
@interface NSURL (WsbsdCompat3)
@property (readonly, copy) NSURL *filePathURL;
- (BOOL)setResourceValue:(id)value forKey:(NSString *)key error:(NSError **)error;
- (void)setTemporaryResourceValue:(id)value forKey:(NSString *)key;
@end
extern NSString *const NSURLTagNamesKey;
typedef NS_ENUM(NSInteger, NSURLRelationship) { NSURLRelationshipContains = 0, NSURLRelationshipSame = 1, NSURLRelationshipOther = 2 };
@interface NSFileManager (WsbsdCompat3)
@property (readonly, copy) NSURL *homeDirectoryForCurrentUser;
- (BOOL)getRelationship:(NSURLRelationship *)outRelationship ofDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domainMask toItemAtURL:(NSURL *)url error:(NSError **)error;
- (NSArray *)mountedVolumeURLsIncludingResourceValuesForKeys:(NSArray *)propertyKeys options:(NSUInteger)options;
@end
enum { NSVolumeEnumerationSkipHiddenVolumes = 1 << 1, NSVolumeEnumerationProduceFileReferenceURLs = 1 << 2 };
@interface NSKeyedArchiver (WsbsdCompat3)
@property (readonly, strong) NSMutableData *encodedData;
@end
@interface NSBundle (WsbsdCompat3)
- (NSImage *)imageForResource:(NSString *)name;
@end
@interface NSImage (WsbsdLayers)
- (id)layerContentsForContentsScale:(CGFloat)layerContentsScale;
@end
@interface NSMutableParagraphStyle (WsbsdCompat3)
@property BOOL allowsDefaultTighteningForTruncation;
@end

/* window and application */
typedef NS_ENUM(NSInteger, NSWindowToolbarStyle) { NSWindowToolbarStyleAutomatic = 0, NSWindowToolbarStyleExpanded, NSWindowToolbarStylePreference, NSWindowToolbarStyleUnified, NSWindowToolbarStyleUnifiedCompact };
@interface NSWindow (WsbsdCompat3)
@property (class) BOOL allowsAutomaticWindowTabbing;
@property NSWindowToolbarStyle toolbarStyle;
@property (readonly, getter=isOnActiveSpace) BOOL onActiveSpace;
@end
@interface NSApplication (WsbsdCompat3)
@property BOOL automaticCustomizeTouchBarMenuItemEnabled;
@property (readonly, getter=isFullKeyboardAccessEnabled) BOOL fullKeyboardAccessEnabled;
@end
@interface NSWorkspace (WsbsdCompat3)
@property (readonly, getter=isVoiceOverEnabled) BOOL voiceOverEnabled;
@end
extern NSString *const NSApplicationLaunchUserNotificationKey, *const NSAnimateBinding, *const NSDocumentEditedBinding;
@interface NSSpellChecker (WsbsdCompat3)
@property (readonly, copy) NSArray *availableLanguages;
@property BOOL automaticallyIdentifiesLanguages;
@end
@interface NSHelpManager (WsbsdCompat3)
- (void)openHelpAnchor:(NSString *)anchor inBook:(NSString *)book;
@end
@interface NSTitlebarAccessoryViewController (WsbsdCompat3)
@property CGFloat fullScreenMinHeight;
@end
@interface NSTableView (WsbsdCompat3)
- (void)enumerateAvailableRowViewsUsingBlock:(void (^)(NSTableRowView *rowView, NSInteger row))handler;
@end
@interface NSLayoutConstraint (WsbsdAnimator)
- (instancetype)animator;
@end
@interface NSBrowser (WsbsdCompat3)
@property CGFloat defaultColumnWidth;
@end
@interface NSViewController (WsbsdRestoration)
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder;
- (void)restoreStateWithCoder:(NSCoder *)coder;
@end

/* accessibility */
typedef NSString *NSAccessibilityRole, *NSAccessibilitySubrole, *NSAccessibilityAttributeName, *NSAccessibilityParameterizedAttributeName, *NSAccessibilityActionName, *NSAccessibilityNotificationName, *NSAccessibilityOrientationValue;
@interface NSObject (WsbsdAccessibility)
- (NSArray *)accessibilityAttributeNames;
- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute;
- (void)accessibilitySetValue:(id)value forAttribute:(NSString *)attribute;
- (NSUInteger)accessibilityArrayAttributeCount:(NSString *)attribute;
- (NSArray *)accessibilityArrayAttributeValues:(NSString *)attribute index:(NSUInteger)index maxCount:(NSUInteger)maxCount;
- (NSUInteger)accessibilityIndexOfChild:(id)child;
@property (nonatomic, strong) id accessibilityTitleUIElement;
@property (nonatomic, copy) NSArray *accessibilitySharedFocusElements;
@end

#import <wsbsd/TouchBar.h>
@interface NSString (WsbsdLocalizedStandard)
- (NSComparisonResult)localizedStandardCompare:(NSString *)other;
- (BOOL)localizedStandardContainsString:(NSString *)s;
@end
@interface NSCalendar (WsbsdRelativeDays)
- (BOOL)isDateInToday:(NSDate *)d; - (BOOL)isDateInYesterday:(NSDate *)d; - (BOOL)isDateInTomorrow:(NSDate *)d;
@end
extern NSString *const NSImageNameTouchBarGoBackTemplate, *const NSImageNameTouchBarGoForwardTemplate;
extern NSString *const NSImageNameTouchBarSearchTemplate, *const NSImageNameTouchBarBookmarksTemplate, *const NSImageNameTouchBarAddTemplate, *const NSImageNameTouchBarRefreshTemplate, *const NSImageNameTouchBarSidebarTemplate;
@interface NSView (WsbsdInput)
@property (readonly, strong) NSTextInputContext *inputContext;
- (BOOL)isInFullScreenMode;
@end
#include <CoreServices/AppleEvents.h>
@interface NSAppleEventDescriptor (WsbsdAEDesc)
- (const AEDesc *)aeDesc;
@end
@interface NSDraggingSessionItemsHelper : NSObject
@end
@interface NSObject (WsbsdDraggingInfo)
@property BOOL animatesToDestination;
- (void)enumerateDraggingItemsWithOptions:(NSUInteger)enumOpts forView:(id)view classes:(NSArray *)classArray searchOptions:(NSDictionary *)searchOptions usingBlock:(void (^)(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop))block;
@end
@interface NSSpellChecker (WsbsdLearn)
- (void)learnWord:(NSString *)word;
- (void)unlearnWord:(NSString *)word;
@end
@interface NSURLProtocol (WsbsdProperties)
+ (void)removePropertyForKey:(NSString *)key inRequest:(NSMutableURLRequest *)request;
@end

/* Apple events as objects (GNUstep's NSAppleEventDescriptor and NSAppleEventManager are empty shells): in-memory descriptors, and handlers registered for event class / id that -dispatch calls */
@interface NSAppleEventDescriptor (WsbsdAE)
+ (NSAppleEventDescriptor *)nullDescriptor;
+ (NSAppleEventDescriptor *)descriptorWithBoolean:(BOOL)boolean;
+ (NSAppleEventDescriptor *)descriptorWithInt32:(int32_t)signedInt;
+ (NSAppleEventDescriptor *)descriptorWithString:(NSString *)string;
+ (NSAppleEventDescriptor *)descriptorWithEnumCode:(uint32_t)enumerator;
+ (NSAppleEventDescriptor *)descriptorWithTypeCode:(uint32_t)typeCode;
+ (NSAppleEventDescriptor *)descriptorWithDescriptorType:(uint32_t)descriptorType data:(NSData *)data;
+ (NSAppleEventDescriptor *)descriptorWithDescriptorType:(uint32_t)descriptorType bytes:(const void *)bytes length:(NSUInteger)byteCount;
+ (NSAppleEventDescriptor *)descriptorWithProcessIdentifier:(pid_t)processIdentifier;
+ (NSAppleEventDescriptor *)descriptorWithBundleIdentifier:(NSString *)bundleIdentifier;
+ (NSAppleEventDescriptor *)listDescriptor;
+ (NSAppleEventDescriptor *)recordDescriptor;
+ (NSAppleEventDescriptor *)appleEventWithEventClass:(uint32_t)eventClass eventID:(uint32_t)eventID targetDescriptor:(NSAppleEventDescriptor *)targetDescriptor returnID:(int16_t)returnID transactionID:(int32_t)transactionID;
@property (readonly) uint32_t descriptorType;
@property (readonly, copy) NSData *data;
@property (readonly) BOOL booleanValue;
@property (readonly) int32_t int32Value;
@property (readonly, copy) NSString *stringValue;
@property (readonly) uint32_t enumCodeValue, typeCodeValue;
@property (readonly) NSInteger numberOfItems;
@property (readonly) uint32_t eventClass, eventID;
@property (readonly) int16_t returnID;
@property (readonly) int32_t transactionID;
- (void)insertDescriptor:(NSAppleEventDescriptor *)descriptor atIndex:(NSInteger)index;
- (NSAppleEventDescriptor *)descriptorAtIndex:(NSInteger)index;
- (void)removeDescriptorAtIndex:(NSInteger)index;
- (void)setDescriptor:(NSAppleEventDescriptor *)descriptor forKeyword:(uint32_t)keyword;
- (NSAppleEventDescriptor *)descriptorForKeyword:(uint32_t)keyword;
- (void)removeDescriptorWithKeyword:(uint32_t)keyword;
- (uint32_t)keywordForDescriptorAtIndex:(NSInteger)index;
- (void)setParamDescriptor:(NSAppleEventDescriptor *)descriptor forKeyword:(uint32_t)keyword;
- (NSAppleEventDescriptor *)paramDescriptorForKeyword:(uint32_t)keyword;
- (void)removeParamDescriptorWithKeyword:(uint32_t)keyword;
- (void)setAttributeDescriptor:(NSAppleEventDescriptor *)descriptor forKeyword:(uint32_t)keyword;
- (NSAppleEventDescriptor *)attributeDescriptorForKeyword:(uint32_t)keyword;
- (NSAppleEventDescriptor *)coerceToDescriptorType:(uint32_t)descriptorType;
@end
@interface NSAppleEventManager (WsbsdAE)
@property (class, readonly) NSAppleEventManager *sharedAppleEventManager;
+ (NSAppleEventManager *)sharedAppleEventManager;
- (void)setEventHandler:(id)handler andSelector:(SEL)handleEventSelector forEventClass:(uint32_t)eventClass andEventID:(uint32_t)eventID;
- (void)removeEventHandlerForEventClass:(uint32_t)eventClass andEventID:(uint32_t)eventID;
- (NSInteger)dispatchEvent:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)reply;       /* 0 when a handler ran, errAEEventNotHandled otherwise */
@property (readonly, retain) NSAppleEventDescriptor *currentAppleEvent, *currentReplyAppleEvent;
@end
@interface NSScriptCommand (WsbsdAE)
@property (copy) id directParameter;
@end
extern NSString *const NSWorkspaceLaunchConfigurationAppleEvent;
@interface NSRelativeDateTimeFormatter : NSFormatter
@property NSInteger dateTimeStyle, unitsStyle, formattingContext;
- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)referenceDate;
@end
/* the is-getters GNUstep declares as methods only: Apple declares @property (getter=isX), and `view.hidden` needs the declaration */
@interface NSView (WsbsdProps)
@property (getter=isHidden) BOOL hidden;
@end
@interface NSText (WsbsdProps)
@property (getter=isEditable) BOOL editable;
@property (getter=isSelectable) BOOL selectable;
@property (getter=isRichText) BOOL richText;
@property (getter=isFieldEditor) BOOL fieldEditor;
@end
@interface NSControl (WsbsdProps)
@property (getter=isEnabled) BOOL enabled;
@end
@interface NSCell (WsbsdProps)
@property (getter=isEnabled) BOOL enabled;
@property (getter=isEditable) BOOL editable;
@property (getter=isSelectable) BOOL selectable;
@property (getter=isBordered) BOOL bordered;
@property (getter=isScrollable) BOOL scrollable;
@property (getter=isHighlighted) BOOL highlighted;
@end
@interface NSWindow (WsbsdProps)
@property (getter=isVisible) BOOL visible;
@property (getter=isOpaque) BOOL opaque;
@property (readonly, getter=isKeyWindow) BOOL keyWindow;
@property (readonly, getter=isMainWindow) BOOL mainWindow;
@property (readonly, getter=isMiniaturized) BOOL miniaturized;
@property (getter=isZoomed) BOOL zoomed;
@property (getter=isDocumentEdited) BOOL documentEdited;
@property (strong) NSButtonCell *defaultButtonCell;
@end
@interface NSMenuItem (WsbsdProps)
@property (getter=isEnabled) BOOL enabled;
@property (getter=isHidden) BOOL hidden;
@property (readonly, getter=isSeparatorItem) BOOL separatorItem;
@end
@interface NSApplication (WsbsdProps)
@property (readonly, getter=isActive) BOOL active;
@property (readonly, getter=isRunning) BOOL running;
@property (readonly, getter=isHidden) BOOL hidden;
@end
/* Foundation additions */
@interface NSProgress (WsbsdCompat3)
- (void)setLocalizedDescription:(NSString *)description;
- (void)setLocalizedAdditionalDescription:(NSString *)description;
@end
extern NSString *const NSProgressKindFile, *const NSProgressEstimatedTimeRemainingKey, *const NSProgressThroughputKey;
@interface NSTask (WsbsdTermination)
@property (copy) void (^terminationHandler)(NSTask *task);
@end
@interface NSStackView (WsbsdCompat3)
@property (readonly, copy) NSArray *views;
@end
@interface NSGridRow (WsbsdCompat3)
@property NSGridRowAlignment rowAlignment;
@end
@interface NSViewController (WsbsdChildren)
- (void)addChildViewController:(NSViewController *)childViewController;
- (void)removeFromParentViewController;
@property (readonly, copy) NSArray<NSViewController *> *childViewControllers;
@property (nonatomic, copy) NSString *identifier;
@end
@interface NSSplitViewItem (WsbsdCompat3)
- (void)setCanCollapse:(BOOL)flag;
- (void)setHoldingPriority:(float)priority;
@end
@protocol NSTextStorageDelegate <NSObject>
@optional
- (void)textStorage:(NSTextStorage *)textStorage willProcessEditing:(NSUInteger)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSUInteger)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
@end
@interface NSURL (WsbsdPasteboardWriting) <NSPasteboardWriting>
@end
@interface NSView (WsbsdDragSource)
- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation;
- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint;
@end
@interface NSSpellChecker (WsbsdCompat4)
- (BOOL)hasLearnedWord:(NSString *)word;
- (NSArray *)guessesForWordRange:(NSRange)range inString:(NSString *)string language:(NSString *)language inSpellDocumentWithTag:(NSInteger)tag;
@end
typedef NSString *NSURLFileResourceType;

@interface NSAccessibilityCustomRotorItemResult (WsbsdSetters)
@property NSRange targetRange;
@property (copy) NSString *customLabel;
@end
@interface NSAccessibilityCustomRotorSearchParameters : NSObject
@property (strong) NSAccessibilityCustomRotorItemResult *currentItem;
@property NSInteger searchDirection;
@property (copy) NSString *filterString;
@end
extern NSString *const NSImageNameTouchBarGoUpTemplate, *const NSImageNameTouchBarGoDownTemplate, *const NSImageNameStopProgressFreestandingTemplate, *const NSImageNameStopProgressTemplate, *const NSImageNameRefreshFreestandingTemplate;
@interface NSWindow (WsbsdFullScreen)
- (void)toggleFullScreen:(id)sender;
@end
@interface NSAlert (WsbsdLayout)
- (void)layout;
@end
@interface NSEvent (WsbsdForce)
@property (readonly) NSInteger stage;
@property (readonly) CGFloat stageTransition;
@end
@interface NSView (WsbsdDefinition)
- (void)showDefinitionForAttributedString:(NSAttributedString *)attrString atPoint:(NSPoint)textBaselineOrigin;
@end
@interface NSDraggingItem : NSObject
@property (readonly, retain) id item;
@property NSRect draggingFrame;
@property (copy) NSArray *(^imageComponentsProvider)(void);
@property (readonly, copy) NSArray *imageComponents;
- (instancetype)initWithPasteboardWriter:(id)pasteboardWriter;
- (void)setDraggingFrame:(NSRect)frame contents:(id)contents;
@end
/* drag sessions of the modern API (the sources keep the classic dragImage:... calls underneath) */
@interface NSDraggingSession : NSObject
@property (readonly) NSPasteboard *draggingPasteboard;
@property (readonly) NSInteger draggingSequenceNumber;
@property NSPoint draggingLocation;
@property BOOL animatesToStartingPositionsOnCancelOrFail;
@end
@interface NSView (WsbsdDraggingSession)
- (NSDraggingSession *)beginDraggingSessionWithItems:(NSArray *)items event:(NSEvent *)event source:(id)source;
@end
@interface NSObject (WsbsdOutlineGroup)
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item;
@end
#endif
