#import <Foundation/Foundation.h>
#include <string.h>
#include "DockRender.h"
#include <math.h>

static void SetRGB(CGContextRef c, double r, double g, double b, double a) { CGContextSetRGBFillColor(c, r, g, b, a); CGContextSetRGBStrokeColor(c, r, g, b, a); }

static CGPathRef RoundRectPath(CGRect r, CGFloat rx)
{
	CGMutablePathRef p = CGPathCreateMutable(); CGFloat x0 = CGRectGetMinX(r), x1 = CGRectGetMaxX(r), y0 = CGRectGetMinY(r), y1 = CGRectGetMaxY(r);
	if (rx * 2 > r.size.height) rx = r.size.height / 2; if (rx * 2 > r.size.width) rx = r.size.width / 2;
	CGPathMoveToPoint(p, NULL, x0 + rx, y0); CGPathAddLineToPoint(p, NULL, x1 - rx, y0); CGPathAddArc(p, NULL, x1 - rx, y0 + rx, rx, -M_PI / 2, 0, 0);
	CGPathAddLineToPoint(p, NULL, x1, y1 - rx); CGPathAddArc(p, NULL, x1 - rx, y1 - rx, rx, 0, M_PI / 2, 0);
	CGPathAddLineToPoint(p, NULL, x0 + rx, y1); CGPathAddArc(p, NULL, x0 + rx, y1 - rx, rx, M_PI / 2, M_PI, 0);
	CGPathAddLineToPoint(p, NULL, x0, y0 + rx); CGPathAddArc(p, NULL, x0 + rx, y0 + rx, rx, M_PI, 3 * M_PI / 2, 0);
	CGPathCloseSubpath(p); return p;
}

/* a rounded rectangle with continuous corners (the superellipse of Core Animation's .continuous curve, approximated by Bezier curves that reach 1.5286 r along the sides) */
static CGPathRef ContinuousRect(CGRect r, CGFloat rad)
{
	CGMutablePathRef p = CGPathCreateMutable();
	CGFloat k = rad * 1.528665, xmin = CGRectGetMinX(r), xmax = CGRectGetMaxX(r), ymin = CGRectGetMinY(r), ymax = CGRectGetMaxY(r);
	if (k * 2 > r.size.width) k = r.size.width / 2; if (k * 2 > r.size.height) k = r.size.height / 2;
	CGFloat c1 = k * 0.0, c2 = k * 0.37, c3 = k * 0.63;                   /* control offsets of a smooth corner */
	(void)c1;
	CGPathMoveToPoint(p, NULL, xmin + k, ymin);
	CGPathAddLineToPoint(p, NULL, xmax - k, ymin);
	CGPathAddCurveToPoint(p, NULL, xmax - c2, ymin, xmax, ymin + c2, xmax, ymin + k);
	CGPathAddLineToPoint(p, NULL, xmax, ymax - k);
	CGPathAddCurveToPoint(p, NULL, xmax, ymax - c2, xmax - c2, ymax, xmax - k, ymax);
	CGPathAddLineToPoint(p, NULL, xmin + k, ymax);
	CGPathAddCurveToPoint(p, NULL, xmin + c2, ymax, xmin, ymax - c2, xmin, ymax - k);
	CGPathAddLineToPoint(p, NULL, xmin, ymin + k);
	CGPathAddCurveToPoint(p, NULL, xmin, ymin + c2, xmin + c2, ymin, xmin + k, ymin);
	CGPathCloseSubpath(p);
	(void)c3;
	return p;
}

