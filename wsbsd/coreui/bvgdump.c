#include <stdio.h>
#include <stdlib.h>
#include "car.h"
#include "bvg.h"
int main(int argc, char **argv)
{
	CarFile *c = car_open(argv[1]); const char *names[1] = { argv[2] }; uint8_t *buf[1] = { 0 }; size_t len[1] = { 0 };
	int w = argc > 3 ? atoi(argv[3]) : 4;
	car_symbols(c, names, 1, w, buf, len); if (!buf[0]) { puts("not found"); return 1; }
	BvgGlyph g; if (bvg_parse(buf[0], len[0], &g)) { puts("parse fail"); return 1; }
	printf("m=%g %g %g %g %g %g layers=%d segs=%d\n", g.m[0], g.m[1], g.m[2], g.m[3], g.m[4], g.m[5], g.nlayer, g.nseg);
	for (int i = 0; i < g.nseg; i++) { BvgSeg *s = &g.seg[i]; printf("%c %g %g %g %g %g %g\n", s->op, s->p[0], s->p[1], s->p[2], s->p[3], s->p[4], s->p[5]); }
	return 0;
}
