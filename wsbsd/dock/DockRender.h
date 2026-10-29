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
	CGImageRef icon;              /* the application's real icon (from LaunchServices); NULL draws the built-in glyph */
} DockTile;

/* the fan of a stack: the newest items rise from the stack's tile along a curve, each with a label pill on its left */
#define DOCK_FAN_MAX 16
typedef struct {
	int n;                        /* number of entries (the last one may be the "N More in Finder" entry) */
	const char *labels[DOCK_FAN_MAX]; const char *glyphs[DOCK_FAN_MAX];
	CGImageRef icons[DOCK_FAN_MAX];  /* the real icons (64 x 64 box); NULL entries fall back to the glyph */
	int anchor;                   /* tile index of the stack */
	double t;                     /* seconds since the fan opened (negative while closing: -elapsed, see DockFanProgress) */
	double u;                     /* open progress 0...1 of the whole fan (staggered per item inside) */
} DockFan;

typedef struct {
	DockMetrics m;
	const DockItem *items; const DockTile *tiles; int n;
	const DockSlot *slots; DockBar bar;
	double origin_x;              /* x of the window's left edge in the Dock's coordinates */
	double height;                /* height of the window */
	int hover;                    /* index of the tile with a tooltip, -1 for none */
	const DockFan *fan;           /* NULL when no stack is open */
	int orient;                   /* 0 bottom, 1 left, 2 right: the scene is drawn as for the bottom and turned onto the edge, the icons and the texts stay upright */
	double width;                 /* width of the window (for the right edge) */
	int chevron1;                 /* 1 + the index of a stack tile whose grid or list is open (it shows the chevron button as in the fan), 0 for none */
} DockScene;

/* geometry of the fan: x offset of item k from the first one, vertical pitch, per-item eased progress for the time t in seconds (0 .. 1) */
double DockFanOffsetX(int k);
double DockFanPitch(void);
double DockFanAngle(int k);
double DockFanItemProgress(int k, double t);

/* draws the bar, the tiles, the dots, the separator and the tooltip into ctx (a context of the window size, y up) */
void DockRender(CGContextRef ctx, const DockScene *s);
extern CGRect gDockLabelPill, gDockLabelTail;     /* the label's glass shapes of the last picture (window space, y up); zero when there is no label */
/* one icon of the built-in set into the square (x, y, size) */
void DockDrawIcon(CGContextRef ctx, const char *glyph, CGRect r);
#endif
