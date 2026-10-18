/* Drawing of the Dock with CoreGraphics (Opal on FreeBSD, Apple's on a Mac, so that the result can be compared with the real Dock). */
#ifndef WSBSD_DOCKRENDER_H
#define WSBSD_DOCKRENDER_H
#include <CoreGraphics/CoreGraphics.h>
#include "dock_layout.h"

typedef struct {
	const char *label;            /* tooltip text */
	const char *glyph;            /* which built-in icon to draw: "finder", "terminal", "settings", "launchpad", "doc", "folder", "trash", "generic" */
	int running;                  /* a dot under the tile */
	int badge;                    /* a red badge with this number when > 0 */
	float bounce;                 /* 0 ... 1 lift of the tile, for the launch bounce (in tile heights) */
} DockTile;

typedef struct {
	DockMetrics m;
	const DockItem *items; const DockTile *tiles; int n;
	const DockSlot *slots; DockBar bar;
	double origin_x;              /* x of the window's left edge in the Dock's coordinates */
	double height;                /* height of the window */
	int hover;                    /* index of the tile with a tooltip, -1 for none */
} DockScene;

/* draws the bar, the tiles, the dots, the separator and the tooltip into ctx (a context of the window size, y up) */
void DockRender(CGContextRef ctx, const DockScene *s);
/* one icon of the built-in set into the square (x, y, size) */
void DockDrawIcon(CGContextRef ctx, const char *glyph, CGRect r);
#endif
