/* The client API of SkyLight (the SLS and CGS functions) as wsbsd's shim implements it. Names, argument order and result codes follow the real library;
 * the implementation (shim/skylight.c) speaks the SkyLight MIG protocol to wsd. */
#ifndef WSBSD_SKYLIGHT_H
#define WSBSD_SKYLIGHT_H
#include <stdint.h>

typedef int CGError;
typedef int CGSConnectionID;
typedef uint32_t CGSWindowID;
typedef struct { double x, y; } SLPoint;
typedef struct { double x, y, w, h; } SLRect;                    /* CGRect: origin then size */
typedef struct CGSRegion *CGSRegionRef;

int SLSMainConnectionID(void);
CGError SLSNewConnection(int unused, CGSConnectionID *cid);
CGError SLSReleaseConnection(CGSConnectionID cid);

CGError CGSNewRegionWithRect(const SLRect *rect, CGSRegionRef *out);
CGError SLSNewRegionWithRect(const SLRect *rect, CGSRegionRef *out);
CGError CGSReleaseRegion(CGSRegionRef region);

CGError SLSNewWindow(CGSConnectionID cid, int type, float x, float y, CGSRegionRef region, CGSWindowID *wid);
CGError SLSReleaseWindow(CGSConnectionID cid, CGSWindowID wid);
CGError SLSOrderWindow(CGSConnectionID cid, CGSWindowID wid, int mode, CGSWindowID relative);   /* mode: 1 above, -1 below, 0 out */
CGError SLSMoveWindow(CGSConnectionID cid, CGSWindowID wid, const SLPoint *origin);
CGError SLSSetWindowLevel(CGSConnectionID cid, CGSWindowID wid, int level);
CGError SLSGetWindowLevel(CGSConnectionID cid, CGSWindowID wid, int *level);
CGError SLSSetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float alpha);
CGError SLSGetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float *alpha);
CGError SLSGetWindowBounds(CGSConnectionID cid, CGSWindowID wid, SLRect *bounds);
CGError SLSGetWindowOwner(CGSConnectionID cid, CGSWindowID wid, CGSConnectionID *owner);
CGError SLSWindowIsOrderedIn(CGSConnectionID cid, CGSWindowID wid, unsigned char *ordered_in);
CGError SLSGetWindowCount(CGSConnectionID cid, CGSConnectionID owner, int *count);
CGError SLSGetOnScreenWindowCount(CGSConnectionID cid, CGSConnectionID owner, int *count);
CGError SLSSetWindowSubLevel(CGSConnectionID cid, CGSWindowID wid, int sublevel);
int SLSGetWindowSubLevel(CGSConnectionID cid, CGSWindowID wid);                 /* the sublevel is the return value */
CGError SLSSetWindowEventMask(CGSConnectionID cid, CGSWindowID wid, unsigned mask);
CGError SLSGetWindowEventMask(CGSConnectionID cid, CGSWindowID wid, unsigned *mask);
CGError SLSSetWindowBackgroundBlurRadius(CGSConnectionID cid, CGSWindowID wid, int radius);
CGError SLSHideCursor(CGSConnectionID cid);
CGError SLSShowCursor(CGSConnectionID cid);
CGError SLSObscureCursor(CGSConnectionID cid);
CGError SLSRevealCursor(CGSConnectionID cid);
CGError SLSGetCursorScale(CGSConnectionID cid, float *scale);
CGError SLSGetOnScreenWindowList(CGSConnectionID cid, CGSConnectionID owner, int max, uint32_t *list, int *count);
CGError SLSSetWindowTags(CGSConnectionID cid, CGSWindowID wid, uint64_t *tags, int size);
CGError SLSClearWindowTags(CGSConnectionID cid, CGSWindowID wid, uint64_t *tags, int size);
CGError SLSGetWindowTags(CGSConnectionID cid, CGSWindowID wid, uint64_t *tags, int size);
CGError SLSSetWindowShape(CGSConnectionID cid, CGSWindowID wid, float tx, float ty, CGSRegionRef shape);   /* origin (tx, ty), size of the region */
CGError SLSGetWindowResolution(CGSConnectionID cid, CGSWindowID wid, double *scale);
CGError SLSSetWindowResolution(CGSConnectionID cid, CGSWindowID wid, double scale);
CGError SLSSetWindowListAlpha(CGSConnectionID cid, const CGSWindowID *list, int count, float alpha);
CGError WSCaptureWindowPixels(CGSConnectionID cid, CGSWindowID wid, int *w, int *h, uint8_t **bgra);   /* wsbsd extension: composed pixels of a window / the screen */
#endif
