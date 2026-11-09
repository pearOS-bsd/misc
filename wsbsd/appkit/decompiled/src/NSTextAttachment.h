/*
 * NSTextAttachment.h — 1:1 reimplementation (core). NSObject <NSSecureCoding>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextAttachment : NSObject <NSTextAttachmentLayout, NSSecureCoding> {
 *       @"NSData" _data; @"UTType" _uti; {CGRect} _bounds; d _layoutPadding;
 *       @"NSImage" _image; @"NSFileWrapper" _fileWrapperForContents;
 *       @"<NSTextAttachmentCell>" _attachmentCell; … _taFlags;
 *   }
 *   @property (T@"NSData",C,D) contents;
 *   @property (T@"NSString",C,D) fileType;
 *   @property (T@"NSImage",&,D) image;
 *   @property (T{CGRect},D) bounds;
 *   @property (Td) lineLayoutPadding;
 *   @property (TB) allowsTextAttachmentView;
 *   -initWithData:ofType:
 *
 * A value object holding an attachment's data, UTI file type, drawing bounds,
 * image and layout padding. The text-attachment view/cell providers and the
 * actual glyph layout (NSTextAttachmentLayout) are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTextAttachment : NSObject

- (instancetype)initWithData:(nullable NSData *)contentData ofType:(nullable NSString *)uti;

@property (nullable, copy) NSData *contents;
@property (nullable, copy) NSString *fileType;
@property (nullable, strong) id image;              /* NSImage (stage2) */
@property (nullable, strong) id fileWrapper;        /* NSFileWrapper */
@property (nullable, strong) id attachmentCell;     /* <NSTextAttachmentCell> */
@property CGRect bounds;
@property CGFloat lineLayoutPadding;
@property BOOL allowsTextAttachmentView;

@end

NS_ASSUME_NONNULL_END
