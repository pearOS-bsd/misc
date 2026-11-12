/*
 * NSPDFImageRep.m — behavioral-1:1 core. See the header.
 */

#import "NSPDFImageRep.h"

@implementation NSPDFImageRep {
    NSData *_pdfData;
    CGPDFDocumentRef _doc;   /* the parsed document (_NSPDFDocument in AppKit) */
    NSInteger _currentPage;
    NSInteger _pageCount;
}

+ (BOOL)canInitWithData:(NSData *)data
{
    if (data.length < 5) return NO;
    const unsigned char *b = (const unsigned char *)data.bytes;
    /* a PDF stream begins with "%PDF-" (possibly after a few junk bytes, but
       the real check is the leading signature). */
    return b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F' && b[4] == '-';
}

+ (instancetype)imageRepWithData:(NSData *)pdfData { return [[self alloc] initWithData:pdfData]; }

- (instancetype)initWithData:(NSData *)pdfData
{
    self = [super init];
    if (self) {
        _pdfData = [pdfData copy];
        _currentPage = 0;
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)_pdfData);
        if (provider) {
            _doc = CGPDFDocumentCreateWithProvider(provider);
            CGDataProviderRelease(provider);
        }
        _pageCount = _doc ? (NSInteger)CGPDFDocumentGetNumberOfPages(_doc) : 0;
        [self _applyCurrentPageGeometry];
    }
    return self;
}

- (void)dealloc
{
    if (_doc) CGPDFDocumentRelease(_doc);
}

- (CGPDFPageRef)_cgPage
{
    if (!_doc || _pageCount == 0) return NULL;
    NSInteger p = _currentPage;
    if (p < 0) p = 0;
    if (p >= _pageCount) p = _pageCount - 1;
    return CGPDFDocumentGetPage(_doc, (size_t)(p + 1)); /* CG is 1-based */
}

- (void)_applyCurrentPageGeometry
{
    CGRect media = CGRectZero;
    CGPDFPageRef page = [self _cgPage];
    if (page) media = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    self.size = media.size;   /* size tracks the current page's media box */
}

- (NSData *)PDFRepresentation { return _pdfData; }
- (NSInteger)pageCount { return _pageCount; }
- (NSInteger)currentPage { return _currentPage; }

- (void)setCurrentPage:(NSInteger)currentPage
{
    _currentPage = currentPage;
    [self _applyCurrentPageGeometry];
}

- (CGRect)bounds
{
    CGPDFPageRef page = [self _cgPage];
    if (!page) return CGRectZero;
    return CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
}

- (BOOL)draw
{
    /* TODO(stage2): CGContextDrawPDFPage into the current graphics context. */
    return YES;
}

@end
