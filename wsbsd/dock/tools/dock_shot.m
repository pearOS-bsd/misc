/* dock_shot: renders the Dock the way DockRender draws it over a black ground into a PPM, for comparison with a screenshot of the real Dock (rest, or with the pointer at x).
 * usage: dock_shot out.ppm [pointer_x] [hover_index]   (3440 x 1440 screen, crop of the bottom 140 rows) */
#import <Foundation/Foundation.h>
#include "../DockRender.h"
int main(int argc, char **argv)
{
	@autoreleasepool {
		DockMetrics m = { 58, 99, 1, 3440 };
		const char *names[] = { "Finder", "Launchpad", "Chrome", "WhatsApp", "Terminal", "Mail", "Spotify", "Notes", "App Store", "Warp", "Settings", "Keyboard", "Premiere", "After Effects", "Anydesk", "Discord", "Claude", "", "Document", "Trash" };
		const char *glyph[] = { "finder", "launchpad", "generic", "generic", "terminal", "generic", "generic", "doc", "generic", "generic", "settings", "settings", "generic", "generic", "generic", "generic", "generic", "", "doc", "trash" };
		DockItem items[20]; DockTile tiles[20]; DockSlot slots[20]; DockBar bar;
		for (int i = 0; i < 20; i++) { items[i].kind = i == 17 ? DOCK_SEPARATOR : (i == 18 ? DOCK_OTHER : (i == 19 ? DOCK_TRASH : DOCK_APP)); tiles[i] = (DockTile){ names[i], glyph[i], (i == 4 || i == 6 || i == 15), i == 3 ? 33 : (i == 15 ? 60 : 0), 0 }; }
		double px = argc > 2 ? atof(argv[2]) : -1; int hover = argc > 3 ? atoi(argv[3]) : -1;
		dock_layout(&m, items, 20, px, slots, &bar);
		int W = 3440, H = 140; double ox = 0;
		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
		CGContextRef c = CGBitmapContextCreate(NULL, W, H, 8, W * 4, cs, kCGImageAlphaPremultipliedLast);
		CGContextSetRGBFillColor(c, 0, 0, 0, 1); CGContextFillRect(c, CGRectMake(0, 0, W, H));
		DockScene sc = { m, items, tiles, 20, slots, bar, ox, H, hover };
		DockRender(c, &sc);
		const uint8_t *d = CGBitmapContextGetData(c); FILE *f = fopen(argv[1], "wb"); fprintf(f, "P6 %d %d 255\n", W, H);
		for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) { const uint8_t *p = d + (size_t)y * W * 4 + x * 4; fputc(p[0], f); fputc(p[1], f); fputc(p[2], f); }
		fclose(f); CGContextRelease(c); CGColorSpaceRelease(cs);
	}
	return 0;
}
