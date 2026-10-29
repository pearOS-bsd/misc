#include "vt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct { vt_cell *c; } vt_line_unused;

struct vt {
	int cols, rows, max_scroll;
	vt_cell *scr;                         /* rows * cols, the visible screen (primary or alternate) */
	vt_cell *primary, *alt; int on_alt;
	vt_cell *hist; int hist_n, hist_head;  /* ring of scrolled-off lines (cols wide); hist_cols is the width they were stored at */
	int hist_cols;
	int cx, cy, wrap_pending;
	int top, bot;                          /* scroll region (inclusive rows) */
	uint32_t fg, bg; uint8_t attr;         /* current rendition */
	int saved_cx, saved_cy; uint32_t saved_fg, saved_bg; uint8_t saved_attr;
	int cursor_visible, autowrap, origin, insert, app_cursor, bracketed;
	uint8_t *tabs;
	/* parser */
	int state; int params[16]; int nparams; int private_mark; char inter; char osc[256]; int osc_n;
	uint32_t utf; int utf_need;
	vt_write_fn wr; void *wctx;
	char title[256]; char cwd[1024];                                  /* the directory the shell announced with OSC 7 */
	uint32_t gen;
	uint64_t scrolled; uint64_t prompts[2048]; int nprompts;       /* lines pushed into the history so far; absolute line numbers of the prompts the shell announced (OSC 133;A) */
	int mouse_mode, mouse_sgr, focus_events;     /* ?1000 / ?1002 / ?1003 (1, 2, 3), ?1006, ?1004 */
	uint32_t ansi[16]; int has_ansi;       /* the 16 ANSI colours of the profile (else the default palette) */
};

enum { S_GROUND, S_ESC, S_CSI, S_OSC, S_OSC_ESC, S_ESC_INTER, S_DCS };

uint32_t vt_palette(int i)
{
	static const uint32_t base[16] = { 0x000000, 0xcd0000, 0x00cd00, 0xcdcd00, 0x0000ee, 0xcd00cd, 0x00cdcd, 0xe5e5e5, 0x7f7f7f, 0xff0000, 0x00ff00, 0xffff00, 0x5c5cff, 0xff00ff, 0x00ffff, 0xffffff };
	if (i < 0) i = 0;
	if (i < 16) return base[i];
	if (i < 232) { int k = i - 16, r = k / 36, g = (k / 6) % 6, b = k % 6; static const int lv[6] = { 0, 95, 135, 175, 215, 255 }; return (uint32_t)(lv[r] << 16 | lv[g] << 8 | lv[b]); }
	if (i < 256) { int v = 8 + (i - 232) * 10; return (uint32_t)(v << 16 | v << 8 | v); }
	return 0xffffff;
}

static uint32_t pal(const vt *t, int i) { return (t->has_ansi && i >= 0 && i < 16) ? t->ansi[i] : vt_palette(i); }
void vt_set_ansi(vt *t, const uint32_t c[16]) { memcpy(t->ansi, c, sizeof t->ansi); t->has_ansi = 1; t->gen++; }

int vt_mouse_mode(const vt *t) { return t->mouse_mode; }
int vt_mouse_sgr(const vt *t) { return t->mouse_sgr; }
int vt_focus_events(const vt *t) { return t->focus_events; }
void vt_clear_scrollback(vt *t) { t->hist_n = 0; t->gen++; }

static vt_cell blank(const vt *t) { vt_cell c = { ' ', VT_DEFAULT_COLOR, t->bg, 0, 0 }; return c; }
static vt_cell *cell(const vt *t, int x, int y) { return &t->scr[(size_t)y * t->cols + x]; }
static void clear_cells(vt *t, int x0, int y0, int x1, int y1)       /* inclusive start, exclusive end in row-major order */
{
	vt_cell b = blank(t);
	for (int i = y0 * t->cols + x0; i < y1 * t->cols + x1 && i < t->rows * t->cols; i++) t->scr[i] = b;
}

