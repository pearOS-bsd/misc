/* Names and methods AppKit gained after OpenStep that unmodified Mac sources use; implemented in sdk/src/AppKitCompat.m. Constants are macros so that a GNUstep
 * that already has them (an enum) is not redeclared. */
#ifndef WSBSD_APPKIT_COMPAT_H
#define WSBSD_APPKIT_COMPAT_H
#import <Foundation/Foundation.h>
#if defined(__has_include)
#if __has_include(<CoreServices/CoreServices.h>)
#import <CoreServices/CoreServices.h>
#endif
#endif
#import <AppKit/NSButton.h>
#import <AppKit/NSButtonCell.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSSegmentedControl.h>
#import <AppKit/NSDocument.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSAlert.h>
#import <AppKit/NSSearchField.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSImageCell.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSOpenPanel.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSView.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSWindowController.h>
#import <AppKit/NSDocumentController.h>
#import <AppKit/NSToolbar.h>
#import <AppKit/NSAlert.h>
#import <AppKit/NSSearchField.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSFontPanel.h>
#import <AppKit/NSGestureRecognizer.h>
#import <AppKit/NSClickGestureRecognizer.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSTextStorage.h>
#import <AppKit/NSGraphics.h>

#if defined(__has_include)
#if __has_include(<CoreGraphics/CoreGraphics.h>)
#import <CoreGraphics/CoreGraphics.h>
#endif
#endif
#if defined(__has_include)
#if __has_include(<CoreFoundation/CFCGTypes.h>)
#import <CoreFoundation/CFCGTypes.h>      /* CGRectEdge and the CG geometry types of newer GNUstep base */
#endif
#endif
/* the constants Opal defines but a stack without it lacks: declared the way Opal does (a repeated extern const is fine), defined weakly in AppKitCompat.m */
extern const CGRect CGRectZero;
extern const CGSize CGSizeZero;
extern const CGPoint CGPointZero;
extern const CGRect CGRectNull;
extern const CGAffineTransform CGAffineTransformIdentity;
#if defined(__has_include)
#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>             /* Apple's Cocoa umbrella reaches CoreText through ApplicationServices */
#endif
#endif
#ifndef NSEventMaskAny
#define NSEventMaskLeftMouseDown NSLeftMouseDownMask
#define NSEventMaskLeftMouseUp NSLeftMouseUpMask
#define NSEventMaskRightMouseDown NSRightMouseDownMask
#define NSEventMaskRightMouseUp NSRightMouseUpMask
#define NSEventMaskMouseMoved NSMouseMovedMask
#define NSEventMaskLeftMouseDragged NSLeftMouseDraggedMask
#define NSEventMaskRightMouseDragged NSRightMouseDraggedMask
#define NSEventMaskKeyDown NSKeyDownMask
#define NSEventMaskKeyUp NSKeyUpMask
#define NSEventMaskFlagsChanged NSFlagsChangedMask
#define NSEventMaskScrollWheel NSScrollWheelMask
#define NSEventMaskPeriodic NSPeriodicMask
#define NSEventMaskAny NSAnyEventMask
#endif
#ifndef NSPasteboardNameGeneral
#define NSPasteboardNameGeneral NSGeneralPboard
#define NSPasteboardNameFind NSFindPboard
#define NSPasteboardNameDrag NSDragPboard
#define NSPasteboardNameFont NSFontPboard
#define NSPasteboardNameRuler NSRulerPboard
#endif
#ifndef NSBezelStyleRounded
#define NSBezelStyleRounded 1
#define NSBezelStyleRegularSquare 2
#define NSBezelStyleShadowlessSquare 6
#define NSBezelStyleCircular 7
#define NSBezelStyleTexturedSquare 8
#define NSBezelStyleHelpButton 9
#define NSBezelStyleSmallSquare 10
#define NSBezelStyleTexturedRounded 11
#define NSBezelStyleRoundRect 12
#define NSBezelStyleRecessed 13
#define NSBezelStyleRoundedDisclosure 14
#define NSBezelStyleInline 15
#endif
#ifndef NSButtonTypeMomentaryChange
#define NSButtonTypeMomentaryLight 0
#define NSButtonTypePushOnPushOff 1
#define NSButtonTypeToggle 2
#define NSButtonTypeSwitch 3
#define NSButtonTypeRadio 4
#define NSButtonTypeMomentaryChange 5
#define NSButtonTypeOnOff 6
#define NSButtonTypeMomentaryPushIn 7
#define NSButtonTypeAccelerator 8
#define NSButtonTypeMultiLevelAccelerator 9
#endif
#ifndef NSSegmentStyleSeparated
#define NSSegmentStyleSeparated 8
#endif
#ifndef NSCompositingOperationSourceOver
#define NSCompositingOperationClear NSCompositeClear
#define NSCompositingOperationCopy NSCompositeCopy
#define NSCompositingOperationSourceOver NSCompositeSourceOver
#define NSCompositingOperationSourceIn NSCompositeSourceIn
#define NSCompositingOperationSourceOut NSCompositeSourceOut
#define NSCompositingOperationSourceAtop NSCompositeSourceAtop
#define NSCompositingOperationDestinationOver NSCompositeDestinationOver
#define NSCompositingOperationDestinationIn NSCompositeDestinationIn
#define NSCompositingOperationDestinationOut NSCompositeDestinationOut
#define NSCompositingOperationDestinationAtop NSCompositeDestinationAtop
#define NSCompositingOperationXOR NSCompositeXOR
#define NSCompositingOperationPlusDarker NSCompositePlusDarker
#define NSCompositingOperationHighlight NSCompositeHighlight
#define NSCompositingOperationPlusLighter NSCompositePlusLighter
#endif
#if __has_feature(objc_arc)
/* Apple declares the colour arrays const (NSColor *const *); GNUstep's NSColor ** is an __autoreleasing out-parameter to ARC, which refuses a plain array */
#define NSRectFillListWithColors(r, c, n) NSRectFillListWithColors((r), (NSColor *__autoreleasing *)(void *)(c), (n))
#define NSRectFillListWithColorsUsingOperation(r, c, n, op) NSRectFillListWithColorsUsingOperation((r), (NSColor *__autoreleasing *)(void *)(c), (n), (op))
#endif
extern NSString *const NSImageNameStopProgressTemplate;
extern NSString *const NSImageNameRefreshTemplate;
extern NSString *const NSImageNameGoLeftTemplate;
extern NSString *const NSImageNameGoRightTemplate;
extern NSString *const NSImageNameAddTemplate;
extern NSString *const NSImageNameRemoveTemplate;
void memset_pattern4(void *b, const void *pattern, size_t len);
void memset_pattern8(void *b, const void *pattern, size_t len);
void memset_pattern16(void *b, const void *pattern, size_t len);
#ifndef NSRectEdgeMinX
#define NSRectEdgeMinX NSMinXEdge
#define NSRectEdgeMinY NSMinYEdge
#define NSRectEdgeMaxX NSMaxXEdge
#define NSRectEdgeMaxY NSMaxYEdge
#endif
typedef NSUInteger NSFontPanelModeMask;
#ifndef NSFontPanelModeMaskFace
#define NSFontPanelModeMaskFace (1UL << 0)
#define NSFontPanelModeMaskSize (1UL << 1)
#define NSFontPanelModeMaskCollection (1UL << 2)
#define NSFontPanelModeMaskUnderlineEffect (1UL << 8)
#define NSFontPanelModeMaskStrikethroughEffect (1UL << 9)
#define NSFontPanelModeMaskTextColorEffect (1UL << 10)
#define NSFontPanelModeMaskDocumentColorEffect (1UL << 11)
#define NSFontPanelModeMaskShadowEffect (1UL << 12)
#define NSFontPanelModeMaskAllEffects 0xFFF00UL
#define NSFontPanelModeMaskStandardModes 0xFFFFUL
#define NSFontPanelModeMaskAllModes 0xFFFFFFFFUL
#endif
#ifndef NSChangeRedone
#define NSChangeRedone ((NSDocumentChangeType)5)
#endif
#ifndef NSChangeDiscardable
#define NSChangeDiscardable ((NSDocumentChangeType)256)
#endif
extern NSString *const NSPasteboardURLReadingFileURLsOnlyKey;
extern NSString *const NSPasteboardURLReadingContentsConformToTypesKey;
typedef NSUInteger NSAttributedStringEnumerationOptions;
#ifndef NSAttributedStringEnumerationReverse
#define NSAttributedStringEnumerationReverse (1UL << 1)
#define NSAttributedStringEnumerationLongestEffectiveRangeNotRequired (1UL << 20)
#endif

