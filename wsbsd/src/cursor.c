/* Standard cursor shapes, drawn procedurally: polygons on a 24x24 grid, 4x4 supersampled, black fill with a white outline (the hand is white with a black outline). */
#include <math.h>
#include <string.h>
#include "ws.h"

#define CS 32
#define OFF 4.0f
typedef struct { float x[12], y[12]; int n; } poly;
typedef struct { poly p[16]; int n; } shape;

static void add(shape *s, int n, const float *xy) { poly *p = &s->p[s->n++]; p->n = n; for (int i = 0; i < n; i++) { p->x[i] = xy[2 * i]; p->y[i] = xy[2 * i + 1]; } }
static void rect(shape *s, float x0, float y0, float x1, float y1) { float v[] = { x0, y0, x1, y0, x1, y1, x0, y1 }; add(s, 4, v); }
static void tri(shape *s, float a, float b, float c, float d, float e, float f) { float v[] = { a, b, c, d, e, f }; add(s, 3, v); }
static void rotate(shape *s, int from, float deg)
{
	float c = cosf(deg * 3.14159265f / 180), sn = sinf(deg * 3.14159265f / 180);
	for (int i = from; i < s->n; i++) for (int k = 0; k < s->p[i].n; k++) {
		float x = s->p[i].x[k] - 12, y = s->p[i].y[k] - 12;
		s->p[i].x[k] = 12 + x * c - y * sn; s->p[i].y[k] = 12 + x * sn + y * c;
	}
}
static void harrow(shape *s) { rect(s, 5, 11, 19, 13); tri(s, 1, 12, 7.5f, 7, 7.5f, 17); tri(s, 23, 12, 16.5f, 7, 16.5f, 17); }
static int inside(const poly *p, float x, float y)
{
	int c = 0;
	for (int i = 0, j = p->n - 1; i < p->n; j = i++)
		if (((p->y[i] > y) != (p->y[j] > y)) && (x < (p->x[j] - p->x[i]) * (y - p->y[i]) / (p->y[j] - p->y[i]) + p->x[i])) c = !c;
	return c;
}

/* shapes: 0 arrow, 1 I-beam, 2 pointing hand, 3 crosshair, 4 resize left-right, 5 resize up-down, 6 resize NW-SE, 7 resize NE-SW, 8 open hand, 9 closed hand, 10 move */
int ws_cursor_shape_count(void) { return 11; }

static void build(shape *s, int k, int *hx, int *hy, int *dark)
{
	memset(s, 0, sizeof *s); *hx = *hy = 12; *dark = 1;
	switch (k) {
	case 1: rect(s, 11, 3, 13, 21); rect(s, 8, 3, 16, 4.6f); rect(s, 8, 19.4f, 16, 21); break;
	case 2: *dark = 0; *hx = 9; *hy = 3; rect(s, 8, 3, 11, 13); rect(s, 5, 12, 19, 21); rect(s, 11, 9, 13.5f, 13); rect(s, 13.5f, 10, 16, 13); rect(s, 16, 11, 18.5f, 13); rect(s, 2.5f, 11, 5.5f, 16); break;
	case 3: rect(s, 11, 2, 13, 22); rect(s, 2, 11, 22, 13); break;
	case 4: harrow(s); break;
	case 5: harrow(s); rotate(s, 0, 90); break;
	case 6: harrow(s); rotate(s, 0, 45); break;
	case 7: harrow(s); rotate(s, 0, -45); break;
	case 8: *dark = 0; rect(s, 6, 11, 18, 21); rect(s, 6, 5, 8.2f, 12); rect(s, 8.7f, 3, 10.9f, 12); rect(s, 11.4f, 3.5f, 13.6f, 12); rect(s, 14.1f, 5, 16.3f, 12); rect(s, 16.8f, 8, 19, 15); break;
	case 9: *dark = 0; rect(s, 6, 10, 18, 21); rect(s, 6.5f, 8, 17.5f, 11); break;
	case 10: { harrow(s); int n = s->n; harrow(s); rotate(s, n, 90); break; }
	}
}

ws_surface *ws_cursor_shape_image(int k, int *hx, int *hy)
{
	if (k < 1 || k >= ws_cursor_shape_count()) return NULL;
	shape s; int dark; build(&s, k, hx, hy, &dark);
	ws_surface *img = ws_surface_new(CS, CS);
	if (!img) return NULL;
	static float cov[CS][CS];
	for (int y = 0; y < CS; y++) for (int x = 0; x < CS; x++) {
		int n = 0;
		for (int sy = 0; sy < 4; sy++) for (int sx = 0; sx < 4; sx++) {
			float fx = x - OFF + (sx + 0.5f) / 4, fy = y - OFF + (sy + 0.5f) / 4;
			for (int i = 0; i < s.n; i++) if (inside(&s.p[i], fx, fy)) { n++; break; }
		}
		cov[y][x] = n / 16.0f;
	}
	for (int y = 0; y < CS; y++) for (int x = 0; x < CS; x++) {
		float fo = cov[y][x], ou = 0;                                   /* outline: the strongest coverage within a radius of 1.2 px */
		for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
			int xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= CS || yy >= CS) continue;
			float w = (dx * dx + dy * dy) > 1.5f ? 0.7f : 1.0f; if (cov[yy][xx] * w > ou) ou = cov[yy][xx] * w;
		}
		float ring = ou * (1 - fo);
		float a = fo + ring; if (a > 1) a = 1;
		float body = dark ? 0.0f : 1.0f, edge = dark ? 1.0f : 0.0f;
		float v = fo * body + ring * edge;                              /* premultiplied */
		uint8_t *d = img->px + (size_t)y * img->stride + (size_t)x * 4;
		d[0] = d[1] = d[2] = (uint8_t)(v * 255.0f + 0.5f); d[3] = (uint8_t)(a * 255.0f + 0.5f);
	}
	*hx += (int)OFF; *hy += (int)OFF;
	return img;
}