vt *vt_new(int cols, int rows, int scrollback)
{
	vt *t = calloc(1, sizeof *t);
	if (!t) return NULL;
	t->cols = cols > 0 ? cols : 80; t->rows = rows > 0 ? rows : 24; t->max_scroll = scrollback < 0 ? 0 : scrollback;
	t->primary = calloc((size_t)t->cols * t->rows, sizeof(vt_cell)); t->alt = calloc((size_t)t->cols * t->rows, sizeof(vt_cell));
	t->hist = t->max_scroll ? calloc((size_t)t->cols * t->max_scroll, sizeof(vt_cell)) : NULL; t->hist_cols = t->cols;
	t->tabs = calloc((size_t)t->cols, 1);
	if (!t->primary || !t->alt || !t->tabs) { vt_free(t); return NULL; }
	t->scr = t->primary;
	t->fg = VT_DEFAULT_COLOR; t->bg = VT_DEFAULT_COLOR; t->top = 0; t->bot = t->rows - 1; t->cursor_visible = 1; t->autowrap = 1;
	for (int i = 0; i < t->cols; i += 8) t->tabs[i] = 1;
	clear_cells(t, 0, 0, t->cols, t->rows);
	vt_cell *save = t->scr; t->scr = t->alt; clear_cells(t, 0, 0, t->cols, t->rows); t->scr = save;
	return t;
}
void vt_free(vt *t) { if (!t) return; free(t->primary); free(t->alt); free(t->hist); free(t->tabs); free(t); }
void vt_set_writer(vt *t, vt_write_fn fn, void *ctx) { t->wr = fn; t->wctx = ctx; }
int vt_cols(const vt *t) { return t->cols; }
int vt_rows(const vt *t) { return t->rows; }
const vt_cell *vt_cell_at(const vt *t, int x, int y) { return (x < 0 || y < 0 || x >= t->cols || y >= t->rows) ? NULL : cell(t, x, y); }
void vt_cursor(const vt *t, int *c, int *r, int *v) { if (c) *c = t->cx; if (r) *r = t->cy; if (v) *v = t->cursor_visible; }
int vt_alt_screen(const vt *t) { return t->on_alt; }
const char *vt_title(const vt *t) { return t->title; }
const char *vt_cwd(const vt *t) { return t->cwd; }
uint32_t vt_dirty_gen(const vt *t) { return t->gen; }
int vt_app_cursor_keys(const vt *t) { return t->app_cursor; }
int vt_bracketed_paste(const vt *t) { return t->bracketed; }
int vt_scrollback_lines(const vt *t) { return t->hist_n; }
const vt_cell *vt_scrollback_cell(const vt *t, int x, int line)
{
	if (!t->hist || line < 0 || line >= t->hist_n || x < 0 || x >= t->hist_cols) return NULL;
	int idx = (t->hist_head - 1 - line + t->max_scroll * 2) % t->max_scroll;
	return &t->hist[(size_t)idx * t->hist_cols + x];
}

static void push_history(vt *t, int y)
{
	if (!t->hist || t->on_alt || t->hist_cols != t->cols) return;
	memcpy(&t->hist[(size_t)t->hist_head * t->cols], cell(t, 0, y), (size_t)t->cols * sizeof(vt_cell));
	t->hist_head = (t->hist_head + 1) % t->max_scroll;
	if (t->hist_n < t->max_scroll) t->hist_n++;
	t->scrolled++;
}

static void scroll_up(vt *t, int n)                                   /* the scroll region moves up: lines at the top are lost (kept in history for a full-screen region) */
{
	if (n > t->bot - t->top + 1) n = t->bot - t->top + 1;
	for (int k = 0; k < n; k++) {
		if (t->top == 0) push_history(t, 0);
		memmove(cell(t, 0, t->top), cell(t, 0, t->top + 1), (size_t)(t->bot - t->top) * t->cols * sizeof(vt_cell));
		clear_cells(t, 0, t->bot, t->cols, t->bot + 1);
	}
}
static void scroll_down(vt *t, int n)
{
	if (n > t->bot - t->top + 1) n = t->bot - t->top + 1;
	for (int k = 0; k < n; k++) {
		memmove(cell(t, 0, t->top + 1), cell(t, 0, t->top), (size_t)(t->bot - t->top) * t->cols * sizeof(vt_cell));
		clear_cells(t, 0, t->top, t->cols, t->top + 1);
	}
}

