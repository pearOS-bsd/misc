/*
 * NSPrinter.h — 1:1 reimplementation (behavioral core) of AppKit's NSPrinter,
 * the object describing a print device.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPrinter_interface.txt.
 *
 * This core builds an NSPrinter from a name (and type), exposing name/type/
 * languageLevel/deviceDescription, with NSCopying/NSSecureCoding. The installed-
 * printer registry (+printerNames / +printerTypes) and the PPD-driven metadata
 * (pageSizeForPaper:, imageRectForPaper:, statusForTable:) are backed by CUPS =
 * TODO(stage2); +printerNames is empty here and +printerWithName: constructs a
 * printer for the BSD port (on stock macOS it returns nil for an unknown name).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSPrinter : NSObject <NSSecureCoding, NSCopying>

@property (class, readonly, copy) NSArray<NSString *> *printerNames;
@property (class, readonly, copy) NSArray<NSString *> *printerTypes;
+ (nullable NSPrinter *)printerWithName:(NSString *)name;
+ (nullable NSPrinter *)printerWithType:(NSString *)type;

@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *type;
@property (readonly) NSInteger languageLevel;
@property (readonly, copy) NSDictionary *deviceDescription;

- (CGSize)pageSizeForPaper:(NSString *)paperName;

@end

NS_ASSUME_NONNULL_END
