/* CoreText drawing over Opal. Opal's CTFontDrawGlyphs is empty, and its CGContextSetFont expects a CairoFont while CTFontCopyGraphicsFont hands back another kind of object, so
 * no glyph reaches the surface. This draws them itself: the font is found through fontconfig by its PostScript name, becomes a cairo FreeType face, and the glyphs are shown on the
 * cairo context that Opal's CGContext draws with (the first instance variable after isa, see the layout below; pinned to Opal's CGContext-private.h), under the context's text
 * matrix and fill colour. This library comes before libopal in the lookup order of the programs, so this definition is the one called. */
#include <CoreText/CoreText.h>
#include <CoreGraphics/CoreGraphics.h>
#include <cairo.h>
#include <cairo-ft.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <objc/runtime.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>

/* the instance variables of Opal's CGContext, after isa, and the first fields of its additional-state struct */
typedef struct { void *isa; cairo_t *ct; void *add; CGAffineTransform txtmatrix; CGFloat scale_factor; CGSize device_size; } OpalCGContext;
typedef struct OpalAdd { struct OpalAdd *next; double alpha; void *fill_color; cairo_pattern_t *fill_cp; } OpalAdd;

#define FACE_CACHE 64
static struct { void *ft; cairo_font_face_t *face; } faces[FACE_CACHE];
static int nfaces;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

/* Opal's FreeType font object (OPFreeTypeFont, which the fontconfig font derives from) keeps its FT_Face in the instance variable fontFace; CTFontCopyPostScriptName is not
 * implemented in Opal, so the name cannot be used to find the face again. */
static cairo_font_face_t *face_for(CTFontRef font)
{
	Ivar iv = class_getInstanceVariable(object_getClass((id)font), "fontFace");
	if (!iv) return NULL;
	void *ft = *(void **)((char *)font + ivar_getOffset(iv));
	if (!ft) return NULL;
	pthread_mutex_lock(&lock);
	for (int i = 0; i < nfaces; i++) if (faces[i].ft == ft) { cairo_font_face_t *f = faces[i].face; pthread_mutex_unlock(&lock); return f; }
	cairo_font_face_t *face = cairo_ft_font_face_create_for_ft_face((FT_Face)ft, 0);
	if (face && nfaces < FACE_CACHE) { faces[nfaces].ft = ft; faces[nfaces].face = face; nfaces++; }
	pthread_mutex_unlock(&lock);
	return face;
}

void CTFontDrawGlyphs(CTFontRef font, const CGGlyph glyphs[], const CGPoint positions[], size_t count, CGContextRef context)
{
	if (!font || !context || !count) return;
	OpalCGContext *c = (OpalCGContext *)context;
	cairo_font_face_t *face = face_for(font);
	if (!face || !c->ct) return;
	cairo_t *ct = c->ct;
	cairo_save(ct);
	cairo_set_font_face(ct, face);
	cairo_matrix_t fm, tm;
	cairo_matrix_init_identity(&fm);
	cairo_matrix_scale(&fm, 1, -1);                                     /* Opal's context is flipped; this undoes it for the glyph shapes */
	cairo_matrix_translate(&fm, 0, -1);
	cairo_matrix_scale(&fm, CTFontGetSize(font), CTFontGetSize(font));
	cairo_matrix_init(&tm, c->txtmatrix.a, c->txtmatrix.b, c->txtmatrix.c, c->txtmatrix.d, 0, 0);
	cairo_matrix_multiply(&fm, &fm, &tm);
	cairo_set_font_matrix(ct, &fm);
	OpalAdd *add = (OpalAdd *)c->add;
	if (add && add->fill_cp) cairo_set_source(ct, add->fill_cp);
	for (size_t i = 0; i < count; i++) {                                /* one at a time: the same cairo workaround Opal's own code has */
		CGPoint p = CGPointApplyAffineTransform(positions[i], c->txtmatrix);
		cairo_glyph_t g = { glyphs[i], p.x, p.y };
		cairo_show_glyphs(ct, &g, 1);
	}
	cairo_restore(ct);
}

/* CTFontCopyCharacterSet: Opal answers with the font descriptor's character set attribute, which a font made by name does not have (nil), so every character looked uncovered by
 * the font (Hex Fiend's ASCII column then asked for substitution fonts forever). The set is read from the face's character map. The set is an NSMutableCharacterSet, made through the
 * runtime because this file is plain C. */
