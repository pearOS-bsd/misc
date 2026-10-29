/* OpenGL ES 2 window compositor (see include/ws_gl.h). Structure:
 *   init      EGL display (GBM platform on a DRM node, else surfaceless/default), ES2 context, extension probing, shader, render target
 *   textures  per-window textures kept across frames; hardware path = dma-buf EGLImage, fallback = glTexSubImage2D of the damaged rectangle
 *   frame     compositor_render_frame(): clear, then draw windows bottom to top, each with premultiplied blending, an analytic rounded-corner
 *             clip (signed distance field) and a 1 px border; the window's shadow layer is drawn above it */
#ifdef WS_GL
#include "ws_gl.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#ifdef WS_GBM
#include <gbm.h>
#endif
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef EGL_PLATFORM_GBM_KHR
#define EGL_PLATFORM_GBM_KHR 0x31D7
#endif
#ifndef EGL_PLATFORM_SURFACELESS_MESA
#define EGL_PLATFORM_SURFACELESS_MESA 0x31DD
#endif

#define MAX_TEX 192

typedef struct { uint32_t wid; GLuint tex; int w, h; uint32_t from_buffer; int seen; } wtex;
typedef struct { uint32_t wid, gen; GLuint tex; int w, h; int seen; } stex;
typedef struct { uint32_t id; void *image; GLuint tex; int w, h; } itex;

struct gl_compositor {
	EGLDisplay dpy; EGLContext ctx; EGLSurface pbuf;
#ifdef WS_GBM
	struct gbm_device *gbm;
#endif
	int w, h;
	int have_import, have_export;
	PFNEGLCREATEIMAGEKHRPROC create_image;
	PFNEGLDESTROYIMAGEKHRPROC destroy_image;
	PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_target;
	PFNEGLEXPORTDMABUFIMAGEQUERYMESAPROC export_query;
	PFNEGLEXPORTDMABUFIMAGEMESAPROC export_image;
	GLuint prog, vbo, fbo, fbo_tex, tmp_fbo, tmp_tex, blur_prog, scene_tex, bl_fbo, bl_tex, glass_prog;
	GLint bu_rect, bu_screen, bu_src, bu_dir, bu_sigma, bu_rad, bu_step;
	GLint gu_rect, gu_screen, gu_scene, gu_blur, gu_n, gu_grect, gu_grm, gu_L, gu_amp;
	GLint u_bright, u_usedst;
	GLint u_invert, u_xf, u_xt, u_rect, u_screen, u_tex, u_size, u_uvscale, u_alpha, u_radius, u_border, u_swap;
	wtex wt[MAX_TEX]; stex st[MAX_TEX]; itex it[MAX_TEX];
	uint8_t *stage; size_t stage_cap;
	char desc[320];
};

/* ---------------------------------------------------------------- shaders */
static const char *VS =
	"attribute vec2 a_pos;\n"                                  /* unit quad, (0,0) top-left */
	"attribute vec2 a_dst;\n"                                  /* mesh vertices: the destination in pixels (a_pos is then the texture coordinate) */
	"uniform int u_usedst;\n"
	"uniform vec4 u_rect;\n"                                   /* x, y, width, height in pixels, origin top-left */
	"uniform vec2 u_screen;\n"
	"uniform vec4 u_xf;\n"                                    /* SetWindowTransform a b c d about the quad centre; all zero (the default) = identity */
	"uniform vec2 u_xt;\n"                                    /* its translation */
	"varying vec2 v_uv;\n"
	"void main() {\n"
	"    vec2 px = u_rect.xy + a_pos * u_rect.zw;\n"
	"    if (u_xf != vec4(0.0)) { vec2 ctr = u_rect.xy + 0.5 * u_rect.zw, d = px - ctr; px = ctr + vec2(u_xf.x * d.x + u_xf.z * d.y, u_xf.y * d.x + u_xf.w * d.y) + u_xt; }\n"
	"    /* row 0 of the render target is the top of the screen, so read-back and scan-out need no flip */\n"
	"    gl_Position = vec4(px.x / u_screen.x * 2.0 - 1.0, px.y / u_screen.y * 2.0 - 1.0, 0.0, 1.0);\n"
	"    if (u_usedst != 0) px = a_dst;\n"
	"    gl_Position = vec4(px.x / u_screen.x * 2.0 - 1.0, px.y / u_screen.y * 2.0 - 1.0, 0.0, 1.0);\n"
	"    v_uv = a_pos;\n"
	"}\n";

static const char *BLUR_FS =
	"#ifdef GL_FRAGMENT_PRECISION_HIGH\n"
	"precision highp float;\n"
	"#else\n"
	"precision mediump float;\n"
	"#endif\n"
	"uniform sampler2D u_src;\n"
	"uniform vec2 u_screen;\n"
	"uniform vec2 u_dir;\n"                                   /* (1,0) or (0,1) */
	"uniform float u_sigma;\n"
	"uniform float u_rad;\n"                                  /* taps on each side, <= 45 */
	"uniform float u_step;\n"                                 /* distance between the taps in pixels (2 reaches 90 px with 45 taps) */
	"void main() {\n"
	"    vec2 uv = gl_FragCoord.xy / u_screen;\n"
	"    vec4 sum = vec4(0.0); float wsum = 0.0;\n"
	"    for (int i = -45; i <= 45; i++) {\n"
	"        float f = float(i);\n"
	"        if (abs(f) > u_rad) continue;\n"
	"        float w = exp(-f * f / (2.0 * u_sigma * u_sigma));\n"
	"        sum += texture2D(u_src, uv + u_dir * f * u_step / u_screen) * w; wsum += w;\n"
	"    }\n"
	"    gl_FragColor = sum / wsum;\n"
	"}\n";


