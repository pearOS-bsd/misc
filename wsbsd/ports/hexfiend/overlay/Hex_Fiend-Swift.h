/* What Xcode generates for the Swift part of Hex Fiend's application (Hex_Fiend-Swift.h): the Objective-C interface of the classes written in Swift.
 * Swift cannot subclass NSObject or call AppKit without Objective-C interoperability, which exists only on Apple's platforms, so on FreeBSD these classes are
 * ports of the four Swift files (see ../README.md); the rest of the application is built from the unmodified sources. */
#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

NS_ASSUME_NONNULL_BEGIN

/* Encodings.swift */
@interface Encodings : NSObject
@property (nonatomic, copy) NSArray<NSNumber *> *menuSystemEncodingsNumbers;
- (NSArray<HFNSStringEncoding *> *)menuSystemEncodings;
- (void)showEncodingsWindow;
- (void)reloadEncodingsWindowIfLoaded;
@end

/* ChooseStringEncodingWindowController.swift */
@interface ChooseStringEncodingWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>
- (void)reload;
@end

/* ScrollViewRepresenter.swift */
@interface ScrollViewRepresenter : HFRepresenter
@end

/* HFByteTheme.swift (an extension of the framework's class) */
@interface HFByteTheme (HFByteThemeFromURL)
+ (nullable instancetype)fromUrl:(NSURL *)url;
@end

NS_ASSUME_NONNULL_END
