/* A VT100 / xterm terminal emulator without any UI: a grid of cells, a byte-stream parser (UTF-8, CSI, ESC, OSC), scrollback and an alternate screen.
 * Written from the public xterm control-sequence documentation (ECMA-48, "XTerm Control Sequences"). */
#ifndef VT_H
#define VT_H
#include <stdint.h>
#include <stddef.h>

enum { VT_BOLD = 1, VT_DIM = 2, VT_ITALIC = 4, VT_UNDERLINE = 8, VT_BLINK = 16, VT_INVERSE = 32, VT_HIDDEN = 64, VT_STRIKE = 128 };
#define VT_DEFAULT_COLOR 0xffffffffu            /* colours are 0x00RRGGBB, or this for the default foreground / background */

typedef struct { uint32_t ch; uint32_t fg, bg; uint8_t attr; uint8_t wide; } vt_cell;       /* wide: 1 = first half of a double width character, 2 = its second half */

typedef struct vt vt;
typedef void (*vt_write_fn)(void *ctx, const char *data, size_t n);                       /* answers sent back to the program (cursor position reports, ...) */

vt *vt_new(int cols, int rows, int scrollback);
void vt_free(vt *t);
void vt_set_writer(vt *t, vt_write_fn fn, void *ctx);
void vt_feed(vt *t, const char *data, size_t n);
void vt_resize(vt *t, int cols, int rows);

int vt_cols(const vt *t); int vt_rows(const vt *t);
const vt_cell *vt_cell_at(const vt *t, int col, int row);                                  /* visible screen */
const vt_cell *vt_scrollback_cell(const vt *t, int col, int line_from_newest);            /* history, 0 = the newest line scrolled off */
int vt_scrollback_lines(const vt *t);
void vt_cursor(const vt *t, int *col, int *row, int *visible);
int vt_alt_screen(const vt *t);
const char *vt_title(const vt *t);                                                         /* set by OSC 0 / 2 */
uint32_t vt_dirty_gen(const vt *t);                                                        /* changes whenever the content changes */
int vt_app_cursor_keys(const vt *t);                                                       /* DECCKM: arrows send ESC O A instead of ESC [ A */
int vt_bracketed_paste(const vt *t);
uint32_t vt_palette(int index);                                                            /* the 256 colour palette as 0x00RRGGBB */
#endif
