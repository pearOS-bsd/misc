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
