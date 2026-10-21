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
#endif