static void linefeed(vt *t) { if (t->cy == t->bot) scroll_up(t, 1); else if (t->cy < t->rows - 1) t->cy++; }

static int is_wide(uint32_t c) { return (c >= 0x1100 && c <= 0x115f) || (c >= 0x2e80 && c <= 0xa4cf) || (c >= 0xac00 && c <= 0xd7a3) || (c >= 0xf900 && c <= 0xfaff) || (c >= 0xfe30 && c <= 0xfe6f) || (c >= 0xff00 && c <= 0xff60) || (c >= 0xffe0 && c <= 0xffe6) || (c >= 0x1f300 && c <= 0x1faff) || (c >= 0x20000 && c <= 0x3fffd); }

static void put_char(vt *t, uint32_t ch)
{
	int w = is_wide(ch) ? 2 : 1;
	if (t->wrap_pending && t->autowrap) { t->cx = 0; linefeed(t); }
	t->wrap_pending = 0;
	if (t->cx + w > t->cols) { if (t->autowrap) { t->cx = 0; linefeed(t); } else t->cx = t->cols - w; }
	if (t->insert) { vt_cell *row = cell(t, 0, t->cy); memmove(&row[t->cx + w], &row[t->cx], (size_t)(t->cols - t->cx - w) * sizeof(vt_cell)); }
	vt_cell *c = cell(t, t->cx, t->cy);
	c->ch = ch; c->fg = t->fg; c->bg = t->bg; c->attr = t->attr; c->wide = w == 2;
	if (w == 2) { vt_cell *d = cell(t, t->cx + 1, t->cy); d->ch = ' '; d->fg = t->fg; d->bg = t->bg; d->attr = t->attr; d->wide = 2; }
	t->cx += w;
	if (t->cx >= t->cols) { t->cx = t->cols - 1; t->wrap_pending = 1; }
}

static void reply(vt *t, const char *s) { if (t->wr) t->wr(t->wctx, s, strlen(s)); }
static int param(const vt *t, int i, int def) { return (i < t->nparams && t->params[i] > 0) ? t->params[i] : def; }
static void goto_xy(vt *t, int x, int y)
{
	if (t->origin) { y += t->top; if (y > t->bot) y = t->bot; } else if (y >= t->rows) y = t->rows - 1;
	if (x >= t->cols) x = t->cols - 1; if (x < 0) x = 0; if (y < 0) y = 0;
	t->cx = x; t->cy = y; t->wrap_pending = 0;
}

static void sgr(vt *t)
{
	if (t->nparams == 0) { t->fg = VT_DEFAULT_COLOR; t->bg = VT_DEFAULT_COLOR; t->attr = 0; return; }
	for (int i = 0; i < t->nparams; i++) {
		int p = t->params[i] < 0 ? 0 : t->params[i];
		if (p == 0) { t->fg = VT_DEFAULT_COLOR; t->bg = VT_DEFAULT_COLOR; t->attr = 0; }
		else if (p == 1) t->attr |= VT_BOLD; else if (p == 2) t->attr |= VT_DIM; else if (p == 3) t->attr |= VT_ITALIC; else if (p == 4) t->attr |= VT_UNDERLINE;
		else if (p == 5 || p == 6) t->attr |= VT_BLINK; else if (p == 7) t->attr |= VT_INVERSE; else if (p == 8) t->attr |= VT_HIDDEN; else if (p == 9) t->attr |= VT_STRIKE;
		else if (p == 22) t->attr &= (uint8_t)~(VT_BOLD | VT_DIM); else if (p == 23) t->attr &= (uint8_t)~VT_ITALIC; else if (p == 24) t->attr &= (uint8_t)~VT_UNDERLINE;
		else if (p == 25) t->attr &= (uint8_t)~VT_BLINK; else if (p == 27) t->attr &= (uint8_t)~VT_INVERSE; else if (p == 28) t->attr &= (uint8_t)~VT_HIDDEN; else if (p == 29) t->attr &= (uint8_t)~VT_STRIKE;
		else if (p >= 30 && p <= 37) t->fg = pal(t, p - 30); else if (p == 39) t->fg = VT_DEFAULT_COLOR;
		else if (p >= 40 && p <= 47) t->bg = pal(t, p - 40); else if (p == 49) t->bg = VT_DEFAULT_COLOR;
		else if (p >= 90 && p <= 97) t->fg = pal(t, p - 90 + 8); else if (p >= 100 && p <= 107) t->bg = pal(t, p - 100 + 8);
		else if (p == 38 || p == 48) {
			uint32_t col = VT_DEFAULT_COLOR;
			if (i + 2 < t->nparams && t->params[i + 1] == 5) { col = pal(t, t->params[i + 2] & 0xff); i += 2; }
			else if (i + 4 < t->nparams && t->params[i + 1] == 2) { col = (uint32_t)((t->params[i + 2] & 0xff) << 16 | (t->params[i + 3] & 0xff) << 8 | (t->params[i + 4] & 0xff)); i += 4; }
			if (p == 38) t->fg = col; else t->bg = col;
		}
	}
}

