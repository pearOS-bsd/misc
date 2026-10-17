/* CoreGraphics inside AppKit drawing: -[NSGraphicsContext graphicsPort] for the cairo backend.
 *
 * Mac applications draw with CoreGraphics in -drawRect: through [[NSGraphicsContext currentContext] graphicsPort] / CGContext. The cairo backend has no CGContext, the port was NULL
 * and the first CGContext call crashed. Opal (CoreGraphics over cairo) can draw on the same cairo surface the window uses, so a CGContext is made on that surface and brought in
 * line with the current graphics state each time the port is asked for: the transformation (the state's ctm on top of the base space both libraries share: the window flipped),
 * the clip (the rectangles of the cairo clip) and the fill and stroke colours. Opal is looked up at run time: programs that do not use it are not affected. */
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <cairo.h>
#include <dlfcn.h>
#include "cairo/CairoGState.h"
#include "cairo/CairoSurface.h"
#include "gsc/GSGState.h"

typedef void *WsdCGContext;
static WsdCGContext (*opalNew)(cairo_surface_t *, CGSize);
static void (*cgFill)(WsdCGContext, CGFloat, CGFloat, CGFloat, CGFloat);
static void (*cgStroke)(WsdCGContext, CGFloat, CGFloat, CGFloat, CGFloat);
typedef struct { void *isa; cairo_t *ct; } WsdOpalContextHead;      /* the first instance variable of Opal's CGContext: the cairo context it draws with */

static const char cgKey, cgSurfaceKey;

static void colorComponents(device_color_t c, CGFloat *r, CGFloat *g, CGFloat *b)
{
	gsColorToRGB(&c);
	*r = c.field[0]; *g = c.field[1]; *b = c.field[2];
}

static void *wsdGraphicsPort(id self, SEL _cmd)
{
	static BOOL looked;
	if (!looked) {
		looked = YES;
		opalNew = dlsym(RTLD_DEFAULT, "opal_new_CGContext");
		cgFill = dlsym(RTLD_DEFAULT, "CGContextSetRGBFillColor");
		cgStroke = dlsym(RTLD_DEFAULT, "CGContextSetRGBStrokeColor");
	}
	if (!opalNew || !cgFill || !cgStroke) return NULL;
	Ivar iv = class_getInstanceVariable([self class], "gstate");
	id gs = iv ? object_getIvar(self, iv) : nil;
	if (!gs || ![gs isKindOfClass: NSClassFromString(@"CairoGState")]) return NULL;
	CairoGState *g = (CairoGState *)gs;
	if (!g->_ct || !g->_surface) return NULL;
	cairo_surface_t *surf = [g->_surface surface];
	NSSize size = [g->_surface size];

	WsdCGContext cg = (WsdCGContext)objc_getAssociatedObject(self, &cgKey);
	NSValue *last = objc_getAssociatedObject(self, &cgSurfaceKey);
	if (!cg || ![last pointerValue] || [last pointerValue] != surf) {
		cg = opalNew(surf, (CGSize){ size.width, size.height });
		if (!cg) return NULL;
		objc_setAssociatedObject(self, &cgKey, (id)cg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);                        /* the context is an Objective-C object; the association keeps it */
		objc_setAssociatedObject(self, &cgSurfaceKey, [NSValue valueWithPointer: surf], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	cairo_t *ct = ((WsdOpalContextHead *)cg)->ct;
	/* base space: the window, flipped; the clip is given in it (cairo clip rectangles of the state's own cairo context) */
	cairo_identity_matrix(ct); cairo_scale(ct, 1, -1); cairo_translate(ct, 0, -size.height);
	cairo_reset_clip(ct);
	cairo_rectangle_list_t *rl = cairo_copy_clip_rectangle_list(g->_ct);
	if (rl && rl->status == CAIRO_STATUS_SUCCESS && rl->num_rectangles > 0) {
		for (int i = 0; i < rl->num_rectangles; i++) cairo_rectangle(ct, rl->rectangles[i].x, rl->rectangles[i].y, rl->rectangles[i].width, rl->rectangles[i].height);
		cairo_clip(ct);
	}
	if (rl) cairo_rectangle_list_destroy(rl);
	NSAffineTransformStruct t = [g->ctm transformStruct];
	cairo_matrix_t m = { t.m11, t.m12, t.m21, t.m22, t.tX, t.tY };
	cairo_transform(ct, &m);
	CGFloat r, gr, b;
	colorComponents(g->fillColor, &r, &gr, &b); cgFill(cg, r, gr, b, 1.0);
	colorComponents(g->strokeColor, &r, &gr, &b); cgStroke(cg, r, gr, b, 1.0);
	return cg;
}

void WsdInstallCGBridge(void)
{
	Method m = class_getInstanceMethod([NSGraphicsContext class], @selector(graphicsPort));
	if (m) class_replaceMethod([NSGraphicsContext class], @selector(graphicsPort), (IMP)wsdGraphicsPort, method_getTypeEncoding(m));
}