#include <objc/message.h>
#include FT_FREETYPE_H
typedef struct { unsigned long location, length; } WsbsdRange;
CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font)
{
	Ivar iv = class_getInstanceVariable(object_getClass((id)font), "fontFace");
	void *ft = iv ? *(void **)((char *)font + ivar_getOffset(iv)) : NULL;
	Class cls = objc_getClass("NSMutableCharacterSet");
	if (!cls) return NULL;
	id set = ((id (*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("new"));
	if (!set) return NULL;
	if (ft) {
		FT_Face face = (FT_Face)ft;
		FT_UInt idx; FT_ULong c = FT_Get_First_Char(face, &idx), start = 0, prev = 0; int open = 0;
		while (idx) {
			if (!open) { start = prev = c; open = 1; }
			else if (c == prev + 1) prev = c;
			else {
				WsbsdRange r = { start, prev - start + 1 };
				if (start < 0x10000) ((void (*)(id, SEL, WsbsdRange))objc_msgSend)(set, sel_registerName("addCharactersInRange:"), r);
				start = prev = c;
			}
			c = FT_Get_Next_Char(face, c, &idx);
		}
		if (open && start < 0x10000) { WsbsdRange r = { start, prev - start + 1 }; ((void (*)(id, SEL, WsbsdRange))objc_msgSend)(set, sel_registerName("addCharactersInRange:"), r); }
	}
	return (CFCharacterSetRef)set;
}

/* CTFontCreateForString: on Apple the result is never NULL (the base font itself when nothing else covers the text; its glyph lookup then fails and the caller marks the character
 * as missing). Opal's returns NULL when fontconfig finds no other font, and Hex Fiend's ASCII column then never settled: the glyph of a character like a newline stayed "not loaded"
 * and it reloaded and redrew forever. */
#include <dlfcn.h>
CTFontRef CTFontCreateForString(CTFontRef base, CFStringRef str, CFRange range)
{
	static CTFontRef (*real)(CTFontRef, CFStringRef, CFRange);
	if (!real) real = (CTFontRef (*)(CTFontRef, CFStringRef, CFRange))dlsym(RTLD_NEXT, "CTFontCreateForString");
	CTFontRef r = real ? real(base, str, range) : NULL;
	if (!r && base) r = (CTFontRef)CFRetain(base);
	return r;
}

/* CTFontGetGlyphsForCharacters: the result is false when some character has no glyph (that glyph is 0). Opal's answers true whatever the lookup found, so a substitution font that does not
 * cover a character was taken for one that does, and Hex Fiend drew glyph 0 (the "missing" box) of a font whose advance it then divided by: a pane-sized box. */
bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar characters[], CGGlyph glyphs[], CFIndex count)
{
	static bool (*real)(CTFontRef, const UniChar *, CGGlyph *, CFIndex);
	if (!real) real = (bool (*)(CTFontRef, const UniChar *, CGGlyph *, CFIndex))dlsym(RTLD_NEXT, "CTFontGetGlyphsForCharacters");
	if (!real) return false;
	bool ok = real(font, characters, glyphs, count);
	for (CFIndex i = 0; i < count; i++) if (glyphs[i] == 0) ok = false;
	return ok;
}

/* CGRectIntersection with the CoreGraphics semantics. Opal's returned the other rectangle when one had no size (CGRectZero, "no caret": Hex Fiend then filled the whole text view
 * with the caret colour) and a NaN rectangle instead of CGRectNull when they do not meet. Touching rectangles give a rectangle without width or height, as on Apple. */
CGRect CGRectIntersection(CGRect r1, CGRect r2)
{
	if (CGRectIsNull(r1) || CGRectIsNull(r2)) return CGRectNull;
	CGFloat a0 = r1.origin.x, a1 = r1.origin.x + r1.size.width, b0 = r2.origin.x, b1 = r2.origin.x + r2.size.width;
	if (a1 < a0) { CGFloat t = a0; a0 = a1; a1 = t; }
	if (b1 < b0) { CGFloat t = b0; b0 = b1; b1 = t; }
	CGFloat c0 = r1.origin.y, c1 = r1.origin.y + r1.size.height, d0 = r2.origin.y, d1 = r2.origin.y + r2.size.height;
	if (c1 < c0) { CGFloat t = c0; c0 = c1; c1 = t; }
	if (d1 < d0) { CGFloat t = d0; d0 = d1; d1 = t; }
	CGFloat x0 = a0 > b0 ? a0 : b0, x1 = a1 < b1 ? a1 : b1, y0 = c0 > d0 ? c0 : d0, y1 = c1 < d1 ? c1 : d1;
	if (!(x1 >= x0) || !(y1 >= y0)) return CGRectNull;                                    /* also NaN */
	return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
