#include <stdio.h>
#include <string.h>
#include "../src/vt.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)
static void feed(vt *t, const char *s) { vt_feed(t, s, strlen(s)); }
static char at(vt *t, int x, int y) { return (char)vt_cell_at(t, x, y)->ch; }
static int row_is(vt *t, int y, const char *s) { for (int i = 0; s[i]; i++) if (at(t, i, y) != s[i]) return 0; return 1; }
static char reply_buf[256]; static void writer(void *ctx, const char *d, size_t n) { (void)ctx; if (strlen(reply_buf) + n < sizeof reply_buf) strncat(reply_buf, d, n); }

int main(void)
{
	vt *t = vt_new(20, 5, 100);
	/* text, wrap, newline */
	feed(t, "hello"); CHECK(row_is(t, 0, "hello")); int cx, cy; vt_cursor(t, &cx, &cy, NULL); CHECK(cx == 5 && cy == 0);
	feed(t, "\r\nab"); CHECK(row_is(t, 1, "ab"));
	feed(t, "\r\n12345678901234567890X"); CHECK(row_is(t, 2, "12345678901234567890") && at(t, 0, 3) == 'X');   /* deferred wrap at the right margin */
	/* cursor movement and erase */
	feed(t, "\033[H\033[2J"); CHECK(at(t, 0, 0) == ' ' && at(t, 0, 1) == ' ');
	feed(t, "\033[3;5HZ"); CHECK(at(t, 4, 2) == 'Z');
	feed(t, "\033[1;1HABCDEF\033[1;3H\033[K"); CHECK(row_is(t, 0, "AB") && at(t, 2, 0) == ' ' && at(t, 3, 0) == ' ');
	feed(t, "\033[1;1H\033[2K\033[1;1Hxyz\033[2D\033[P"); CHECK(row_is(t, 0, "xz"));                 /* delete char */
	feed(t, "\033[1;1H\033[2@"); CHECK(at(t, 0, 0) == ' ' && at(t, 2, 0) == 'x');                    /* insert 2 blanks */
	/* SGR: bold red, 256 colours, true colour, reset */
	feed(t, "\033[2J\033[H\033[1;31mR\033[0mn\033[38;5;196mC\033[48;2;1;2;3mT\033[m");
	CHECK((vt_cell_at(t, 0, 0)->attr & VT_BOLD) && vt_cell_at(t, 0, 0)->fg == 0xcd0000);
	CHECK(vt_cell_at(t, 1, 0)->fg == VT_DEFAULT_COLOR && vt_cell_at(t, 1, 0)->attr == 0);
	CHECK(vt_cell_at(t, 2, 0)->fg == vt_palette(196) && vt_cell_at(t, 3, 0)->bg == 0x010203);
	/* scrolling into history and the scroll region */
	vt_free(t); t = vt_new(10, 3, 50);
	feed(t, "one\r\ntwo\r\nthree\r\nfour"); CHECK(row_is(t, 0, "two") && row_is(t, 2, "four") && vt_scrollback_lines(t) == 1 && vt_scrollback_cell(t, 0, 0)->ch == 'o');
	feed(t, "\033[2J\033[H\033[2;3r\033[2;1Ha\r\nb\r\nc"); CHECK(at(t, 0, 1) == 'b' && at(t, 0, 2) == 'c');       /* only rows 2..3 scroll */
	vt_free(t); t = vt_new(10, 3, 50);
	/* alternate screen keeps the primary one */
	feed(t, "keep"); feed(t, "\033[?1049h"); CHECK(vt_alt_screen(t) && at(t, 0, 0) == ' '); feed(t, "alt"); feed(t, "\033[?1049l"); CHECK(!vt_alt_screen(t) && row_is(t, 0, "keep"));
	/* UTF-8, wide characters */
	feed(t, "\033[2J\033[H"); feed(t, "\xc3\xa9\xe4\xb8\xad."); CHECK(vt_cell_at(t, 0, 0)->ch == 0xe9 && vt_cell_at(t, 1, 0)->ch == 0x4e2d && vt_cell_at(t, 1, 0)->wide == 1 && vt_cell_at(t, 2, 0)->wide == 2 && at(t, 3, 0) == '.');
	/* reports */
	vt_set_writer(t, writer, NULL); reply_buf[0] = 0; feed(t, "\033[2;3H\033[6n"); CHECK(strcmp(reply_buf, "\033[2;3R") == 0);
	reply_buf[0] = 0; feed(t, "\033[c"); CHECK(strncmp(reply_buf, "\033[?1;2c", 7) == 0);
	/* modes and title */
	feed(t, "\033[?1h"); CHECK(vt_app_cursor_keys(t)); feed(t, "\033[?1l"); CHECK(!vt_app_cursor_keys(t));
	feed(t, "\033[?25l"); vt_cursor(t, NULL, NULL, &cx); CHECK(cx == 0);
	feed(t, "\033]0;my title\007"); CHECK(strcmp(vt_title(t), "my title") == 0); feed(t, "\033]2;second\033\\"); CHECK(strcmp(vt_title(t), "second") == 0);
	/* tabs, save / restore */
	feed(t, "\033[2J\033[H\tX"); CHECK(at(t, 8, 0) == 'X');
	feed(t, "\033[2J\033[H\033[2;2H\0337\033[1;1H\0338Q"); CHECK(at(t, 1, 1) == 'Q');
	/* resize keeps the cursor visible and the content */
	vt_free(t); t = vt_new(10, 4, 50); feed(t, "a\r\nb\r\nc\r\nd"); vt_resize(t, 12, 2); vt_cursor(t, &cx, &cy, NULL); CHECK(vt_rows(t) == 2 && cy == 1 && at(t, 0, 1) == 'd' && vt_scrollback_lines(t) >= 2);
	/* garbage never crashes: random bytes */
	unsigned s = 12345; char junk[4096]; for (int i = 0; i < 4096; i++) { s = s * 1103515245u + 12345u; junk[i] = (char)(s >> 16); }
	for (int r = 0; r < 50; r++) vt_feed(t, junk, sizeof junk);
	vt_free(t);
	{ /* OSC 133;A (the shell's prompt marks) and the absolute line numbers: the screen has 3 rows, so lines scroll into the history */
		vt *t2 = vt_new(10, 3, 100); const char *s = "\033]133;A\007one\r\ntwo\r\nthree\r\n\033]133;A\007four\r\n";
		vt_feed(t2, s, strlen(s));
		CHECK(vt_prompt_count(t2) == 2 && vt_prompt_at(t2, 0) == 0 && vt_prompt_at(t2, 1) == 3);
		CHECK(vt_scrolled(t2) == 2);
		vt_free(t2);
	}
	if (failures) { printf("%d failures\n", failures); return 1; }
	printf("vt emulator: all checks passed\n");
	return 0;
}
