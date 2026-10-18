/* The layout of the Dock: where every tile is, with and without magnification. Pure C, no drawing: the numbers come from measurements of the real Dock (see dock/tools) and from its decompiled genie routine.
 * Coordinates are points, x to the right, along the Dock; "rest" is the layout without magnification. */
#ifndef WSBSD_DOCK_LAYOUT_H
#define WSBSD_DOCK_LAYOUT_H

enum { DOCK_APP = 0, DOCK_SEPARATOR = 1, DOCK_OTHER = 2, DOCK_TRASH = 3, DOCK_MINIMIZED = 4 };

typedef struct {
	int tilesize;                 /* the "size" preference, 58 by default */
	int largesize;                /* the magnified size, 99 */
	int magnification;            /* 0 or 1 */
	int screen_w;                 /* length of the screen along the Dock */
} DockMetrics;

typedef struct { int kind; } DockItem;

typedef struct {
	double x;                     /* left edge of the tile's slot, in the Dock's coordinates (the bar included) */
	double w;                     /* width of the slot */
	double cx;                    /* centre of the tile */
	double scale;                 /* 1 at rest, up to largesize / tilesize */
	double art;                   /* edge of the (square) icon art: tilesize * 0.81 * scale */
} DockSlot;

typedef struct {
	double bar_x, bar_w;          /* the bar: its left edge and its width */
	double bar_h;                 /* tilesize + 20 */
	double bottom_margin;         /* 5 */
	double art_rest;              /* tilesize * 0.81, rounded */
} DockBar;

/* fills slots[n] and the bar. cursor_x: the pointer along the Dock or a negative value when it is not over the Dock (no magnification). */
void dock_layout(const DockMetrics *m, const DockItem *items, int n, double cursor_x, DockSlot *slots, DockBar *bar);
/* the size factor of a tile at the given distance (in points) from the pointer, in rest coordinates */
double dock_magnify_factor(const DockMetrics *m, double distance);
#endif
