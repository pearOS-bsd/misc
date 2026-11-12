/* test_nspdfimagerep.m */
#import "../src/NSPDFImageRep.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSData *makePDF(int pages, CGFloat w, CGFloat h) {
    NSMutableData *d = [NSMutableData data];
    CGDataConsumerRef cons = CGDataConsumerCreateWithCFData((CFMutableDataRef)d);
    CGRect media = CGRectMake(0, 0, w, h);
    CGContextRef c = CGPDFContextCreate(cons, &media, NULL);
    for (int i = 0; i < pages; i++) { CGContextBeginPage(c, &media); CGContextEndPage(c); }
    CGPDFContextClose(c); CGContextRelease(c); CGDataConsumerRelease(cons);
    return d;
}

int main(void) {
    @autoreleasepool {
        NSData *pdf = makePDF(3, 200, 100);

        CHECK([NSPDFImageRep canInitWithData:pdf], "canInitWithData YES for PDF");
        CHECK(![NSPDFImageRep canInitWithData:[@"not a pdf" dataUsingEncoding:NSUTF8StringEncoding]], "canInitWithData NO for junk");
        CHECK(![NSPDFImageRep canInitWithData:[NSData data]], "canInitWithData NO for empty");

        NSPDFImageRep *r = [[NSPDFImageRep alloc] initWithData:pdf];
        CHECK([r isKindOfClass:[NSImageRep class]], "is NSImageRep");
        CHECK(r.pageCount == 3, "pageCount 3");
        CHECK(r.currentPage == 0, "currentPage 0 default (0-based)");
        CHECK(r.bounds.size.width == 200 && r.bounds.size.height == 100, "bounds = media box");
        CHECK(r.size.width == 200 && r.size.height == 100, "size tracks bounds");
        CHECK([r.PDFRepresentation isEqual:pdf], "PDFRepresentation is input data");

        /* page selection */
        r.currentPage = 2;
        CHECK(r.currentPage == 2 && r.bounds.size.width == 200, "set currentPage within range");

        /* out-of-range currentPage clamps geometry but stores raw value (observable) */
        r.currentPage = 99;
        CHECK(r.bounds.size.width == 200, "clamped page still yields valid bounds");

        /* +imageRepWithData factory */
        NSPDFImageRep *r2 = [NSPDFImageRep imageRepWithData:pdf];
        CHECK(r2 != nil && r2.pageCount == 3, "factory builds equivalent rep");

        /* invalid data => non-nil rep, 0 pages, zero size (measured) */
        NSPDFImageRep *bad = [[NSPDFImageRep alloc] initWithData:[@"%garbage" dataUsingEncoding:NSUTF8StringEncoding]];
        CHECK(bad != nil, "invalid data still returns a rep");
        CHECK(bad.pageCount == 0, "invalid data: 0 pages");
        CHECK(bad.size.width == 0 && bad.size.height == 0, "invalid data: zero size");
        CHECK(CGRectEqualToRect(bad.bounds, CGRectZero), "invalid data: zero bounds");

        /* single-page, different size */
        NSPDFImageRep *one = [[NSPDFImageRep alloc] initWithData:makePDF(1, 612, 792)];
        CHECK(one.pageCount == 1 && one.bounds.size.height == 792, "single US-Letter page");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
