/*
 * NSPrintInfo.h — 1:1 reimplementation (core). NSObject <NSSecureCoding, NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSPrintInfo : NSObject <NSSecureCoding, NSCopying, NSCoding> {
 *       @"NSMutableDictionary" _attributes;  @ _moreVars;
 *   }
 *   +sharedPrintInfo +setSharedPrintInfo: -initWithDictionary: -dictionary
 *   -paperName -paperSize -orientation -scalingFactor -leftMargin/right/top/bottom
 *   -isHorizontallyCentered …
 *
 * All settings live in the attributes dictionary (the `_attributes` ivar) keyed
 * by the NSPrint* keys; the accessors read/write it. Defaults are US Letter,
 * portrait, 1.0 scaling, 1-inch margins, centered. The actual print operation /
 * PMPrintSettings bridge is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSPaperOrientation) {
    NSPaperOrientationPortrait = 0,
    NSPaperOrientationLandscape = 1,
};

@interface NSPrintInfo : NSObject <NSCopying>

- (instancetype)initWithDictionary:(nullable NSDictionary<NSString *, id> *)attributes;
@property (readonly, strong) NSMutableDictionary<NSString *, id> *dictionary;

@property (class, strong) NSPrintInfo *sharedPrintInfo;

@property (copy) NSString *paperName;
@property CGSize paperSize;
@property NSPaperOrientation orientation;
@property CGFloat scalingFactor;
@property CGFloat leftMargin;
@property CGFloat rightMargin;
@property CGFloat topMargin;
@property CGFloat bottomMargin;
@property (getter=isHorizontallyCentered) BOOL horizontallyCentered;
@property (getter=isVerticallyCentered) BOOL verticallyCentered;

@end

NS_ASSUME_NONNULL_END