static void switch_alt(vt *t, int on)
{
	if (on == t->on_alt) return;
	t->on_alt = on; t->scr = on ? t->alt : t->primary;
	if (on) { t->saved_cx = t->cx; t->saved_cy = t->cy; clear_cells(t, 0, 0, t->cols, t->rows); t->cx = t->cy = 0; }
	else { t->cx = t->saved_cx; t->cy = t->saved_cy; }
	t->top = 0; t->bot = t->rows - 1; t->wrap_pending = 0;
}

static void set_mode(vt *t, int on)
{
	for (int i = 0; i < (t->nparams ? t->nparams : 1); i++) {
		int p = t->params[i];
		if (t->private_mark == '?') {
			if (p == 1) t->app_cursor = on; else if (p == 6) { t->origin = on; goto_xy(t, 0, 0); } else if (p == 7) t->autowrap = on; else if (p == 25) t->cursor_visible = on;
			else if (p == 47 || p == 1047 || p == 1049) switch_alt(t, on); else if (p == 2004) t->bracketed = on;
			else if (p == 1000 || p == 1002 || p == 1003) t->mouse_mode = on ? (p == 1000 ? 1 : p == 1002 ? 2 : 3) : 0; else if (p == 1006) t->mouse_sgr = on; else if (p == 1004) t->focus_events = on;
		} else if (p == 4) t->insert = on;
	}
}