/* the glass of a window (see blur.c ws_glass_regions): up to 16 rounded rectangles melted by a smooth minimum; modes 1, 2 the lens material, 3, 4 the menu material of Menu.caar */
static const char *GLASS_FS =
	"#ifdef GL_FRAGMENT_PRECISION_HIGH\n"
	"precision highp float;\n"
	"#else\n"
	"precision mediump float;\n"
	"#endif\n"
	"uniform sampler2D u_scene;\n"                             /* the frame so far (a copy) */
	"uniform sampler2D u_blur;\n"                              /* the same, blurred (menu materials) */
	"uniform vec2 u_screen;\n"
	"uniform int u_n;\n"
	"uniform vec4 u_grect[16];\n"                              /* x, y, w, h in screen pixels */
	"uniform vec2 u_grm[16];\n"                                /* radius, mode */
	"uniform float u_L;\n"
	"uniform float u_amp;\n"
	"float field(vec2 p, out float mode) {\n"
	"    float f = 1e9; mode = 1.0; bool first = true;\n"
	"    for (int i = 0; i < 16; i++) {\n"
	"        if (i >= u_n) break;\n"
	"        if (u_grm[i].y < 0.5) continue;\n"
	"        vec4 r = u_grect[i]; vec2 h = 0.5 * r.zw; float rad = min(u_grm[i].x, min(h.x, h.y));\n"
	"        vec2 q = abs(p - (r.xy + h)) - (h - vec2(rad));\n"
	"        float s = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;\n"
	"        if (first) { f = s; mode = u_grm[i].y; first = false; continue; }\n"
	"        float hh = max(14.0 - abs(f - s), 0.0) / 14.0; float m = min(f, s) - hh * hh * 14.0 * 0.25;\n"
	"        if (s < f) mode = u_grm[i].y;\n"
	"        f = m;\n"
	"    }\n"
	"    return f;\n"
	"}\n"
	"void main() {\n"
	"    vec2 p = gl_FragCoord.xy; float mode, dm;\n"
	"    float sdf = field(p, mode);\n"
	"    vec3 dst = texture2D(u_scene, p / u_screen).rgb;\n"
	"    float cover = clamp(0.5 - sdf, 0.0, 1.0);\n"
	"    if (cover <= 0.0) { gl_FragColor = vec4(dst, 1.0); return; }\n"
	"    vec3 col;\n"
	"    if (mode > 4.5) {\n"
	"        float dd = max(-sdf, 0.0);\n"
	"        float gx = field(p + vec2(1.0, 0.0), dm) - field(p - vec2(1.0, 0.0), dm), gy = field(p + vec2(0.0, 1.0), dm) - field(p - vec2(0.0, 1.0), dm);\n"
	"        float gl = sqrt(gx * gx + gy * gy), ny = gl > 1e-4 ? abs(gy / gl) : 1.0; vec2 no = gl > 1e-4 ? vec2(gx, gy) / gl : vec2(0.0, -1.0);\n"
	"        float sx = 0.0, sy = 0.0;\n"
	"        for (int q = 0; q < 16; q++) { if (q >= u_n) break; if (u_grm[q].y < 4.5 || (u_grm[q].y > 5.5 && u_grm[q].y < 7.5)) continue; vec4 r = u_grect[q]; if (p.x >= r.x && p.x < r.x + r.z && p.y >= r.y && p.y < r.y + r.w) {\n"        /* the displacement per edge, as in blur.c; the shader's y is up, so the top edge of the glass is its larger y */
	"            float dl = p.x - r.x, dr = r.x + r.z - p.x, db = p.y - r.y, dt = r.y + r.w - p.y, dx = min(dl, dr);\n"
	"            if (dx < 8.0) sx = 12.0 * sin(3.14159265 * dx / 8.0);\n"
	"            if (dt < 14.0 && dt <= db) sy = -18.0 * sin(3.14159265 * dt / 14.0); else if (db < 8.0) sy = -12.0 * sin(3.14159265 * db / 8.0);\n"
	"            break; } }\n"
	"        vec3 c = texture2D(u_blur, (p + vec2(sx, sy)) / u_screen).rgb;\n"
	"        if (mode > 5.5 && mode < 7.5) { vec3 a = texture2D(u_scene, p / u_screen).rgb; float wt = 1.0; a += 0.0; for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) { if (i == 0 && j == 0) continue; float w = (i != 0 && j != 0) ? 0.44 : 0.66; a += w * texture2D(u_scene, (p + vec2(float(i), float(j))) / u_screen).rgb; wt += w; } c = a / wt; }\n"
	"        float L = dot(c, vec3(0.1886, 0.7455, 0.0659)), f = mode > 7.5 ? 0.4041 + L * (0.6443 + L * (0.1437 - 0.1998 * L)) : mode > 6.5 ? 0.1216 + L * (0.987 - 0.395 * L) : mode > 5.5 ? 0.047 + L * (0.856 - 0.213 * L) : 0.12494 + L * (0.86553 - L * (0.24983 + 0.16865 * L));\n"
	"        float rim = (mode > 6.5 && mode < 7.5) ? 0.0 : (mode > 5.5 && mode < 6.5) ? ny * (floor(dd) < 1.0 ? 0.292 : floor(dd) < 9.0 ? 0.066 * exp(-0.55 * (floor(dd) - 1.0)) : 0.0) * (1.0 - 0.26 * L - 0.17 * L * L) : (dd < 1.0 ? 0.10 + 0.177 * ny : 0.042 * ny * exp(-(dd - 1.5) / 3.8));\n"
	"        col = clamp(vec3(f) + 1.091 * (c - vec3(L)), 0.0, 1.0);\n"
	"        col = col * (1.0 - rim) + vec3(rim);\n"
	"        if (mode > 6.5 && mode < 7.5 && dd < 1.0) col *= 0.53;\n"
	"    } else if (mode > 2.5) {\n"
	"        bool dark = mode > 3.5;\n"
	"        float sat = dark ? 2.2 : 2.1, fill = dark ? 0.157 : 0.965, fa = dark ? 0.70 : 0.72, tone = dark ? 0.125 : 0.93;\n"
	"        col = texture2D(u_blur, p / u_screen).rgb;\n"
	"        float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));\n"
	"        col = clamp(vec3(lum) + (col - vec3(lum)) * sat, 0.0, 1.0);\n"
	"        col = vec3(fill * fa) + col * (1.0 - fa);\n"
	"        col = dark ? max(col, vec3(tone)) : min(col, vec3(tone));\n"
	"    } else {\n"
	"        float d = max(-sdf, 0.0);\n"
	"        float gx = field(p + vec2(1.0, 0.0), dm) - field(p - vec2(1.0, 0.0), dm), gy = field(p + vec2(0.0, 1.0), dm) - field(p - vec2(0.0, 1.0), dm);\n"
	"        float gl = sqrt(gx * gx + gy * gy); vec2 n = gl > 1e-4 ? vec2(gx, gy) / gl : vec2(0.0, -1.0);\n"
	"        bool clear = mode > 1.5;\n"
	"        float L = clear ? 10.0 : u_L, A = clear ? u_amp * 0.5 : u_amp, tint = clear ? 0.90 : 0.69, lift = clear ? 0.0 : 0.012;\n"
	"        float shift = d < L ? A * sin(3.14159265 * d / L) : 0.0;\n"
	"        col = texture2D(u_scene, (p + n * shift) / u_screen).rgb;\n"
	"        float light = max(n.x * -0.55 + n.y * -0.83, 0.0);\n"
	"        float rim = exp(-d / 1.1) * (0.10 + 0.50 * light), glow = exp(-d / 5.0) * 0.05 * light, white = rim + glow;\n"
	"        col = col * tint + vec3(lift); col = col * (1.0 - white) + vec3(white); col = min(col, vec3(1.0));\n"
	"    }\n"
	"    gl_FragColor = vec4(mix(dst, col, cover), 1.0);\n"
	"}\n";

