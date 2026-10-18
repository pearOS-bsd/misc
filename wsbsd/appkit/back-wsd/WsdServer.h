/* WsdServer: a GNUstep display server (libs-back) that talks to wsd, the FreeBSD WindowServer. Windows are wsd windows with a shared pixel buffer
 * bound as their surface; drawing is Cairo into that buffer; input arrives on the wsd event channel. */
#ifndef WsdServer_h
#define WsdServer_h

#include "config.h"
#include <GNUstepGUI/GSDisplayServer.h>
#include "wsd/ws_client.h"

/* the "device" GNUstep passes around for a window */
struct wsd_window {
	int number;                 /* GNUstep window number == wsd window id */
	ws_win win;
	ws_cbuf cbuf;
	uint32_t sid;
	int has_buffer;
	int x, y, w, h;             /* wsd coordinates (origin top-left) */
	int level;
	unsigned style;
	int dockTaken;              /* the Dock has taken the minimizing window over (it animates and orders it out) */
	void *surface;              /* the current WsdCairoSurface (unretained) */
	struct wsd_window *next;
};

@interface WsdServer : GSDisplayServer
{
	ws_conn *conn;
	int screenW, screenH;
	struct wsd_window *windows;
	int keyWindow;
	NSPoint lastPoint;
}
+ (void) initializeBackend;
- (struct wsd_window *) wsdWindow: (int)number;
- (ws_conn *) connection;
/* (re)allocates the shared buffer of a window to its current size and binds it as the surface */
- (BOOL) attachBuffer: (struct wsd_window *)w;
- (void) commitWindow: (struct wsd_window *)w rect: (NSRect)rect;
@end

#endif