static void csi(vt *t, char final)
{
	int n = param(t, 0, 1), c;
	switch (final) {
	case 'A': goto_xy(t, t->cx, (t->cy - n < (t->origin ? t->top : 0) ? (t->origin ? t->top : 0) : t->cy - n) - (t->origin ? t->top : 0)); break;
	case 'B': case 'e': { int y = t->cy + n; if (y > t->bot && t->cy <= t->bot) y = t->bot; if (y >= t->rows) y = t->rows - 1; t->cy = y; t->wrap_pending = 0; break; }
	case 'C': case 'a': t->cx += n; if (t->cx >= t->cols) t->cx = t->cols - 1; t->wrap_pending = 0; break;
	case 'D': t->cx -= n; if (t->cx < 0) t->cx = 0; t->wrap_pending = 0; break;
	case 'E': t->cx = 0; t->cy += n; if (t->cy >= t->rows) t->cy = t->rows - 1; t->wrap_pending = 0; break;
	case 'F': t->cx = 0; t->cy -= n; if (t->cy < 0) t->cy = 0; t->wrap_pending = 0; break;
	case 'G': case '`': goto_xy(t, param(t, 0, 1) - 1, t->cy - (t->origin ? t->top : 0)); break;
	case 'H': case 'f': goto_xy(t, param(t, 1, 1) - 1, param(t, 0, 1) - 1); break;
	case 'd': goto_xy(t, t->cx, param(t, 0, 1) - 1); break;
	case 'J': c = t->nparams ? t->params[0] : 0;
		if (c == 0) clear_cells(t, t->cx, t->cy, t->cols, t->rows); else if (c == 1) clear_cells(t, 0, 0, t->cx + 1, t->cy), clear_cells(t, 0, t->cy, t->cx + 1, t->cy + 1);
		else if (c == 2 || c == 3) clear_cells(t, 0, 0, t->cols, t->rows);
		if (c == 3) t->hist_n = 0;
		break;
	case 'K': c = t->nparams ? t->params[0] : 0;
		if (c == 0) clear_cells(t, t->cx, t->cy, t->cols, t->cy + 1); else if (c == 1) clear_cells(t, 0, t->cy, t->cx + 1, t->cy + 1); else if (c == 2) clear_cells(t, 0, t->cy, t->cols, t->cy + 1);
		break;
	case 'L': if (t->cy >= t->top && t->cy <= t->bot) { int s = t->top; t->top = t->cy; scroll_down(t, n); t->top = s; } break;
	case 'M': if (t->cy >= t->top && t->cy <= t->bot) { int s = t->top; t->top = t->cy; { int keep = t->on_alt; t->on_alt = 1; scroll_up(t, n); t->on_alt = keep; } t->top = s; } break;   /* deleted lines are not history */
	case '@': { vt_cell *row = cell(t, 0, t->cy); if (n > t->cols - t->cx) n = t->cols - t->cx; memmove(&row[t->cx + n], &row[t->cx], (size_t)(t->cols - t->cx - n) * sizeof(vt_cell)); clear_cells(t, t->cx, t->cy, t->cx + n, t->cy); break; }
	case 'P': { vt_cell *row = cell(t, 0, t->cy); if (n > t->cols - t->cx) n = t->cols - t->cx; memmove(&row[t->cx], &row[t->cx + n], (size_t)(t->cols - t->cx - n) * sizeof(vt_cell)); clear_cells(t, t->cols - n, t->cy, t->cols, t->cy); break; }
	case 'X': if (n > t->cols - t->cx) n = t->cols - t->cx; clear_cells(t, t->cx, t->cy, t->cx + n, t->cy); break;
	case 'S': scroll_up(t, n); break;
	case 'T': scroll_down(t, n); break;
	case 'm': sgr(t); break;
	case 'h': set_mode(t, 1); break;
	case 'l': set_mode(t, 0); break;
	case 'r': { int top = param(t, 0, 1) - 1, bot = param(t, 1, t->rows) - 1; if (bot >= t->rows) bot = t->rows - 1; if (top < bot) { t->top = top; t->bot = bot; goto_xy(t, 0, 0); } break; }
	case 's': t->saved_cx = t->cx; t->saved_cy = t->cy; break;
	case 'u': t->cx = t->saved_cx; t->cy = t->saved_cy; break;
	case 'g': if (!t->nparams || t->params[0] == 0) t->tabs[t->cx] = 0; else if (t->params[0] == 3) memset(t->tabs, 0, (size_t)t->cols); break;
	case 'n': c = t->nparams ? t->params[0] : 0;
		if (c == 5) reply(t, "\033[0n"); else if (c == 6) { char b[32]; snprintf(b, sizeof b, "\033[%d;%dR", t->cy + 1 - (t->origin ? t->top : 0), t->cx + 1); reply(t, b); }
		break;
	case 'c': if (!t->private_mark) reply(t, "\033[?1;2c"); break;
	default: break;
	}
}

static void esc(vt *t, char c)
{
	switch (c) {
	case 'D': linefeed(t); break;
	case 'E': t->cx = 0; linefeed(t); break;
	case 'M': if (t->cy == t->top) scroll_down(t, 1); else if (t->cy > 0) t->cy--; break;
	case '7': t->saved_cx = t->cx; t->saved_cy = t->cy; t->saved_fg = t->fg; t->saved_bg = t->bg; t->saved_attr = t->attr; break;
	case '8': t->cx = t->saved_cx; t->cy = t->saved_cy; t->fg = t->saved_fg; t->bg = t->saved_bg; t->attr = t->saved_attr; t->wrap_pending = 0; break;
	case 'H': t->tabs[t->cx] = 1; break;
	case 'c': t->fg = t->bg = VT_DEFAULT_COLOR; t->attr = 0; t->top = 0; t->bot = t->rows - 1; clear_cells(t, 0, 0, t->cols, t->rows); t->cx = t->cy = 0; t->cursor_visible = 1; t->autowrap = 1; t->origin = 0; t->insert = 0; break;
	default: break;
	}
}