void DockDrawIcon(CGContextRef c, const char *glyph, CGRect r)
{
	CGContextSaveGState(c);
	CGFloat s = r.size.width;
	CGPathRef sq = ContinuousRect(r, s * 0.2237);
	CGContextAddPath(c, sq); CGContextClip(c);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	struct { const char *g; CGFloat top[3], bot[3]; } styles[] = {
		{ "finder",    { 0.40, 0.80, 1.00 }, { 0.00, 0.45, 0.95 } }, { "terminal", { 0.20, 0.20, 0.22 }, { 0.04, 0.04, 0.05 } }, { "settings", { 0.78, 0.78, 0.80 }, { 0.50, 0.50, 0.53 } },
		{ "launchpad", { 0.96, 0.96, 0.97 }, { 0.80, 0.80, 0.83 } }, { "doc", { 1, 1, 1 }, { 0.90, 0.92, 0.95 } }, { "folder", { 0.45, 0.78, 0.98 }, { 0.20, 0.58, 0.92 } },
		{ "trash", { 0.78, 0.80, 0.84 }, { 0.58, 0.60, 0.65 } }, { "generic", { 0.55, 0.60, 0.95 }, { 0.30, 0.30, 0.80 } } };
	int si = 7; for (int i = 0; i < 8; i++) if (glyph && !strcmp(glyph, styles[i].g)) si = i;
	CGFloat comps[8] = { styles[si].top[0], styles[si].top[1], styles[si].top[2], 1, styles[si].bot[0], styles[si].bot[1], styles[si].bot[2], 1 };
	CGFloat locs[2] = { 0, 1 };
	CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, locs, 2);
	CGContextDrawLinearGradient(c, g, CGPointMake(r.origin.x, r.origin.y + s), CGPointMake(r.origin.x, r.origin.y), 0);
	CGGradientRelease(g); CGColorSpaceRelease(cs);
	CGFloat u = s / 100.0, ox = r.origin.x, oy = r.origin.y;
	CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
	if (!strcmp(glyph ? glyph : "", "finder")) {
		SetRGB(c, 1, 1, 1, 1); CGContextFillRect(c, CGRectMake(ox + 50 * u, oy, 50 * u, s));
		SetRGB(c, 0.05, 0.1, 0.4, 1); CGContextSetLineWidth(c, 4 * u);
		CGContextMoveToPoint(c, ox + 34 * u, oy + 62 * u); CGContextAddLineToPoint(c, ox + 34 * u, oy + 74 * u); CGContextStrokePath(c);
		CGContextMoveToPoint(c, ox + 66 * u, oy + 62 * u); CGContextAddLineToPoint(c, ox + 66 * u, oy + 74 * u); CGContextStrokePath(c);
		CGContextMoveToPoint(c, ox + 28 * u, oy + 32 * u); CGContextAddQuadCurveToPoint(c, ox + 50 * u, oy + 18 * u, ox + 72 * u, oy + 32 * u); CGContextStrokePath(c);
	} else if (!strcmp(glyph ? glyph : "", "terminal")) {
		SetRGB(c, 0.25, 0.9, 0.35, 1); CGContextSetLineWidth(c, 7 * u);
		CGContextMoveToPoint(c, ox + 26 * u, oy + 66 * u); CGContextAddLineToPoint(c, ox + 44 * u, oy + 50 * u); CGContextAddLineToPoint(c, ox + 26 * u, oy + 34 * u); CGContextStrokePath(c);
		CGContextMoveToPoint(c, ox + 52 * u, oy + 32 * u); CGContextAddLineToPoint(c, ox + 74 * u, oy + 32 * u); CGContextStrokePath(c);
	} else if (!strcmp(glyph ? glyph : "", "settings")) {
		SetRGB(c, 0.95, 0.95, 0.97, 1); CGContextSetLineWidth(c, 9 * u);
		CGContextStrokeEllipseInRect(c, CGRectMake(ox + 30 * u, oy + 30 * u, 40 * u, 40 * u));
		for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; CGContextMoveToPoint(c, ox + (50 + 24 * cos(a)) * u, oy + (50 + 24 * sin(a)) * u); CGContextAddLineToPoint(c, ox + (50 + 33 * cos(a)) * u, oy + (50 + 33 * sin(a)) * u); CGContextStrokePath(c); }
	} else if (!strcmp(glyph ? glyph : "", "launchpad")) {
		const double cols[9][3] = { { 1, .3, .3 }, { 1, .7, .2 }, { .3, .8, .4 }, { .3, .6, 1 }, { .7, .4, 1 }, { 1, .4, .7 }, { .5, .5, .55 }, { .2, .8, .8 }, { 1, .85, .2 } };
		for (int i = 0; i < 9; i++) { SetRGB(c, cols[i][0], cols[i][1], cols[i][2], 1); CGContextFillRect(c, CGRectMake(ox + (20 + 22 * (i % 3)) * u, oy + (20 + 22 * (i / 3)) * u, 16 * u, 16 * u)); }
	} else if (!strcmp(glyph ? glyph : "", "doc")) {
		SetRGB(c, 0.3, 0.5, 0.9, 1); CGContextSetLineWidth(c, 5 * u);
		CGContextStrokeRect(c, CGRectMake(ox + 28 * u, oy + 18 * u, 44 * u, 60 * u));
		for (int i = 0; i < 4; i++) { CGContextMoveToPoint(c, ox + 36 * u, oy + (62 - i * 11) * u); CGContextAddLineToPoint(c, ox + 64 * u, oy + (62 - i * 11) * u); CGContextStrokePath(c); }
	} else if (!strcmp(glyph ? glyph : "", "folder")) {
		SetRGB(c, 1, 1, 1, 0.9); CGContextSetLineWidth(c, 6 * u);
		CGContextMoveToPoint(c, ox + 50 * u, oy + 70 * u); CGContextAddLineToPoint(c, ox + 50 * u, oy + 34 * u); CGContextStrokePath(c);
		CGContextMoveToPoint(c, ox + 34 * u, oy + 48 * u); CGContextAddLineToPoint(c, ox + 50 * u, oy + 32 * u); CGContextAddLineToPoint(c, ox + 66 * u, oy + 48 * u); CGContextStrokePath(c);
	} else if (!strcmp(glyph ? glyph : "", "trash")) {
		SetRGB(c, 1, 1, 1, 0.9); CGContextSetLineWidth(c, 5 * u);
		CGContextStrokeRect(c, CGRectMake(ox + 32 * u, oy + 22 * u, 36 * u, 44 * u));
		CGContextMoveToPoint(c, ox + 26 * u, oy + 72 * u); CGContextAddLineToPoint(c, ox + 74 * u, oy + 72 * u); CGContextStrokePath(c);
		for (int i = 0; i < 3; i++) { CGContextMoveToPoint(c, ox + (42 + i * 8) * u, oy + 30 * u); CGContextAddLineToPoint(c, ox + (42 + i * 8) * u, oy + 58 * u); CGContextStrokePath(c); }
	} else {
		SetRGB(c, 1, 1, 1, 0.95); CGContextFillEllipseInRect(c, CGRectMake(ox + 34 * u, oy + 34 * u, 32 * u, 32 * u));
	}
	CGContextRestoreGState(c);
	/* the soft edge of every icon: a faint dark outline */
	SetRGB(c, 0, 0, 0, 0.18); CGContextSetLineWidth(c, 0.8); CGContextAddPath(c, sq); CGContextStrokePath(c);
	CGPathRelease(sq);
}

