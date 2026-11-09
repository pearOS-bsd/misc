/*
 * NSTextAttachment.m — 1:1 (core). See NSTextAttachment.h for interface evidence.
 *
 * Plain value object: -initWithData:ofType: records the contents (_data) and
 * UTI file type (_uti); bounds/lineLayoutPadding/image/fileWrapper/attachmentCell
 * are stored fields. allowsTextAttachmentView lives in _taFlags bit0. The glyph
 * layout and the view/cell providers (NSTextAttachmentLayout) are stage2.
 */
#import "NSTextAttachment.h"

@implementation NSTextAttachment {
    NSData *_data;
    NSString *_uti;
    CGRect _bounds;
    CGFloat _layoutPadding;
    id _image, _fileWrapper, _attachmentCell;
    BOOL _allowsTextAttachmentView;   /* _taFlags bit0 */
}

- (instancetype)initWithData:(NSData *)contentData ofType:(NSString *)uti
{
    self = [super init];
    if (self) {
        _data = [contentData copy];
        _uti = [uti copy];
        _bounds = CGRectZero;
    }
    return self;
}

- (instancetype)init { return [self initWithData:nil ofType:nil]; }

- (NSData *)contents { return _data; }
- (void)setContents:(NSData *)v { _data = [v copy]; }
- (NSString *)fileType { return _uti; }
- (void)setFileType:(NSString *)v { _uti = [v copy]; }
- (id)image { return _image; }
- (void)setImage:(id)v { _image = v; }
- (id)fileWrapper { return _fileWrapper; }
- (void)setFileWrapper:(id)v { _fileWrapper = v; }
- (id)attachmentCell { return _attachmentCell; }
- (void)setAttachmentCell:(id)v { _attachmentCell = v; }
- (CGRect)bounds { return _bounds; }
- (void)setBounds:(CGRect)v { _bounds = v; }
- (CGFloat)lineLayoutPadding { return _layoutPadding; }
- (void)setLineLayoutPadding:(CGFloat)v { _layoutPadding = v; }
- (BOOL)allowsTextAttachmentView { return _allowsTextAttachmentView; }
- (void)setAllowsTextAttachmentView:(BOOL)v { _allowsTextAttachmentView = v; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ {type:%@ dataLen:%lu bounds:{%g,%g,%g,%g}}",
            [super description], _uti, (unsigned long)_data.length,
            _bounds.origin.x, _bounds.origin.y, _bounds.size.width, _bounds.size.height];
}

@end