static void ground(vt *t, uint8_t b)
{
	if (t->utf_need) {
		if ((b & 0xc0) == 0x80) { t->utf = (t->utf << 6) | (b & 0x3f); if (--t->utf_need == 0) put_char(t, t->utf); return; }
		t->utf_need = 0;                                            /* malformed: drop what we had and treat b afresh */
	}
	if (b >= 0x20 && b < 0x7f) { put_char(t, b); return; }
	if (b >= 0xc2 && b <= 0xf4) { t->utf = b >= 0xf0 ? (b & 0x07) : b >= 0xe0 ? (b & 0x0f) : (b & 0x1f); t->utf_need = b >= 0xf0 ? 3 : b >= 0xe0 ? 2 : 1; return; }
	switch (b) {
	case 0x07: break;
	case 0x08: if (t->cx > 0) t->cx--; t->wrap_pending = 0; break;
	case 0x09: { int x = t->cx + 1; while (x < t->cols - 1 && !t->tabs[x]) x++; t->cx = x >= t->cols ? t->cols - 1 : x; t->wrap_pending = 0; break; }
	case 0x0a: case 0x0b: case 0x0c: linefeed(t); t->wrap_pending = 0; break;
	case 0x0d: t->cx = 0; t->wrap_pending = 0; break;
	case 0x1b: t->state = S_ESC; break;
	default: break;
	}
}

static void osc_done(vt *t)
{
	t->osc[t->osc_n < 255 ? t->osc_n : 255] = 0; int code = atoi(t->osc); char *semi = strchr(t->osc, ';');
	if (semi && (code == 0 || code == 2)) snprintf(t->title, sizeof t->title, "%s", semi + 1);
	else if (semi && code == 7 && !strncmp(semi + 1, "file://", 7)) {         /* the shell's working directory: file://host/path, percent-encoded */
		const char *u = strchr(semi + 8, '/'); size_t n = 0; if (!u) return;
		for (; *u && n < sizeof t->cwd - 1; u++) { if (*u == '%' && isxdigit((unsigned char)u[1]) && isxdigit((unsigned char)u[2])) { char h[3] = { u[1], u[2], 0 }; t->cwd[n++] = (char)strtol(h, NULL, 16); u += 2; } else t->cwd[n++] = *u; }
		t->cwd[n] = 0; t->gen++;
	}
	else if (semi && code == 133 && semi[1] == 'A') {                  /* the shell integration: a prompt starts on this line */
		uint64_t abs = t->scrolled + (uint64_t)t->cy;
		if (!t->nprompts || t->prompts[t->nprompts - 1] != abs) { if (t->nprompts == 2048) { memmove(t->prompts, t->prompts + 1, 2047 * sizeof t->prompts[0]); t->nprompts--; } t->prompts[t->nprompts++] = abs; }
	}
}
uint64_t vt_scrolled(const vt *t) { return t->scrolled; }
int vt_prompt_count(const vt *t) { return t->nprompts; }
uint64_t vt_prompt_at(const vt *t, int i) { return t->prompts[i]; }

