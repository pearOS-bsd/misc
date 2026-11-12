/*
 * NSPDFImageRep.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPDFImageRep, an NSImageRep backed by PDF data.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPDFImageRep_interface.txt. Real ivars: _pdfData,
 * _private (_NSPDFDocument).
 *
 * This core reproduces the page model by parsing the data with CoreGraphics'
 * CGPDFDocument (the same system parser AppKit uses): pageCount, currentPage
 * (0-based, settable), bounds = the current page's media box, size = bounds.size,
 * PDFRepresentation = the input data. +canInitWithData: recognises the %PDF
 * signature. Invalid data yields a non-nil rep with pageCount 0 and zero size
 * (measured). Actual rasterising in -draw is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSImageRep.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPDFImageRep : NSImageRep

+ (nullable instancetype)imageRepWithData:(NSData *)pdfData;
- (nullable instancetype)initWithData:(NSData *)pdfData;
+ (BOOL)canInitWithData:(NSData *)data;

@property (readonly, copy) NSData *PDFRepresentation;
@property (readonly) CGRect bounds;
@property NSInteger currentPage;
@property (readonly) NSInteger pageCount;

@end

NS_ASSUME_NONNULL_END