@interface NSView (WsbsdCompat)
@property (nonatomic) BOOL clipsToBounds;
- (NSMenuItem *)enclosingMenuItem;
@end
@interface NSImage (WsbsdCompat)
- (void)lockFocusFlipped:(BOOL)flipped;
@end
@interface NSString (WsbsdCompat)
- (BOOL)localizedCaseInsensitiveContainsString:(NSString *)other;
- (BOOL)getBytes:(void *)buffer maxLength:(NSUInteger)maxBufferCount usedLength:(NSUInteger *)usedBufferCount encoding:(NSStringEncoding)encoding
         options:(NSUInteger)options range:(NSRange)range remainingRange:(NSRangePointer)leftover;
@end
@interface NSWindow (WsbsdCompat)
- (void)setAutorecalculatesContentBorderThickness:(BOOL)flag forEdge:(NSRectEdge)edge;
- (NSArray *)tabbedWindows;
@end
@interface NSDocument (WsbsdViewing)
- (BOOL)isInViewingMode;
@end
@interface NSFileCoordinator (WsbsdCompat)
- (instancetype)initWithFilePresenter:(id)presenter;
@end
@interface NSPasteboard (WsbsdReading)
- (NSArray *)readObjectsForClasses:(NSArray *)classArray options:(NSDictionary *)options;
@end
@interface NSView (WsbsdBacking)
- (NSRect)convertRectFromBacking:(NSRect)r;
- (NSRect)convertRectToBacking:(NSRect)r;
- (NSSize)convertSizeFromBacking:(NSSize)s;
- (NSSize)convertSizeToBacking:(NSSize)s;
@end
/* Mach ports: no Mach IPC here, the classes exist so that code naming them compiles; their ports are always absent */
@interface NSMachPort : NSPort
+ (NSPort *)portWithMachPort:(uint32_t)machPort;
- (instancetype)initWithMachPort:(uint32_t)machPort options:(NSUInteger)f;
- (uint32_t)machPort;
@end
enum { NSMachPortDeallocateNone = 0, NSMachPortDeallocateSendRight = 1, NSMachPortDeallocateReceiveRight = 2 };
@interface NSMachBootstrapServer : NSObject
+ (instancetype)sharedInstance;
- (NSPort *)portForName:(NSString *)name;
- (NSPort *)portForName:(NSString *)name host:(NSString *)host;
@end
@interface NSGestureRecognizer (WsbsdCompat)
- (instancetype)initWithTarget:(id)target action:(SEL)action;
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, weak) NSView *view;
@property (nonatomic) NSInteger state;
@property (nonatomic, weak) id delegate;
@end
@interface NSClickGestureRecognizer (WsbsdCompat)
@property (nonatomic) NSUInteger buttonMask;
@property (nonatomic) NSInteger numberOfClicksRequired;
@end
@interface NSView (WsbsdGestures)
- (void)addGestureRecognizer:(NSGestureRecognizer *)recognizer;
- (void)removeGestureRecognizer:(NSGestureRecognizer *)recognizer;
- (NSArray *)gestureRecognizers;
@end
/* modern property spellings and constants GNUstep lacks */
@protocol NSMenuItemValidation <NSObject>
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
@end
@interface NSString (WsbsdProperties)
@property (readonly, getter=isAbsolutePath) BOOL absolutePath;
@end
@interface NSToolbar (WsbsdProperties)
@property (readonly, getter=isVisible) BOOL visible;
@end
@interface NSScanner (WsbsdProperties)
@property (readonly, getter=isAtEnd) BOOL atEnd;
@end
@interface NSDocumentController (WsbsdClassProperties)
@property (class, readonly, strong) NSDocumentController *sharedDocumentController;
@end
@class NSRunningApplication;
@interface NSWorkspaceOpenConfiguration : NSObject
+ (instancetype)configuration;
@property BOOL activates, addsToRecentItems, promptsUserIfNeeded;
@end
@interface NSWorkspace (WsbsdOpenConfiguration)
- (void)openURLs:(NSArray *)urls withApplicationAtURL:(NSURL *)appURL configuration:(NSWorkspaceOpenConfiguration *)configuration completionHandler:(void (^)(NSRunningApplication *app, NSError *error))handler;
@end
@interface NSDocumentController (WsbsdRecents)
@property (readonly, copy) NSArray *recentDocumentURLs;
@end
@interface NSAlert (WsbsdSuppression)
@property BOOL showsSuppressionButton;
@property (readonly, strong) NSButton *suppressionButton;
@end
enum { NSAlertStyleWarning = 0, NSAlertStyleInformational = 1, NSAlertStyleCritical = 2 };
enum { NSBitmapImageFileTypeTIFF = 0, NSBitmapImageFileTypeBMP, NSBitmapImageFileTypeGIF, NSBitmapImageFileTypeJPEG, NSBitmapImageFileTypePNG, NSBitmapImageFileTypeJPEG2000 };
extern NSPasteboardType const NSPasteboardTypeURL;
enum { NSURLBookmarkCreationWithSecurityScope = 1 << 11, NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess = 1 << 12 };
@interface NSWindow (WsbsdVisible)
@property (readonly, getter=isVisible) BOOL visible;
@end
@protocol NSToolbarItemValidation <NSObject>
- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
@end
@interface NSSearchField (WsbsdSearch)
@property BOOL sendsWholeSearchString;
@property BOOL sendsSearchStringImmediately;
@end
/* bookmarks and security scope: a bookmark is the path (there is no sandbox; resolving it gives the path back) */
@interface NSURL (WsbsdBookmarks)
- (NSData *)bookmarkDataWithOptions:(NSUInteger)options includingResourceValuesForKeys:(NSArray *)keys relativeToURL:(NSURL *)relativeURL error:(NSError **)error;
+ (instancetype)URLByResolvingBookmarkData:(NSData *)bookmarkData options:(NSUInteger)options relativeToURL:(NSURL *)relativeURL bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error;
- (BOOL)startAccessingSecurityScopedResource;
- (void)stopAccessingSecurityScopedResource;
@end
@interface NSMenu (WsbsdMenuName)
- (void)_setMenuName:(NSString *)name;
- (NSString *)_menuName;
@end
@interface NSControl (WsbsdEnabled)
@property (getter=isEnabled) BOOL enabled;
@end
@interface NSWindow (WsbsdStatus)
@property (readonly, getter=isMainWindow) BOOL mainWindow;
@property (readonly, getter=isKeyWindow) BOOL keyWindow;
@property (readonly, getter=isZoomed) BOOL zoomed;
@end
@interface NSTimer (WsbsdTolerance)
@property NSTimeInterval tolerance;
@end
@interface NSView (WsbsdAnimator)
- (instancetype)animator;
+ (id)defaultAnimationForKey:(NSString *)key;
@end
#ifndef NSCompositingOperationColorDodge
#define NSCompositingOperationMultiply 14
#define NSCompositingOperationScreen 15
#define NSCompositingOperationOverlay 16
#define NSCompositingOperationDarken 17
#define NSCompositingOperationLighten 18
#define NSCompositingOperationColorDodge 19
#define NSCompositingOperationColorBurn 20
#define NSCompositingOperationSoftLight 21
#define NSCompositingOperationHardLight 22
#define NSCompositingOperationDifference 23
#define NSCompositingOperationExclusion 24
#endif
@interface NSWindow (WsbsdProperties)
- (BOOL)documentEdited;
- (void)setContentBorderThickness:(CGFloat)thickness forEdge:(NSRectEdge)edge;
/* the window's own appearance (nil: the application's), a transparent title bar and a changeable style mask: kept; the theme draws the title bar the same either way */
@property (nonatomic, strong) id appearance;
@property (nonatomic) BOOL titlebarAppearsTransparent;
@property (nonatomic) NSInteger titleVisibility;
- (void)setStyleMask:(NSUInteger)mask;
@end
@interface NSMenuItem (WsbsdHidden)
- (BOOL)isHidden;
- (void)setHidden:(BOOL)flag;
@end
@interface NSBundle (WsbsdURLs)
- (NSArray *)URLsForResourcesWithExtension:(NSString *)ext subdirectory:(NSString *)subpath;
@end
@interface NSTableView (WsbsdStyle)
@property (nonatomic) NSInteger style;
@end
#ifndef NSTableViewStyleFullWidth
#define NSTableViewStyleAutomatic 0
#define NSTableViewStyleFullWidth 1
#define NSTableViewStyleInset 2
#define NSTableViewStyleSourceList 3
#define NSTableViewStylePlain 4
#endif
@interface NSOpenPanel (WsbsdCompat)
@property (nonatomic) BOOL accessoryViewDisclosed;
@end
@interface NSWindow (WsbsdURL)
@property (nonatomic, copy) NSURL *representedURL;
@end
@interface NSPasteboard (WsbsdWriting)
- (NSInteger)clearContents;
- (BOOL)writeObjects:(NSArray *)objects;
@end
extern NSPasteboardType const NSPasteboardTypeFileURL;
@interface NSScrollView (WsbsdScrolling)
@property (nonatomic) BOOL usesPredominantAxisScrolling;
@end
/* AppleScript: no scripting engine here; compiling and running a script reports an error */
extern NSString *const NSAppleScriptErrorNumber;
extern NSString *const NSAppleScriptErrorMessage;
@interface NSAppleScript (WsbsdCompat)
- (instancetype)initWithSource:(NSString *)source;
- (id)executeAndReturnError:(NSDictionary **)errorInfo;
@end
@interface NSUndoManager (WsbsdCompat)
- (void)setActionIsDiscardable:(BOOL)flag;
@end
@interface NSEvent (WsbsdCompat)
- (BOOL)hasPreciseScrollingDeltas;
- (CGFloat)scrollingDeltaX;
- (CGFloat)scrollingDeltaY;
@end
@interface NSControl (WsbsdCompat)
- (NSControlSize)controlSize;
- (void)setControlSize:(NSControlSize)size;
@end
@interface NSScroller (WsbsdCompat)
+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)size scrollerStyle:(int)style;
@end
@interface NSTextView (WsbsdCompat)
- (void)insertText:(id)string replacementRange:(NSRange)range;
- (BOOL)isAutomaticQuoteSubstitutionEnabled;
- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)flag;
@end
@interface NSButton (WsbsdCompat)
@property (nonatomic) NSImageScaling imageScaling;
@end
@interface NSSegmentedControl (WsbsdCompat)
- (void)setToolTip:(NSString *)tip forSegment:(NSInteger)segment;
- (NSString *)toolTipForSegment:(NSInteger)segment;
- (void)setImageScaling:(NSImageScaling)scaling forSegment:(NSInteger)segment;
- (NSImageScaling)imageScalingForSegment:(NSInteger)segment;
@end
@interface NSDocument (WsbsdCompat)
@property (nonatomic, getter=isDraft) BOOL draft;
@end
@interface NSPasteboard (WsbsdCompat)
- (BOOL)canReadItemWithDataConformingToTypes:(NSArray *)types;
@end
@interface NSAlert (WsbsdCompat)
@property (nonatomic, retain) NSView *accessoryView;
@end
@interface NSColor (WsbsdCompat)
+ (NSColor *)linkColor;
+ (NSColor *)separatorColor;
+ (NSColor *)textInsertionPointColor;
+ (NSColor *)unemphasizedSelectedTextBackgroundColor;
+ (NSArray *)alternatingContentBackgroundColors;
@end
@interface NSAttributedString (WsbsdCompat)
- (void)enumerateAttribute:(NSString *)name inRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block;
- (void)enumerateAttributesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary *attrs, NSRange range, BOOL *stop))block;
@end
@interface NSData (WsbsdCompat)
+ (id)dataWithContentsOfFile:(NSString *)path options:(NSUInteger)options error:(NSError **)error;
- (NSString *)base64Encoding;
@end
#endif