static const char *FS =
	"#ifdef GL_FRAGMENT_PRECISION_HIGH\n"
	"precision highp float;\n"
	"#else\n"
	"precision mediump float;\n"
	"#endif\n"
	"uniform sampler2D u_tex;\n"
	"uniform vec2 u_size;\n"                                   /* quad size in pixels */
	"uniform vec2 u_uvscale;\n"
	"uniform float u_alpha;\n"                                 /* window opacity */
	"uniform float u_radius;\n"                                /* corner radius in pixels, 0 = square */
	"uniform float u_border;\n"                                /* 1px border strength, 0 = none */
	"uniform int u_swap;\n"
	"uniform float u_bright;\n"                               /* SetWindowListBrightness: the colour of the premultiplied pixel is scaled, never above the alpha */
	"uniform int u_invert;\n"                                 /* CIColorInvert: premultiplied c = a - c */                                    /* 1: the texture holds BGRA bytes uploaded as RGBA */
	"varying vec2 v_uv;\n"
	"void main() {\n"
	"    vec2 p = (v_uv - 0.5) * u_size;\n"
	"    vec2 q = abs(p) - (0.5 * u_size - vec2(u_radius));\n"
	"    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - u_radius;\n"   /* signed distance to the rounded rectangle, < 0 inside */
	"    float cover = clamp(0.5 - d, 0.0, 1.0);\n"                               /* analytic anti-aliased clip */
	"    vec4 c = texture2D(u_tex, v_uv * u_uvscale);\n"                          /* premultiplied */
	"    if (u_swap != 0) c = c.bgra;\n"
	"    if (u_invert != 0) c = vec4(c.a - c.rgb, c.a);\n"
	"    c.rgb = min(c.rgb * u_bright, vec3(c.a));\n"
	"    c *= cover;\n"
	"    float ring = clamp(1.0 - abs(d + 0.5), 0.0, 1.0);\n"                      /* a 1 px band just inside the edge */
	"    vec4 b = vec4(0.0, 0.0, 0.0, 0.16) * ring * u_border * cover;\n"          /* subtle dark stroke, premultiplied */
	"    c = b + c * (1.0 - b.a);\n"
	"    gl_FragColor = c * u_alpha;\n"                                            /* premultiplied output for glBlendFunc(ONE, ONE_MINUS_SRC_ALPHA) */
	"}\n";

static GLuint compile(GLenum type, const char *src)
{
	GLuint s = glCreateShader(type);
	glShaderSource(s, 1, &src, NULL);
	glCompileShader(s);
	GLint ok = 0;
	glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
	if (!ok) {
		char log[512]; GLsizei n = 0;
		glGetShaderInfoLog(s, sizeof log - 1, &n, log); log[n] = 0;
		fprintf(stderr, "wsd: shader compile failed: %s\n", log);
		glDeleteShader(s);
		return 0;
	}
	return s;
}

static int build_program(gl_compositor *c)
{
	GLuint vs = compile(GL_VERTEX_SHADER, VS), fs = compile(GL_FRAGMENT_SHADER, FS);
	if (!vs || !fs) { if (vs) glDeleteShader(vs); if (fs) glDeleteShader(fs); return -1; }
	c->prog = glCreateProgram();
	glAttachShader(c->prog, vs); glAttachShader(c->prog, fs);
	glBindAttribLocation(c->prog, 0, "a_pos"); glBindAttribLocation(c->prog, 1, "a_dst");
	glLinkProgram(c->prog);
	glDeleteShader(vs); glDeleteShader(fs);
	GLint ok = 0;
	glGetProgramiv(c->prog, GL_LINK_STATUS, &ok);
	if (!ok) {
		char log[512]; GLsizei n = 0;
		glGetProgramInfoLog(c->prog, sizeof log - 1, &n, log); log[n] = 0;
		fprintf(stderr, "wsd: shader link failed: %s\n", log);
		glDeleteProgram(c->prog); c->prog = 0;
		return -1;
	}
	c->u_rect = glGetUniformLocation(c->prog, "u_rect");
	c->u_invert = glGetUniformLocation(c->prog, "u_invert"); c->u_bright = glGetUniformLocation(c->prog, "u_bright"); c->u_usedst = glGetUniformLocation(c->prog, "u_usedst");
	c->u_xf = glGetUniformLocation(c->prog, "u_xf"); c->u_xt = glGetUniformLocation(c->prog, "u_xt");
	c->u_screen = glGetUniformLocation(c->prog, "u_screen");
	c->u_tex = glGetUniformLocation(c->prog, "u_tex");
	c->u_size = glGetUniformLocation(c->prog, "u_size");
	c->u_uvscale = glGetUniformLocation(c->prog, "u_uvscale");
	c->u_alpha = glGetUniformLocation(c->prog, "u_alpha");
	c->u_radius = glGetUniformLocation(c->prog, "u_radius");
	c->u_border = glGetUniformLocation(c->prog, "u_border");
	c->u_swap = glGetUniformLocation(c->prog, "u_swap");
	{                                                                             /* separable gaussian for background blur */
		GLuint bvs = compile(GL_VERTEX_SHADER, VS), bfs = compile(GL_FRAGMENT_SHADER, BLUR_FS);
		if (bvs && bfs) {
			c->blur_prog = glCreateProgram();
			glAttachShader(c->blur_prog, bvs); glAttachShader(c->blur_prog, bfs);
			glBindAttribLocation(c->blur_prog, 0, "a_pos");
			glLinkProgram(c->blur_prog);
			GLint lk = 0; glGetProgramiv(c->blur_prog, GL_LINK_STATUS, &lk);
			if (!lk) { glDeleteProgram(c->blur_prog); c->blur_prog = 0; }
			else {
				c->bu_rect = glGetUniformLocation(c->blur_prog, "u_rect"); c->bu_screen = glGetUniformLocation(c->blur_prog, "u_screen");
				c->bu_src = glGetUniformLocation(c->blur_prog, "u_src"); c->bu_dir = glGetUniformLocation(c->blur_prog, "u_dir");
				c->bu_sigma = glGetUniformLocation(c->blur_prog, "u_sigma"); c->bu_rad = glGetUniformLocation(c->blur_prog, "u_rad"); c->bu_step = glGetUniformLocation(c->blur_prog, "u_step");
			}
		}
		if (bvs) glDeleteShader(bvs);
		if (bfs) glDeleteShader(bfs);
	}
	{                                                                             /* the glass pass */
		GLuint gvs = compile(GL_VERTEX_SHADER, VS), gfs = compile(GL_FRAGMENT_SHADER, GLASS_FS);
		if (gvs && gfs) {
			c->glass_prog = glCreateProgram();
			glAttachShader(c->glass_prog, gvs); glAttachShader(c->glass_prog, gfs);
			glBindAttribLocation(c->glass_prog, 0, "a_pos");
			glLinkProgram(c->glass_prog);
			GLint lk = 0; glGetProgramiv(c->glass_prog, GL_LINK_STATUS, &lk);
			if (!lk) { char log[512]; GLsizei n = 0; glGetProgramInfoLog(c->glass_prog, sizeof log - 1, &n, log); log[n] = 0; fprintf(stderr, "wsd: glass shader link failed: %s\n", log); glDeleteProgram(c->glass_prog); c->glass_prog = 0; }
			else {
				GLuint g = c->glass_prog;
				c->gu_rect = glGetUniformLocation(g, "u_rect"); c->gu_screen = glGetUniformLocation(g, "u_screen"); c->gu_scene = glGetUniformLocation(g, "u_scene"); c->gu_blur = glGetUniformLocation(g, "u_blur");
				c->gu_n = glGetUniformLocation(g, "u_n"); c->gu_grect = glGetUniformLocation(g, "u_grect"); c->gu_grm = glGetUniformLocation(g, "u_grm"); c->gu_L = glGetUniformLocation(g, "u_L"); c->gu_amp = glGetUniformLocation(g, "u_amp");
			}
		} else if (gfs == 0) fprintf(stderr, "wsd: glass shader did not compile\n");
		if (gvs) glDeleteShader(gvs);
		if (gfs) glDeleteShader(gfs);
	}
	return 0;
}

