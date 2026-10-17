/* Names and methods AppKit gained after OpenStep that unmodified Mac sources use; implemented in sdk/src/AppKitCompat.m. Constants are macros so that a GNUstep
 * that already has them (an enum) is not redeclared. */
#ifndef WSBSD_APPKIT_COMPAT_H
#define WSBSD_APPKIT_COMPAT_H
#import <Foundation/Foundation.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSButtonCell.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSSegmentedControl.h>
#import <AppKit/NSDocument.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSAlert.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSImageCell.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSView.h>
#import <AppKit/NSImage.h>
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