static void Upright(CGContextRef c, const DockScene *s, CGFloat cx, CGFloat cy);
static void DrawText(CGContextRef c, const char *text, CGFloat size, CGPoint at, CGFloat *outWidth)
{
	/* the "toy" text API of CoreGraphics: it exists in Apple's and in Opal; the width is measured by drawing far outside the window (Opal does not know the invisible text mode) */
	CGContextSaveGState(c);
	CGContextSelectFont(c, "Helvetica", size, kCGEncodingMacRoman);
	CGContextSetTextMatrix(c, CGAffineTransformIdentity);
	if (outWidth) {
		CGContextTranslateCTM(c, -100000, -100000);
		CGContextSetTextPosition(c, 0, 0);
		CGContextShowText(c, text, strlen(text));
		*outWidth = CGContextGetTextPosition(c).x;
	} else {
		CGContextSetTextDrawingMode(c, kCGTextFill);
		CGContextShowTextAtPoint(c, at.x, at.y, text, strlen(text));
	}
	CGContextRestoreGState(c);
}

static const double fanx[16] = { 0, 2.5, 6.5, 13, 19.5, 27.5, 37.5, 49, 62, 76, 92, 109, 127.5, 146.5, 169, 192 };
double DockFanOffsetX(int k) { return fanx[k < 0 ? 0 : k > 15 ? 15 : k]; }
double DockFanPitch(void) { return 64; }
double DockFanAngle(int k) { return -(0.65 + 1.246 * (k + 1)); }       /* degrees; every item is turned a little more, clockwise */
double DockFanItemProgress(int k, double t)                          /* ease-out over 0.17 s, each item starting 12 ms after the one below it */
{
	double u = (t - 0.012 * k) / 0.17; if (u < 0) u = 0; if (u > 1) u = 1;
	return 1 - (1 - u) * (1 - u) * (1 - u);
}