void vt_feed(vt *t, const char *data, size_t n)
{
	for (size_t i = 0; i < n; i++) {
		uint8_t b = (uint8_t)data[i];
		switch (t->state) {
		case S_GROUND: ground(t, b); break;
		case S_ESC:
			if (b == '[') { t->state = S_CSI; t->nparams = 0; t->private_mark = 0; memset(t->params, 0, sizeof t->params); t->inter = 0; t->params[0] = -1; }
			else if (b == ']') { t->state = S_OSC; t->osc_n = 0; }
			else if (b == 'P' || b == '_' || b == '^' || b == 'X') t->state = S_DCS;
			else if (b == '(' || b == ')' || b == '*' || b == '+' || b == '#' || b == '%') t->state = S_ESC_INTER;
			else { esc(t, (char)b); t->state = S_GROUND; }
			break;
		case S_ESC_INTER: t->state = S_GROUND; break;
		case S_CSI:
			if (b >= '0' && b <= '9') { if (t->nparams == 0) t->nparams = 1; int *p = &t->params[t->nparams - 1]; *p = (*p < 0 ? 0 : *p) * 10 + (b - '0'); if (*p > 99999) *p = 99999; }
			else if (b == ';') { if (t->nparams == 0) t->nparams = 1; if (t->nparams < 16) { t->nparams++; t->params[t->nparams - 1] = -1; } }
			else if (b == '?' || b == '>' || b == '=' || b == '<') t->private_mark = b;
			else if (b >= 0x20 && b <= 0x2f) t->inter = (char)b;
			else if (b >= 0x40 && b <= 0x7e) { if (t->nparams == 0) t->params[0] = -1; csi(t, (char)b); t->state = S_GROUND; }
			else if (b == 0x1b) t->state = S_ESC; else if (b < 0x20) ground(t, b);
			break;
		case S_OSC:
			if (b == 0x07) { osc_done(t); t->state = S_GROUND; }
			else if (b == 0x1b) t->state = S_OSC_ESC; else if (t->osc_n < 255) t->osc[t->osc_n++] = (char)b;
			break;
		case S_OSC_ESC: osc_done(t); t->state = b == '\\' ? S_GROUND : S_ESC; break;
		case S_DCS: if (b == 0x1b) t->state = S_OSC_ESC, t->osc_n = 0; else if (b == 0x07) t->state = S_GROUND; break;
		}
	}
	t->gen++;
}

void vt_resize(vt *t, int cols, int rows)
{
	if (cols < 1 || rows < 1 || (cols == t->cols && rows == t->rows)) return;
	vt_cell *np = calloc((size_t)cols * rows, sizeof(vt_cell)), *na = calloc((size_t)cols * rows, sizeof(vt_cell));
	uint8_t *nt = calloc((size_t)cols, 1);
	if (!np || !na || !nt) { free(np); free(na); free(nt); return; }
	vt_cell b = { ' ', VT_DEFAULT_COLOR, VT_DEFAULT_COLOR, 0, 0 };
	for (int i = 0; i < cols * rows; i++) np[i] = na[i] = b;
	int copy_rows = rows < t->rows ? rows : t->rows, copy_cols = cols < t->cols ? cols : t->cols;
	int shift = t->cy >= rows ? t->cy - rows + 1 : 0;                           /* the cursor stays visible: the top lines go to history */
	if (!t->on_alt) for (int y = 0; y < shift; y++) push_history(t, y);
	for (int y = 0; y < copy_rows; y++) {
		int sy = y + shift; if (sy >= t->rows) break;
		memcpy(&np[(size_t)y * cols], &t->primary[(size_t)sy * t->cols], (size_t)copy_cols * sizeof(vt_cell));
		memcpy(&na[(size_t)y * cols], &t->alt[(size_t)sy * t->cols], (size_t)copy_cols * sizeof(vt_cell));
	}
	free(t->primary); free(t->alt); free(t->tabs);
	t->primary = np; t->alt = na; t->tabs = nt; t->scr = t->on_alt ? t->alt : t->primary;
	for (int i = 0; i < cols; i += 8) t->tabs[i] = 1;
	if (t->hist && t->hist_cols != cols) {                                  /* history lines are re-stored at the new width (padded or cut), oldest first */
		vt_cell *nh = calloc((size_t)cols * t->max_scroll, sizeof(vt_cell));
		if (nh) {
			vt_cell blankc = { ' ', VT_DEFAULT_COLOR, VT_DEFAULT_COLOR, 0, 0 };
			for (int k = 0; k < t->hist_n; k++) {
				int idx = (t->hist_head - t->hist_n + k + t->max_scroll * 2) % t->max_scroll;
				for (int x = 0; x < cols; x++) nh[(size_t)k * cols + x] = x < t->hist_cols ? t->hist[(size_t)idx * t->hist_cols + x] : blankc;
			}
			free(t->hist); t->hist = nh; t->hist_head = t->hist_n % t->max_scroll; t->hist_cols = cols;
		}
	}
	t->cols = cols; t->rows = rows; t->cy -= shift; if (t->cy < 0) t->cy = 0; if (t->cx >= cols) t->cx = cols - 1; if (t->cy >= rows) t->cy = rows - 1;
	t->top = 0; t->bot = rows - 1; t->wrap_pending = 0; t->gen++;
}
