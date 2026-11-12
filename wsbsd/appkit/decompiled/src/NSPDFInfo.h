/*
 * NSPDFInfo.h — 1:1 reimplementation (behavioral core) of AppKit's NSPDFInfo,
 * the value object describing a PDF export (used by NSPDFPanel / Export-as-PDF).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPDFInfo_interface.txt. Real ivars: _URL, _tagNames,
 * _orientation, _paperSize, _attributes, _fileExtensionHidden. Conforms to
 * NSCopying + NSCoding.
 *
 * Measured defaults: URL=nil, tagNames=@[], orientation=Portrait(0),
 * paperSize={595,842} (A4 pts), isFileExtensionHidden=YES, attributes={}
 * (mutable, exposed readonly). -copy yields a distinct object whose attributes
 * is an independent mutable dictionary.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSPaperOrientation) {
    NSPaperOrientationPortrait = 0,
    NSPaperOrientationLandscape = 1,
};

@interface NSPDFInfo : NSObject <NSCopying, NSCoding>

@property (nullable, copy) NSURL *URL;
@property (getter=isFileExtensionHidden) BOOL fileExtensionHidden;
@property (copy) NSArray<NSString *> *tagNames;
@property NSPaperOrientation orientation;
@property CGSize paperSize;
@property (readonly, strong) NSMutableDictionary *attributes;

@end

NS_ASSUME_NONNULL_END