/* the stack's tile while its fan, grid or list is open: a dark rounded button with a chevron (u: opening progress) */
static void DrawChevronButton(CGContextRef c, CGFloat art, CGFloat cx, CGFloat art_bottom, double u)
{
	CGFloat bx = cx - art / 2, by = art_bottom;
	SetRGB(c, 0.13, 0.13, 0.135, 0.96 * fmin(1, u * 3)); CGPathRef btn = ContinuousRect(CGRectMake(bx, by, art, art), art * 0.2237); CGContextAddPath(c, btn); CGContextFillPath(c);
	SetRGB(c, 1, 1, 1, 0.16); CGContextSetLineWidth(c, 1); CGContextAddPath(c, btn); CGContextStrokePath(c); CGPathRelease(btn);
	SetRGB(c, 1, 1, 1, 0.92); CGContextSetLineWidth(c, 4); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
	CGContextMoveToPoint(c, cx - 10, by + art / 2 + 5); CGContextAddLineToPoint(c, cx, by + art / 2 - 5); CGContextAddLineToPoint(c, cx + 10, by + art / 2 + 5); CGContextStrokePath(c);
}

static void DrawFan(CGContextRef c, const DockScene *s, CGFloat art_bottom)
{
	const DockFan *f = s->fan; const DockSlot *sl = &s->slots[f->anchor];
	CGFloat cx = sl->cx - s->origin_x, tile_top = art_bottom + sl->art;
	for (int k = f->n - 1; k >= 0; k--) {                                 /* the top ones first so the lower ones overlap them */
		double e = DockFanItemProgress(k, f->t); if (f->u < 1) e = e * f->u;
		if (e <= 0.001) continue;
		CGFloat fx = cx - 2 + DockFanOffsetX(k), fy = tile_top + 62.5 + DockFanPitch() * k;
		if (s->orient) { fx = cx - (62.5 + DockFanPitch() * k); fy = tile_top + 6 + DockFanOffsetX(k); }       /* beside the bar: the items rise up the screen and lean away from the edge */
		CGFloat x = cx + (fx - cx) * e, y = tile_top + (fy - tile_top) * e; CGFloat sgn = s->orient == 2 ? -1 : 1;
		CGContextSaveGState(c); CGContextSetAlpha(c, e);
		CGContextTranslateCTM(c, x, y); Upright(c, s, 0, 0); CGContextRotateCTM(c, sgn * DockFanAngle(k) * M_PI / 180 * e); CGContextScaleCTM(c, 0.55 + 0.45 * e, 0.55 + 0.45 * e);
		CGRect ir = CGRectMake(-32, -32, 64, 64);
		if (f->icons[k]) CGContextDrawImage(c, ir, f->icons[k]); else DockDrawIcon(c, f->glyphs[k], CGRectInset(ir, 6, 6));
		CGFloat tw = 0; DrawText(c, f->labels[k], 13, CGPointZero, &tw);
		CGFloat ph = 26, pw = tw + 29, px = s->orient == 1 ? 37 : -37 - pw, py = -ph / 2;
		SetRGB(c, 0.15, 0.15, 0.155, 0.92); CGPathRef pill = RoundRectPath(CGRectMake(px, py, pw, ph), ph / 2); CGContextAddPath(c, pill); CGContextFillPath(c);
		SetRGB(c, 1, 1, 1, 0.10); CGContextSetLineWidth(c, 1); CGContextAddPath(c, pill); CGContextStrokePath(c); CGPathRelease(pill);
		SetRGB(c, 1, 1, 1, 0.86); DrawText(c, f->labels[k], 13, CGPointMake(px + 14.5, py + 8.5), NULL);
		CGContextRestoreGState(c);
	}
	/* while the fan is open the stack's tile is a dark rounded button with a chevron */
	DrawChevronButton(c, sl->art, cx, art_bottom, f->u);
}


