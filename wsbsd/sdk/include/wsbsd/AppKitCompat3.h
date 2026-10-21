/* More of the modern AppKit / Foundation surface that applications name: declarations of what the back-end already implements without a header (tracking areas, intrinsic size), the Apple event classes
 * GNUstep ships as empty shells, touch bar properties, accessibility element properties, and small additions. Implemented in sdk/src/AppKitCompat3.m, always as categories (the classes themselves are GNUstep's). */
#ifndef WSBSD_APPKITCOMPAT3_H
#define WSBSD_APPKITCOMPAT3_H
#import <AppKit/AppKit.h>
#include <wsbsd/CGEvent.h>
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
@interface NSObject (WsbsdAccessibility)
- (NSArray *)accessibilityAttributeNames;
- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute;
- (void)accessibilitySetValue:(id)value forAttribute:(NSString *)attribute;
@property (nonatomic, strong) id accessibilityTitleUIElement;
@property (nonatomic, copy) NSArray *accessibilitySharedFocusElements;
@end

/* touch bar: the objects exist and keep what is set on them, nothing is shown */
extern NSString *const NSTouchBarItemIdentifierOtherItemsProxy, *const NSTouchBarItemIdentifierFlexibleSpace, *const NSTouchBarItemIdentifierFixedSpaceSmall, *const NSImageNameTouchBarGoBackTemplate, *const NSImageNameTouchBarGoForwardTemplate;
@interface NSTouchBar (WsbsdCompat3)
@property (assign) id delegate;
@property (copy) NSArray *defaultItemIdentifiers, *customizationAllowedItemIdentifiers;
@property (copy) NSString *customizationIdentifier;
@end
@interface NSTouchBarItem (WsbsdCompat3)
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (readonly, copy) NSString *identifier;
@end
@interface NSCustomTouchBarItem (WsbsdCompat3)
@property (strong) NSView *view;
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
/* the C++ view of NS_OPTIONS-less enums: `a | b` stays the enum type */
#ifdef __cplusplus
inline NSTableViewAnimationOptions operator|(NSTableViewAnimationOptions a, NSTableViewAnimationOptions b) { return (NSTableViewAnimationOptions)((int)a | (int)b); }
#endif

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