/* ---------------------------------------------------------------- EGL */
static int has_ext(const char *list, const char *name)
{
	if (!list) return 0;
	size_t n = strlen(name);
	for (const char *p = list; (p = strstr(p, name)); p += n)
		if ((p == list || p[-1] == ' ') && (p[n] == ' ' || p[n] == 0)) return 1;
	return 0;
}

static EGLDisplay pick_display(gl_compositor *c, const char *node)
{
	const char *cext = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);        /* client extensions, NULL if unsupported */
	PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform = (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
	EGLDisplay d = EGL_NO_DISPLAY;
#ifdef WS_GBM
	if (node) {
		c->gbm = ws_gbm_open(node);
		if (c->gbm) {
			if (get_platform && (has_ext(cext, "EGL_KHR_platform_gbm") || has_ext(cext, "EGL_MESA_platform_gbm")))
				d = get_platform(EGL_PLATFORM_GBM_KHR, c->gbm, NULL);
			if (d == EGL_NO_DISPLAY) d = eglGetDisplay((EGLNativeDisplayType)c->gbm);
			if (d != EGL_NO_DISPLAY) return d;
			ws_gbm_close(c->gbm); c->gbm = NULL;
		}
	}
#else
	(void)node;
#endif
	if (get_platform && has_ext(cext, "EGL_MESA_platform_surfaceless")) d = get_platform(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
	if (d == EGL_NO_DISPLAY) d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
	return d;
}

static void make_target(gl_compositor *c)
{
	glGenTextures(1, &c->fbo_tex);
	glBindTexture(GL_TEXTURE_2D, c->fbo_tex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, c->w, c->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glGenFramebuffers(1, &c->fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, c->fbo_tex, 0);
	glGenTextures(1, &c->tmp_tex);                                                 /* intermediate target of the separable blur */
	glBindTexture(GL_TEXTURE_2D, c->tmp_tex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, c->w, c->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glGenFramebuffers(1, &c->tmp_fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, c->tmp_fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, c->tmp_tex, 0);
	glGenTextures(1, &c->scene_tex);                                               /* a copy of the frame for the glass to read while it writes */
	glBindTexture(GL_TEXTURE_2D, c->scene_tex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, c->w, c->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenTextures(1, &c->bl_tex);                                                  /* and its blurred version */
	glBindTexture(GL_TEXTURE_2D, c->bl_tex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, c->w, c->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenFramebuffers(1, &c->bl_fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, c->bl_fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, c->bl_tex, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
}

gl_compositor *glc_create(const char *node, int width, int height)
{
	if (width <= 0 || height <= 0) return NULL;
	gl_compositor *c = calloc(1, sizeof *c);
	if (!c) return NULL;
	c->w = width; c->h = height; c->dpy = EGL_NO_DISPLAY; c->ctx = EGL_NO_CONTEXT; c->pbuf = EGL_NO_SURFACE;
	c->dpy = pick_display(c, node);
	EGLint major = 0, minor = 0;
	if (c->dpy == EGL_NO_DISPLAY || !eglInitialize(c->dpy, &major, &minor)) goto fail;
	if (!eglBindAPI(EGL_OPENGL_ES_API)) goto fail;
	const char *eext = eglQueryString(c->dpy, EGL_EXTENSIONS);
	int surfaceless = has_ext(eext, "EGL_KHR_surfaceless_context");

	EGLConfig cfg; EGLint ncfg = 0;
	EGLint cattr[] = { EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, surfaceless ? EGL_DONT_CARE : EGL_PBUFFER_BIT,
	                   EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE };
	if (!eglChooseConfig(c->dpy, cattr, &cfg, 1, &ncfg) || ncfg < 1) goto fail;
	EGLint xattr[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
	c->ctx = eglCreateContext(c->dpy, cfg, EGL_NO_CONTEXT, xattr);
	if (c->ctx == EGL_NO_CONTEXT) goto fail;
	if (!surfaceless) {
		EGLint pb[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
		c->pbuf = eglCreatePbufferSurface(c->dpy, cfg, pb);
		if (c->pbuf == EGL_NO_SURFACE) goto fail;
	}
	if (!eglMakeCurrent(c->dpy, c->pbuf, c->pbuf, c->ctx)) goto fail;

	/* runtime extension probing: no extension is required for the upload path */
	const char *gext = (const char *)glGetString(GL_EXTENSIONS);
	c->create_image = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
	c->destroy_image = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
	c->image_target = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
	c->have_import = has_ext(eext, "EGL_EXT_image_dma_buf_import") && has_ext(gext, "GL_OES_EGL_image") &&
	                 c->create_image && c->destroy_image && c->image_target;
	c->export_query = (PFNEGLEXPORTDMABUFIMAGEQUERYMESAPROC)eglGetProcAddress("eglExportDMABUFImageQueryMESA");
	c->export_image = (PFNEGLEXPORTDMABUFIMAGEMESAPROC)eglGetProcAddress("eglExportDMABUFImageMESA");
	c->have_export = has_ext(eext, "EGL_MESA_image_dma_buf_export") && c->export_query && c->export_image && c->create_image && c->destroy_image;

	if (build_program(c)) goto fail;
	static const GLfloat quad[8] = { 0, 0, 1, 0, 0, 1, 1, 1 };
	glGenBuffers(1, &c->vbo);
	glBindBuffer(GL_ARRAY_BUFFER, c->vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
	make_target(c);
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { fprintf(stderr, "wsd: render target incomplete\n"); goto fail; }

	snprintf(c->desc, sizeof c->desc, "EGL %d.%d, %s, dma-buf import %s, export %s, %s",
	         (int)major, (int)minor, (const char *)glGetString(GL_RENDERER), c->have_import ? "yes" : "no (upload path)", c->have_export ? "yes" : "no (read-back)",
#ifdef WS_GBM
	         c->gbm ? "GBM display" : "default display"
#else
	         "default display"
#endif
	);
	return c;
fail:
	glc_destroy(c);
	return NULL;
}

/* ---------------------------------------------------------------- textures */
static GLuint new_texture(void)
{
	GLuint t = 0;
	glGenTextures(1, &t);
	glBindTexture(GL_TEXTURE_2D, t);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	return t;
}

/* Fallback upload: copies the dirty rectangle into a tightly packed staging buffer (ES2 has no unpack row length) and uploads it. */
static void upload_rect(gl_compositor *c, GLuint tex, const ws_surface *p, ws_rect r)
{
	if (r.x < 0) { r.w += r.x; r.x = 0; }
	if (r.y < 0) { r.h += r.y; r.y = 0; }
	if (r.x + r.w > p->w) r.w = p->w - r.x;
	if (r.y + r.h > p->h) r.h = p->h - r.y;
	if (r.w <= 0 || r.h <= 0) return;
	size_t need = (size_t)r.w * (size_t)r.h * 4;
	if (need > c->stage_cap) {
		uint8_t *n = realloc(c->stage, need);
		if (!n) return;
		c->stage = n; c->stage_cap = need;
	}
	for (int y = 0; y < r.h; y++)
		memcpy(c->stage + (size_t)y * (size_t)r.w * 4, p->px + (size_t)(r.y + y) * p->stride + (size_t)r.x * 4, (size_t)r.w * 4);
	glBindTexture(GL_TEXTURE_2D, tex);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
	glTexSubImage2D(GL_TEXTURE_2D, 0, r.x, r.y, r.w, r.h, GL_RGBA, GL_UNSIGNED_BYTE, c->stage);
}

static itex *find_import(gl_compositor *c, uint32_t id)
{
	for (int i = 0; i < MAX_TEX; i++) if (c->it[i].id == id && id) return &c->it[i];
	return NULL;
}

int glc_import_buffer(gl_compositor *c, const ws_buffer *b)
{
	if (!c || !c->have_import || b->kind != WS_BUF_DMABUF || b->fd[0] < 0) return -1;
	itex *slot = NULL;
	for (int i = 0; i < MAX_TEX && !slot; i++) if (!c->it[i].id) slot = &c->it[i];
	if (!slot) return -1;
	void *img = ws_buffer_egl_import((ws_buffer *)b, c->dpy);                   /* eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, fourcc, size, pitch, offset) */
	if (!img) return -1;
	GLuint t = new_texture();
	c->image_target(GL_TEXTURE_2D, (GLeglImageOES)img);                          /* the texture now aliases the client's memory */
	if (glGetError() != GL_NO_ERROR) { glDeleteTextures(1, &t); c->destroy_image(c->dpy, (EGLImageKHR)img); return -1; }
	slot->id = b->id; slot->image = img; slot->tex = t; slot->w = b->w; slot->h = b->h;
	return 0;
}

void glc_forget_buffer(gl_compositor *c, uint32_t id)
{
	itex *i = find_import(c, id);
	if (!i) return;
	glDeleteTextures(1, &i->tex);
	c->destroy_image(c->dpy, (EGLImageKHR)i->image);
	memset(i, 0, sizeof *i);
}

static wtex *window_slot(gl_compositor *c, uint32_t wid)
{
	wtex *free_slot = NULL;
	for (int i = 0; i < MAX_TEX; i++) {
		if (c->wt[i].wid == wid && c->wt[i].tex) return &c->wt[i];
		if (!c->wt[i].tex && !free_slot) free_slot = &c->wt[i];
	}
	return free_slot;
}

/* Returns the texture to sample for this window, uploading the damaged part first when the content lives in CPU memory. */
static GLuint window_texture(gl_compositor *c, const ws_visit *v, int *swap, float *uvx, float *uvy)
{
	*uvx = *uvy = 1.0f;
	if (v->buffer_id) {                                                          /* hardware path: no copy */
		itex *im = find_import(c, v->buffer_id);
		if (im) { *swap = 0; return im->tex; }
	}
	const ws_surface *p = v->pixels;
	if (!p || !p->px || p->w <= 0 || p->h <= 0) return 0;
	wtex *t = window_slot(c, v->id);
	if (!t) return 0;
	int fresh = !t->tex || t->w != p->w || t->h != p->h || t->from_buffer != v->buffer_id;
	if (fresh) {
		if (t->tex) glDeleteTextures(1, &t->tex);
		t->tex = new_texture();
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, p->w, p->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		t->wid = v->id; t->w = p->w; t->h = p->h; t->from_buffer = v->buffer_id;
	}
	if (fresh || v->full_damage) upload_rect(c, t->tex, p, (ws_rect){ 0, 0, p->w, p->h });
	else if (v->has_damage) upload_rect(c, t->tex, p, v->damage);               /* only the dirty rectangle from FlushSurface */
	t->seen = 1;
	*swap = 1;                                                                   /* BGRA bytes uploaded as RGBA */
	return t->tex;
}

static GLuint shadow_texture(gl_compositor *c, const ws_visit *v)
{
	stex *t = NULL, *free_slot = NULL;
	for (int i = 0; i < MAX_TEX; i++) {
		if (c->st[i].tex && c->st[i].wid == v->id) t = &c->st[i];
		else if (!c->st[i].tex && !free_slot) free_slot = &c->st[i];
	}
	if (!t) t = free_slot;
	if (!t) return 0;
	const ws_surface *p = v->shadow;
	if (!t->tex || t->gen != v->shadow_gen || t->w != p->w || t->h != p->h) {
		if (t->tex) glDeleteTextures(1, &t->tex);
		t->tex = new_texture();
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, p->w, p->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		upload_rect(c, t->tex, p, (ws_rect){ 0, 0, p->w, p->h });
		t->wid = v->id; t->gen = v->shadow_gen; t->w = p->w; t->h = p->h;
	}
	t->seen = 1;
	return t->tex;
}

/* ---------------------------------------------------------------- frame */
static void draw_quad(gl_compositor *c, float x, float y, float w, float h, GLuint tex, float uvx, float uvy, float alpha, float radius, float border, int swap)
{
	glUniform4f(c->u_rect, x, y, w, h);
	glUniform2f(c->u_size, w, h);
	glUniform2f(c->u_uvscale, uvx, uvy);
	glUniform1f(c->u_alpha, alpha);
	glUniform1f(c->u_radius, radius);
	glUniform1f(c->u_border, border);
	glUniform1i(c->u_swap, swap);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, tex);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

/* backdrop blur: horizontal pass of the scene into tmp (the window rect plus the vertical reach), vertical pass back into the frame inside the window rect */
static void blur_backdrop(gl_compositor *c, const ws_visit *v)
{
	if (!c->blur_prog || v->blur_radius <= 0) return;
	float sigma = ws_blur_sigma(v->blur_radius); int reach = (int)ceilf(3.0f * sigma); if (reach > 45) reach = 45;
	float x = (float)v->frame.x, y = (float)v->frame.y, w = (float)v->frame.w, h = (float)v->frame.h;
	float y0 = y - (float)reach < 0 ? 0 : y - (float)reach, y1 = y + h + (float)reach > (float)c->h ? (float)c->h : y + h + (float)reach;
	if (x < 0) { w += x; x = 0; }
	if (x + w > (float)c->w) w = (float)c->w - x;
	if (w <= 0 || y1 <= y0) return;
	glDisable(GL_BLEND);
	glUseProgram(c->blur_prog);
	glUniform2f(c->bu_screen, (float)c->w, (float)c->h);
	glUniform1i(c->bu_src, 0); glUniform1f(c->bu_sigma, sigma); glUniform1f(c->bu_rad, (float)reach); glUniform1f(c->bu_step, 1.0f);
	glActiveTexture(GL_TEXTURE0);
	glBindFramebuffer(GL_FRAMEBUFFER, c->tmp_fbo);
	glBindTexture(GL_TEXTURE_2D, c->fbo_tex);
	glUniform2f(c->bu_dir, 1.0f, 0.0f); glUniform4f(c->bu_rect, x, y0, w, y1 - y0);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
	glBindTexture(GL_TEXTURE_2D, c->tmp_tex);
	glUniform2f(c->bu_dir, 0.0f, 1.0f); glUniform4f(c->bu_rect, x, y, w, h < (float)c->h - y ? h : (float)c->h - y);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glUseProgram(c->prog);
	glEnable(GL_BLEND);
}

/* the glass shapes of a window over the frame drawn so far: a copy of the frame (and, for the menu materials, a gaussian blur of it) is read while the shapes are written */
static void glass_pass(gl_compositor *c, const ws_visit *v)
{
	if (!c->glass_prog || !v->glass || v->nglass <= 0 || !c->blur_prog) return;
	float rect[16 * 4], rm[16 * 2]; int n = 0, mat = 0; float bx0 = 1e9f, by0 = 1e9f, bx1 = -1e9f, by1 = -1e9f;
	for (int i = 0; i < v->nglass && i < 16; i++) {
		const ws_glass *g = &v->glass[i]; rect[4 * i] = (float)(v->frame.x + g->rect.x); rect[4 * i + 1] = (float)(v->frame.y + g->rect.y); rect[4 * i + 2] = (float)g->rect.w; rect[4 * i + 3] = (float)g->rect.h;
		rm[2 * i] = (float)g->radius; rm[2 * i + 1] = g->rect.w > 3 && g->rect.h > 3 ? (float)g->mode : 0.0f; n = i + 1;
		if (rm[2 * i + 1] <= 0) continue;
		if (g->mode >= 3) mat |= g->mode >= 5 && g->mode <= 8 ? 2 : 1;
		if (rect[4 * i] < bx0) bx0 = rect[4 * i]; if (rect[4 * i + 1] < by0) by0 = rect[4 * i + 1];
		if (rect[4 * i] + rect[4 * i + 2] > bx1) bx1 = rect[4 * i] + rect[4 * i + 2]; if (rect[4 * i + 1] + rect[4 * i + 3] > by1) by1 = rect[4 * i + 1] + rect[4 * i + 3];
	}
	if (bx1 <= bx0) return;
	const float M = 32.0f;                                                          /* the lens looks this far beyond the edge */
	float x0 = fmaxf(bx0 - M, 0), y0 = fmaxf(by0 - M, 0), x1 = fminf(bx1 + M, (float)c->w), y1 = fminf(by1 + M, (float)c->h);
	if (x1 <= x0 || y1 <= y0) return;
	glDisable(GL_BLEND);
	glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
	glBindTexture(GL_TEXTURE_2D, c->scene_tex);
	glCopyTexSubImage2D(GL_TEXTURE_2D, 0, (int)x0, (int)y0, (int)x0, (int)y0, (int)(x1 - x0), (int)(y1 - y0));
	if (mat) {                                                                      /* sigma 30 with taps 2 px apart: 45 taps reach 90 px */
		float reach = (mat & 1) ? 90.0f : 22.0f, ry0 = fmaxf(y0 - reach, 0), ry1 = fminf(y1 + reach, (float)c->h);
		glUseProgram(c->blur_prog);
		int fine = !(mat & 1);                                                         /* only the context-menu material (sigma 7, measured with stripes behind a menu): taps 1 px apart */
		glUniform2f(c->bu_screen, (float)c->w, (float)c->h); glUniform1i(c->bu_src, 0); glUniform1f(c->bu_sigma, fine ? 7.0f : 15.0f); glUniform1f(c->bu_rad, fine ? 21.0f : 45.0f); glUniform1f(c->bu_step, fine ? 1.0f : 2.0f);
		glActiveTexture(GL_TEXTURE0);
		glBindFramebuffer(GL_FRAMEBUFFER, c->tmp_fbo); glBindTexture(GL_TEXTURE_2D, c->fbo_tex);
		glUniform2f(c->bu_dir, 1.0f, 0.0f); glUniform4f(c->bu_rect, x0, ry0, x1 - x0, ry1 - ry0); glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glBindFramebuffer(GL_FRAMEBUFFER, c->bl_fbo); glBindTexture(GL_TEXTURE_2D, c->tmp_tex);
		glUniform2f(c->bu_dir, 0.0f, 1.0f); glUniform4f(c->bu_rect, x0, y0, x1 - x0, y1 - y0); glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
	}
	glUseProgram(c->glass_prog);
	glUniform2f(c->gu_screen, (float)c->w, (float)c->h); glUniform4f(c->gu_rect, x0, y0, x1 - x0, y1 - y0);
	glUniform1i(c->gu_scene, 0); glUniform1i(c->gu_blur, 1); glUniform1i(c->gu_n, n);
	glUniform4fv(c->gu_grect, n, rect); glUniform2fv(c->gu_grm, n, rm);
	glUniform1f(c->gu_L, 18.0f); glUniform1f(c->gu_amp, 26.0f);
	glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_2D, c->bl_tex);
	glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, c->scene_tex);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glUseProgram(c->prog); glEnable(GL_BLEND);
}

/* the warped window (SetWindowWarp): every cell of the mesh is split into 6 x 6 pieces whose corners are interpolated bilinearly (the software compositor solves the bilinear map per pixel; triangles of a coarse cell
 * would show their diagonal), drawn as triangles from a client-side vertex array with the destination as a second attribute */
static void draw_mesh(gl_compositor *c, const ws_visit *v, GLuint tex, float uvx, float uvy, float alpha, int swap)
{
	enum { SUB = 6 };
	int cols = v->mcols, rows = v->mrows; if (cols < 2 || rows < 2) return;
	size_t cells = (size_t)(cols - 1) * (rows - 1), nv = cells * SUB * SUB * 6;
	float *vert = malloc(nv * 4 * sizeof(float)); if (!vert) return;
	size_t o = 0; float fw = (float)v->frame.w, fh = (float)v->frame.h, H = (float)c->h;
	for (int r = 0; r + 1 < rows; r++) for (int cc = 0; cc + 1 < cols; cc++) {
		const float *p[4] = { v->mesh + 4 * (r * cols + cc), v->mesh + 4 * (r * cols + cc + 1), v->mesh + 4 * ((r + 1) * cols + cc), v->mesh + 4 * ((r + 1) * cols + cc + 1) };
		for (int j = 0; j < SUB; j++) for (int i = 0; i < SUB; i++) {
			float s0 = (float)i / SUB, s1 = (float)(i + 1) / SUB, t0 = (float)j / SUB, t1 = (float)(j + 1) / SUB;
			float cs[4][2] = { { s0, t0 }, { s1, t0 }, { s0, t1 }, { s1, t1 } }; float q[4][4];
			for (int k = 0; k < 4; k++) {
				float s = cs[k][0], t = cs[k][1];
				#define LERP(n) ((1 - s) * (1 - t) * p[0][n] + s * (1 - t) * p[1][n] + (1 - s) * t * p[2][n] + s * t * p[3][n])
				float sx = LERP(0), sy = LERP(1), dx = LERP(2), dy = LERP(3);
				q[k][0] = sx / fw * uvx; q[k][1] = (fh - sy) / fh * uvy;      /* texture coordinates (a_pos is multiplied by u_uvscale in the fragment shader, so give it unscaled) */
				q[k][0] = sx / fw; q[k][1] = (fh - sy) / fh;
				q[k][2] = dx; q[k][3] = H - dy;
				#undef LERP
			}
			static const int idx[6] = { 0, 1, 2, 2, 1, 3 };
			for (int k = 0; k < 6; k++) { memcpy(vert + o, q[idx[k]], 4 * sizeof(float)); o += 4; }
		}
	}
	glUniform1i(c->u_usedst, 1); glUniform4f(c->u_rect, 0, 0, 1, 1); glUniform2f(c->u_size, fw, fh); glUniform2f(c->u_uvscale, uvx, uvy);
	glUniform1f(c->u_alpha, alpha); glUniform1f(c->u_radius, 0); glUniform1f(c->u_border, 0); glUniform1i(c->u_swap, swap);
	glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, tex);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), vert); glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), vert + 2);
	glDrawArrays(GL_TRIANGLES, 0, (GLsizei)o / 4);
	glDisableVertexAttribArray(1); glUniform1i(c->u_usedst, 0);
	glBindBuffer(GL_ARRAY_BUFFER, c->vbo); glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
	free(vert);
}

static void visit(void *ctx, const ws_visit *v)
{
	gl_compositor *c = ctx;
	if (v->blur_radius > 0) blur_backdrop(c, v);
	glass_pass(c, v);
	int swap = 1; float uvx = 1, uvy = 1;
	GLuint tex = window_texture(c, v, &swap, &uvx, &uvy);
	if (tex && v->alpha > 0.0f) {
		glUniform1i(c->u_invert, v->invert); glUniform1f(c->u_bright, v->brightness > 0 || v->brightness == 0 ? v->brightness : 1.0f);
		if (v->has_xf) { glUniform4f(c->u_xf, v->xf[0], v->xf[1], v->xf[2], v->xf[3]); glUniform2f(c->u_xt, v->xf[4], v->xf[5]); }
		if (v->mesh && v->mcols >= 2 && v->mrows >= 2) draw_mesh(c, v, tex, uvx, uvy, v->alpha, swap);
		else draw_quad(c, (float)v->frame.x, (float)v->frame.y, (float)v->frame.w, (float)v->frame.h, tex, uvx, uvy, v->alpha,
		          (float)v->corner_radius, v->corner_radius > 0 ? 1.0f : 0.0f, swap);
		glUniform1i(c->u_invert, 0); glUniform1f(c->u_bright, 1.0f);
		if (v->has_xf) { glUniform4f(c->u_xf, 0, 0, 0, 0); glUniform2f(c->u_xt, 0, 0); }
	}
	if (v->shadow && v->alpha > 0.0f) {                                          /* the shadow layer lies above its window: it is cut out of the window shape */
		GLuint st = shadow_texture(c, v);
		if (st) draw_quad(c, (float)v->shadow_x, (float)v->shadow_y, (float)v->shadow->w, (float)v->shadow->h, st, 1, 1, v->alpha, 0, 0, 1);
	}
}

int compositor_render_frame(gl_compositor *c, ws_server *srv)
{
	if (!c) return -1;
	if (eglGetCurrentContext() != c->ctx && !eglMakeCurrent(c->dpy, c->pbuf, c->pbuf, c->ctx)) return -1;
	for (int i = 0; i < MAX_TEX; i++) { c->wt[i].seen = 0; c->st[i].seen = 0; }
	glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
	glViewport(0, 0, c->w, c->h);
	float bg[3]; ws_server_desktop_color(srv, bg);
	glClearColor(bg[0], bg[1], bg[2], 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	glDisable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE); glDisable(GL_SCISSOR_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);                                  /* premultiplied alpha */
	glUseProgram(c->prog);
	glUniform2f(c->u_screen, (float)c->w, (float)c->h);
	glUniform1i(c->u_tex, 0); glUniform1f(c->u_bright, 1.0f); glUniform1i(c->u_usedst, 0);
	glBindBuffer(GL_ARRAY_BUFFER, c->vbo);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
	ws_server_walk(srv, visit, c);                                                /* Z-order, bottom to top */
	for (int i = 0; i < MAX_TEX; i++) {                                           /* free textures of windows that disappeared */
		if (c->wt[i].tex && !c->wt[i].seen) { glDeleteTextures(1, &c->wt[i].tex); memset(&c->wt[i], 0, sizeof c->wt[i]); }
		if (c->st[i].tex && !c->st[i].seen) { glDeleteTextures(1, &c->st[i].tex); memset(&c->st[i], 0, sizeof c->st[i]); }
	}
	glFinish();                                                                   /* the frame is complete and visible to read-back and to scan-out */
	ws_server_clear_damage(srv);
	return glGetError() == GL_NO_ERROR ? 0 : -1;
}

int glc_read_pixels(gl_compositor *c, ws_surface *dst)
{
	if (!c || !dst || dst->w != c->w || dst->h != c->h) return -1;
	size_t need = (size_t)c->w * (size_t)c->h * 4;
	if (need > c->stage_cap) {
		uint8_t *n = realloc(c->stage, need);
		if (!n) return -1;
		c->stage = n; c->stage_cap = need;
	}
	glBindFramebuffer(GL_FRAMEBUFFER, c->fbo);
	glPixelStorei(GL_PACK_ALIGNMENT, 4);
	glReadPixels(0, 0, c->w, c->h, GL_RGBA, GL_UNSIGNED_BYTE, c->stage);          /* row 0 is the top row (see the vertex shader) */
	for (int y = 0; y < c->h; y++) {
		const uint8_t *s = c->stage + (size_t)y * (size_t)c->w * 4;
		uint8_t *d = dst->px + (size_t)y * dst->stride;
		for (int x = 0; x < c->w; x++, s += 4, d += 4) { d[0] = s[2]; d[1] = s[1]; d[2] = s[0]; d[3] = s[3]; }   /* RGBA -> BGRA */
	}
	return glGetError() == GL_NO_ERROR ? 0 : -1;
}

int glc_export_target(gl_compositor *c, int *fd, uint32_t *fourcc, uint32_t *stride, uint32_t *offset, uint64_t *modifier)
{
	if (!c || !c->have_export) return -1;
	EGLint attr[] = { EGL_GL_TEXTURE_LEVEL_KHR, 0, EGL_NONE };
	EGLImageKHR img = c->create_image(c->dpy, c->ctx, EGL_GL_TEXTURE_2D_KHR, (EGLClientBuffer)(uintptr_t)c->fbo_tex, attr);
	if (img == EGL_NO_IMAGE_KHR) return -1;
	int fcc = 0, planes = 0, rc = -1;
	EGLuint64KHR mod = 0;
	if (c->export_query(c->dpy, img, &fcc, &planes, &mod) && planes == 1) {
		int fds[1] = { -1 }; EGLint st[1] = { 0 }, off[1] = { 0 };
		if (c->export_image(c->dpy, img, fds, st, off)) {
			*fd = fds[0]; *fourcc = (uint32_t)fcc; *stride = (uint32_t)st[0]; *offset = (uint32_t)off[0]; *modifier = (uint64_t)mod;
			rc = 0;
		}
	}
	c->destroy_image(c->dpy, img);
	return rc;
}

int glc_has_dmabuf_import(const gl_compositor *c) { return c && c->have_import; }
const char *glc_describe(const gl_compositor *c) { return c ? c->desc : "no GL compositor"; }

void glc_destroy(gl_compositor *c)
{
	if (!c) return;
	if (c->dpy != EGL_NO_DISPLAY && c->ctx != EGL_NO_CONTEXT && eglMakeCurrent(c->dpy, c->pbuf, c->pbuf, c->ctx)) {
		for (int i = 0; i < MAX_TEX; i++) {
			if (c->wt[i].tex) glDeleteTextures(1, &c->wt[i].tex);
			if (c->st[i].tex) glDeleteTextures(1, &c->st[i].tex);
			if (c->it[i].id) { glDeleteTextures(1, &c->it[i].tex); if (c->destroy_image) c->destroy_image(c->dpy, (EGLImageKHR)c->it[i].image); }
		}
		if (c->fbo) glDeleteFramebuffers(1, &c->fbo);
		if (c->fbo_tex) glDeleteTextures(1, &c->fbo_tex);
		if (c->tmp_tex) glDeleteTextures(1, &c->tmp_tex);
		if (c->tmp_fbo) glDeleteFramebuffers(1, &c->tmp_fbo);
		if (c->blur_prog) glDeleteProgram(c->blur_prog);
		if (c->vbo) glDeleteBuffers(1, &c->vbo);
		if (c->prog) glDeleteProgram(c->prog);
		eglMakeCurrent(c->dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
	}
	if (c->pbuf != EGL_NO_SURFACE) eglDestroySurface(c->dpy, c->pbuf);
	if (c->ctx != EGL_NO_CONTEXT) eglDestroyContext(c->dpy, c->ctx);
	if (c->dpy != EGL_NO_DISPLAY) eglTerminate(c->dpy);
#ifdef WS_GBM
	if (c->gbm) ws_gbm_close(c->gbm);
#endif
	free(c->stage);
	free(c);
}
#endif