/* the bar on the left or right edge: dock space (x along the bar, y away from the edge) maps onto the window; Upright undoes the turn around a point so that icons and texts are not rotated */
static void Orient(CGContextRef c, const DockScene *s)
{
	if (s->orient == 1) CGContextConcatCTM(c, CGAffineTransformMake(0, -1, 1, 0, 0, s->height));
	else if (s->orient == 2) CGContextConcatCTM(c, CGAffineTransformMake(0, -1, -1, 0, s->width, s->height));
}
static void Upright(CGContextRef c, const DockScene *s, CGFloat cx, CGFloat cy)
{
	if (!s->orient) return;
	CGContextTranslateCTM(c, cx, cy);
	if (s->orient == 1) CGContextConcatCTM(c, CGAffineTransformMake(0, 1, -1, 0, 0, 0)); else CGContextConcatCTM(c, CGAffineTransformMake(0, -1, -1, 0, 0, 0));
	CGContextTranslateCTM(c, -cx, -cy);
}
static CGPoint WinOf(const DockScene *s, CGFloat x, CGFloat y)                    /* a point of dock space in the window */
{
	if (s->orient == 1) return CGPointMake(y, s->height - x);
	if (s->orient == 2) return CGPointMake(s->width - y, s->height - x);
	return CGPointMake(x, y);
}

