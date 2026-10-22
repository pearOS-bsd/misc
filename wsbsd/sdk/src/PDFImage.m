/* PDF images: -[NSImage initWithContentsOfFile:] / ...URL:, +imageNamed: and -[NSBundle imageForResource:] load .pdf files (the template images of Mac applications are PDFs). The first page is rendered by
 * poppler (libpoppler-glib, loaded at run time; without it the PDFs stay unloadable as before) into a bitmap at three times its size, shown at its natural size. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <dlfcn.h>

typedef struct _cairo cairo_t; typedef struct _cairo_surface cairo_surface_t;
static void *(*p_doc_new)(const char *, const char *, void **);
static int (*p_doc_pages)(void *);
static void *(*p_doc_page)(void *, int);
static void (*p_page_size)(void *, double *, double *);
static void (*p_page_render)(void *, cairo_t *);
static void (*p_unref)(void *);
static cairo_surface_t *(*c_surface)(int, int, int);
static cairo_t *(*c_create)(cairo_surface_t *);
static void (*c_scale)(cairo_t *, double, double);
static void (*c_destroy)(cairo_t *);
static void (*c_surface_destroy)(cairo_surface_t *);
static void (*c_flush)(cairo_surface_t *);
static unsigned char *(*c_data)(cairo_surface_t *);
static int (*c_stride)(cairo_surface_t *);

static BOOL LoadPoppler(void)
{
	static int state; if (state) return state > 0;
	void *h = dlopen("libpoppler-glib.so.8", RTLD_NOW | RTLD_GLOBAL); if (!h) h = dlopen("libpoppler-glib.so", RTLD_NOW | RTLD_GLOBAL); void *g = dlopen("libgobject-2.0.so", RTLD_NOW | RTLD_GLOBAL); void *c = dlopen("libcairo.so.2", RTLD_NOW | RTLD_GLOBAL); if (!c) c = dlopen("libcairo.so", RTLD_NOW | RTLD_GLOBAL);
	if (!h || !c) { state = -1; return NO; }
	p_doc_new = dlsym(h, "poppler_document_new_from_file"); p_doc_pages = dlsym(h, "poppler_document_get_n_pages"); p_doc_page = dlsym(h, "poppler_document_get_page"); p_page_size = dlsym(h, "poppler_page_get_size"); p_page_render = dlsym(h, "poppler_page_render");
	p_unref = dlsym(g ?: h, "g_object_unref"); c_surface = dlsym(c, "cairo_image_surface_create"); c_create = dlsym(c, "cairo_create"); c_scale = dlsym(c, "cairo_scale"); c_destroy = dlsym(c, "cairo_destroy"); c_surface_destroy = dlsym(c, "cairo_surface_destroy"); c_flush = dlsym(c, "cairo_surface_flush"); c_data = dlsym(c, "cairo_image_surface_get_data"); c_stride = dlsym(c, "cairo_image_surface_get_stride");
	state = p_doc_new && p_doc_pages && p_doc_page && p_page_size && p_page_render && p_unref && c_surface && c_create && c_scale && c_destroy && c_surface_destroy && c_flush && c_data && c_stride ? 1 : -1; return state > 0;
}
static NSImage *RenderPDF(NSString *path)
{
	if (!LoadPoppler() || ![path length]) return nil;
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary]; NSImage *hit = cache[path]; if (hit) return [hit copy];
	NSMutableString *uri = [NSMutableString stringWithString: @"file://"]; for (const unsigned char *p = (const unsigned char *)[path fileSystemRepresentation]; *p; p++) { if (isalnum(*p) || strchr("/-_.~", *p)) [uri appendFormat: @"%c", *p]; else [uri appendFormat: @"%%%02X", *p]; }
	void *err = NULL; void *doc = p_doc_new([uri UTF8String], NULL, &err); if (!doc) return nil; if (p_doc_pages(doc) < 1) { p_unref(doc); return nil; }
	void *page = p_doc_page(doc, 0); double w = 0, h = 0; p_page_size(page, &w, &h); if (w < 1 || h < 1) { p_unref(page); p_unref(doc); return nil; }
	const double S = 3; int pw = (int)ceil(w * S), ph = (int)ceil(h * S); cairo_surface_t *sf = c_surface(0, pw, ph); cairo_t *cr = c_create(sf); c_scale(cr, S, S); p_page_render(page, cr); c_flush(sf);
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: pw pixelsHigh: ph bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: pw * 4 bitsPerPixel: 32];
	unsigned char *dst = [rep bitmapData], *src = c_data(sf); int st = c_stride(sf);
	for (int y = 0; y < ph; y++) for (int x = 0; x < pw; x++) { unsigned char *s = src + y * st + x * 4, *d = dst + (y * pw + x) * 4; unsigned a = s[3]; d[3] = a; if (a) { d[0] = MIN(255, s[2] * 255 / a); d[1] = MIN(255, s[1] * 255 / a); d[2] = MIN(255, s[0] * 255 / a); } else d[0] = d[1] = d[2] = 0; }
	c_destroy(cr); c_surface_destroy(sf); p_unref(page); p_unref(doc);
	[rep setSize: NSMakeSize(w, h)]; NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)]; [img addRepresentation: rep]; cache[path] = img; return [img copy];
}
static BOOL IsPDF(NSString *p) { return [[[p pathExtension] lowercaseString] isEqualToString: @"pdf"]; }

static IMP origInitFile, origInitURL, origNamed, origForResource;
static id NewInitFile(id self, SEL _cmd, NSString *path) { if (IsPDF(path)) { NSImage *i = RenderPDF(path); if (i) return i; } return ((id (*)(id, SEL, id))origInitFile)(self, _cmd, path); }
static id NewInitURL(id self, SEL _cmd, NSURL *url) { if ([url isFileURL] && IsPDF([url path])) { NSImage *i = RenderPDF([url path]); if (i) return i; } return ((id (*)(id, SEL, id))origInitURL)(self, _cmd, url); }
static id NewNamed(id self, SEL _cmd, NSString *name)
{
	id img = ((id (*)(id, SEL, id))origNamed)(self, _cmd, name); if (img || ![name length] || [name hasPrefix: @"/"]) return img;
	NSString *p = [[NSBundle mainBundle] pathForResource: name ofType: @"pdf"]; if (p) { NSImage *i = RenderPDF(p); if (i) { [i setName: name]; return i; } } return nil;
}
static id NewForResource(id self, SEL _cmd, NSString *name)
{
	id img = origForResource ? ((id (*)(id, SEL, id))origForResource)(self, _cmd, name) : nil; if (img || ![name length]) return img;
	NSString *p = [(NSBundle *)self pathForResource: name ofType: @"pdf"]; return p ? RenderPDF(p) : nil;
}
@interface WsbsdPDFLoader : NSObject @end
@implementation WsbsdPDFLoader
+ (void)load
{
	Class img = objc_getClass("NSImage"); Method m;
	if ((m = class_getInstanceMethod(img, @selector(initWithContentsOfFile:)))) { origInitFile = method_getImplementation(m); method_setImplementation(m, (IMP)NewInitFile); }
	if ((m = class_getInstanceMethod(img, @selector(initWithContentsOfURL:)))) { origInitURL = method_getImplementation(m); method_setImplementation(m, (IMP)NewInitURL); }
	if ((m = class_getClassMethod(img, @selector(imageNamed:)))) { origNamed = method_getImplementation(m); method_setImplementation(m, (IMP)NewNamed); }
	Class b = objc_getClass("NSBundle"); m = class_getInstanceMethod(b, @selector(imageForResource:)); if (m) { origForResource = method_getImplementation(m); method_setImplementation(m, (IMP)NewForResource); } else class_addMethod(b, @selector(imageForResource:), (IMP)NewForResource, "@@:@");
}
@end
