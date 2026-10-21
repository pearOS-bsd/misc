/* QuickLook: generators (CFPlugIn bundles ".qlgenerator" in /usr/local/share/wsbsd/QuickLook, ~/Library/QuickLook, /Library/QuickLook) produce thumbnails and previews, the system ones (images, text, RTF)
 * are built in; the preview panel is QLPreviewPanel of Quartz.h. Implemented in sdk/src/QuickLook.m */
#ifndef WSBSD_QUICKLOOK_H
#define WSBSD_QUICKLOOK_H
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugIn.h>
#include <CoreGraphics/CoreGraphics.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct __QLThumbnailRequest *QLThumbnailRequestRef;
typedef struct __QLPreviewRequest *QLPreviewRequestRef;
#define kQLGeneratorTypeID CFUUIDGetConstantUUIDWithBytes(NULL, 0x5E, 0x2D, 0x96, 0x80, 0x50, 0x22, 0x40, 0xFA, 0xB8, 0x06, 0x43, 0x34, 0x96, 0x22, 0xE5, 0xB9)
#define kQLGeneratorCallbacksInterfaceID CFUUIDGetConstantUUIDWithBytes(NULL, 0x86, 0x5A, 0xF5, 0xE0, 0x6D, 0x30, 0x43, 0x45, 0x95, 0x1B, 0xD3, 0x71, 0x05, 0x75, 0x4F, 0x2D)
typedef struct QLGeneratorInterfaceStruct {
	IUNKNOWN_C_GUTS;
	OSStatus (*GenerateThumbnailForURL)(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
	void (*CancelThumbnailGeneration)(void *thisInterface, QLThumbnailRequestRef thumbnail);
	OSStatus (*GeneratePreviewForURL)(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
	void (*CancelPreviewGeneration)(void *thisInterface, QLPreviewRequestRef preview);
} QLGeneratorInterfaceStruct;
extern const CFStringRef kQLPreviewPropertyDisplayNameKey, kQLPreviewPropertyWidthKey, kQLPreviewPropertyHeightKey, kQLPreviewPropertyMIMETypeKey, kQLPreviewPropertyTextEncodingNameKey,
	kQLPreviewPropertyBackgroundColorKey, kQLThumbnailPropertyExtensionKey, kQLThumbnailPropertyBadgeImageKey;
/* generator side */
CFBundleRef QLThumbnailRequestGetGeneratorBundle(QLThumbnailRequestRef thumbnail);
CFBundleRef QLPreviewRequestGetGeneratorBundle(QLPreviewRequestRef preview);
Boolean QLThumbnailRequestIsCancelled(QLThumbnailRequestRef thumbnail);
Boolean QLPreviewRequestIsCancelled(QLPreviewRequestRef preview);
CGContextRef QLThumbnailRequestCreateContext(QLThumbnailRequestRef thumbnail, CGSize size, Boolean isBitmap, CFDictionaryRef properties);
void QLThumbnailRequestFlushContext(QLThumbnailRequestRef thumbnail, CGContextRef context);
void QLThumbnailRequestSetImage(QLThumbnailRequestRef thumbnail, CGImageRef image, CFDictionaryRef properties);
void QLThumbnailRequestSetImageWithData(QLThumbnailRequestRef thumbnail, CFDataRef data, CFDictionaryRef properties);
void QLThumbnailRequestSetImageAtURL(QLThumbnailRequestRef thumbnail, CFURLRef url, CFDictionaryRef properties);
void QLPreviewRequestSetDataRepresentation(QLPreviewRequestRef preview, CFDataRef data, CFStringRef contentTypeUTI, CFDictionaryRef properties);
void QLPreviewRequestSetURLRepresentation(QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef properties);
CGContextRef QLPreviewRequestCreateContext(QLPreviewRequestRef preview, CGSize size, Boolean isBitmap, CFDictionaryRef properties);
void QLPreviewRequestFlushContext(QLPreviewRequestRef preview, CGContextRef context);
/* client side */
CGImageRef QLThumbnailImageCreate(CFAllocatorRef allocator, CFURLRef url, CGSize maxThumbnailSize, CFDictionaryRef options);
#ifdef __cplusplus
}
#endif
#ifdef __OBJC__
#import <Quartz/Quartz.h>
/* the preview of a file as the panel shows it: attributed text, an image, or nothing (kind 0) */
@interface WsbsdQLPreview : NSObject
@property (nonatomic, readonly) NSInteger kind;                 /* 0 none, 1 text, 2 image */
@property (nonatomic, readonly, strong) NSAttributedString *text;
@property (nonatomic, readonly, strong) NSImage *image;
@property (nonatomic, readonly, copy) NSString *contentType;    /* the UTI of the data a generator returned (nil for the built-in ones) */
+ (WsbsdQLPreview *)previewForURL:(NSURL *)url;
@end
#endif
#endif