void DockRender(CGContextRef c, const DockScene *s)
{
	if (s->orient) { CGContextSaveGState(c); Orient(c, s); }
	const DockBar *b = &s->bar;
	CGFloat bx = b->bar_x - s->origin_x, by = b->bottom_margin, bw = b->bar_w, bh = b->bar_h;
	/* the bar: white at 4.7 %, over what the compositor blurs behind the window */
	CGPathRef bar = ContinuousRect(CGRectMake(bx, by, bw, bh), 18);
	SetRGB(c, 1, 1, 1, 0.047); CGContextAddPath(c, bar); CGContextFillPath(c);
	/* the rim: a bright line at the top and at the bottom that fades inward over 7 px (83/255 over a dark ground at the edge, 28, 21, 18, 16, 14, 13) */
	CGContextSaveGState(c); CGContextAddPath(c, bar); CGContextClip(c);
	{
		const CGFloat edge[8] = { 0.28, 0.063, 0.035, 0.024, 0.016, 0.008, 0.004, 0.0 };
		for (int i = 0; i < 8; i++) {
			SetRGB(c, 1, 1, 1, edge[i]);
			CGContextFillRect(c, CGRectMake(bx, by + bh - 1 - i, bw, 1)); CGContextFillRect(c, CGRectMake(bx, by + i, bw, 1));
		}
	}
	CGContextRestoreGState(c);
	SetRGB(c, 1, 1, 1, 0.07); CGContextSetLineWidth(c, 1); CGContextAddPath(c, bar); CGContextStrokePath(c);
	CGPathRelease(bar);
	CGFloat art_bottom = by + 15.0;                                      /* the icons stand 15 px above the inside of the bar's bottom edge */
	for (int i = 0; i < s->n; i++) {
		const DockSlot *sl = &s->slots[i]; const DockTile *t = &s->tiles[i];
		CGFloat cx = sl->cx - s->origin_x;
		if (s->items[i].kind == DOCK_SEPARATOR) {                         /* a 1 px line, 62 px tall, white at 25 % */
			SetRGB(c, 1, 1, 1, 0.255); CGContextFillRect(c, CGRectMake(floor(cx), by + 11, 1, 62));
			continue;
		}
		if (DOCK_IS_GAP(s->items[i].kind)) continue;
		CGFloat art = sl->art, lift = t->bounce * s->m.tilesize;
		if (s->fan && s->fan->anchor == i) continue;                      /* drawn by DrawFan */
		if (s->chevron1 == i + 1) { CGContextSaveGState(c); Upright(c, s, cx, art_bottom + art / 2); DrawChevronButton(c, art, cx, art_bottom, 1); CGContextRestoreGState(c); continue; }
		CGContextSaveGState(c); Upright(c, s, cx, art_bottom + lift + art / 2);
		if (t->glyph && !strcmp(t->glyph, "none") && !t->icon) { /* a minimizing window's tile: empty until the window has arrived */ }
		else if (t->icon) CGContextDrawImage(c, CGRectMake(cx - art / 2 - art * 0.0625, art_bottom + lift - art * 0.0625, art * 1.125, art * 1.125), t->icon);   /* the icon image has a margin (the art is 80 % of it) */
		else DockDrawIcon(c, t->glyph, CGRectMake(cx - art / 2, art_bottom + lift, art, art));
		if (t->badge > 0) {                                               /* the badge, laid out as ECStatusLabelLayer does on the 128 point icon canvas (decompiled): a red pill 50 high and at least 50 wide, text 20 wider than the number, in the top right corner */
			char num[16]; snprintf(num, sizeof num, "%d", t->badge); double canvas = art * 1.25, k = canvas / 128; CGFloat tw = 0; DrawText(c, num, (CGFloat)(30 * k), CGPointZero, &tw);
			double w128 = fmax(54, tw / k + 20) - 4, bw = w128 * k, bh = 50 * k, bxx = cx + canvas / 2 - bw - 1 * k, byy = art_bottom + lift - art * 0.0625 + canvas - bh - 1 * k;
			SetRGB(c, 1.0, 0.2314, 0.1885, 0.92); CGPathRef pill = ContinuousRect(CGRectMake(bxx, byy, bw, bh), bh / 2); CGContextAddPath(c, pill); CGContextFillPath(c); CGPathRelease(pill);
			SetRGB(c, 1, 1, 1, 1); DrawText(c, num, (CGFloat)(30 * k), CGPointMake(bxx + (bw - tw) / 2, byy + bh / 2 - 10.5 * k), NULL);
		}
		CGContextRestoreGState(c);
		if (t->running) { SetRGB(c, 0.54, 0.54, 0.54, 1); CGContextFillEllipseInRect(c, CGRectMake(cx - 2, by + 11.5, 4, 4)); }
	}
	if (s->fan) DrawFan(c, s, art_bottom);
	if (s->orient) CGContextRestoreGState(c);
	if (!s->fan && s->hover >= 0 && s->hover < s->n && s->tiles[s->hover].label) {                 /* the label: a dark pill beside the tile with a small arrow */
		const DockSlot *sl = &s->slots[s->hover]; CGFloat cx = sl->cx - s->origin_x, tw = 0;
		DrawText(c, s->tiles[s->hover].label, 15, CGPointZero, &tw);
		CGFloat pw = tw + 28, ph = 30;
		if (!s->orient) {
			CGFloat py = art_bottom + sl->art + 14; CGRect pr = CGRectMake(cx - pw / 2, py, pw, ph);
			SetRGB(c, 0.17, 0.17, 0.18, 0.92); CGPathRef pill = ContinuousRect(pr, 15); CGContextAddPath(c, pill); CGContextFillPath(c); CGPathRelease(pill);
			CGContextMoveToPoint(c, cx - 7, py + 0.5); CGContextAddLineToPoint(c, cx, py - 7); CGContextAddLineToPoint(c, cx + 7, py + 0.5); CGContextClosePath(c); CGContextFillPath(c);
			SetRGB(c, 1, 1, 1, 0.95); DrawText(c, s->tiles[s->hover].label, 15, CGPointMake(cx - tw / 2, py + 9), NULL);
		} else {                                                                                   /* on the left edge the pill is to the right of the tile, on the right edge to the left */
			CGPoint e = WinOf(s, cx, art_bottom + sl->art + 14), cp = WinOf(s, cx, art_bottom + sl->art / 2); CGFloat dir = s->orient == 1 ? 1 : -1;
			CGRect pr = CGRectMake(s->orient == 1 ? e.x : e.x - pw, cp.y - ph / 2, pw, ph);
			SetRGB(c, 0.17, 0.17, 0.18, 0.92); CGPathRef pill = ContinuousRect(pr, 15); CGContextAddPath(c, pill); CGContextFillPath(c); CGPathRelease(pill);
			CGContextMoveToPoint(c, e.x - dir * 0.5, cp.y + 7); CGContextAddLineToPoint(c, e.x - dir * 7.5, cp.y); CGContextAddLineToPoint(c, e.x - dir * 0.5, cp.y - 7); CGContextClosePath(c); CGContextFillPath(c);
			SetRGB(c, 1, 1, 1, 0.95); DrawText(c, s->tiles[s->hover].label, 15, CGPointMake(pr.origin.x + 14, cp.y - 6), NULL);
		}
	}
}
