#include "config.h"
#include "wsd/WsdServer.h"
#include "wsd/WsdCairoSurface.h"
#include <cairo/cairo.h>

@implementation WsdCairoSurface

- (id) initWithDevice: (void *)device
{
	struct wsd_window *w = device;
	WsdServer *srv = (WsdServer *)GSCurrentServer();
	if (w == NULL || ![srv attachBuffer: w]) {
		[self release];
		return nil;
	}
	ws_surface *px = w->cbuf.buf.cpu;
	gsDevice = device;
	_surface = cairo_image_surface_create_for_data(px->px, CAIRO_FORMAT_ARGB32, w->w, w->h, (int)px->stride);
	if (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS) {
		cairo_surface_destroy(_surface); _surface = NULL;
		[self release];
		return nil;
	}
	w->surface = self;
	return self;
}

- (void) dealloc
{
	struct wsd_window *w = gsDevice;
	if (w && w->surface == self) w->surface = NULL;
	[super dealloc];
}

- (NSSize) size
{
	if (_surface == NULL) return NSZeroSize;
	return NSMakeSize(cairo_image_surface_get_width(_surface), cairo_image_surface_get_height(_surface));
}

- (void) handleExposeRect: (NSRect)rect
{
	struct wsd_window *w = gsDevice;
	if (w == NULL) return;
	cairo_surface_flush(_surface);
	[(WsdServer *)GSCurrentServer() commitWindow: w rect: rect];
}

- (void) flush
{
	if (_surface) cairo_surface_flush(_surface);
}

@end
