/* The genie minimize effect: the mesh that Dock gives SetWindowWarp every frame, ported from the decompiled Dock (the routine at 0x100026c64 and its subdivision helper at 0x1000276d8).
 * Coordinates are screen coordinates with y down. The window rect and the rect of the Dock tile are (x, y, w, h); progress runs 0 ... 1; the direction is the side of the screen the Dock is on:
 * 1 bottom, 2 top, 3 left, 4 right. The mesh has 4 floats per point: srcX srcY (pixels in the window) dstX dstY (screen); cols x rows points (2 x N for 1 and 2, N x 2 for 3 and 4).
 * Returns the number of floats written (0 when there is nothing to draw); *done is the fraction of the effect that has finished (the window is removed at 1). */
#ifndef WSBSD_GENIE_H
#define WSBSD_GENIE_H
#define GENIE_MAX_FLOATS 12800
int genie_mesh(const double win[4], const double icon[4], float progress, int dir, float *mesh, int *cols, int *rows, float *done);
#endif
