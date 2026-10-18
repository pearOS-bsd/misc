/* fan_shot: renders the Dock with an open Downloads fan (as DockRender draws it) into a PNG the size of a reference crop of the real Dock (900 x 1100 at (1800, 340) of the 3440 x 1440 screen), for tools/overlay.py.
 * usage: fan_shot out.png [t_seconds]   (t = time since the fan opened; default settled) */
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#include "../DockRender.h"
#import "../../launchservices/LSIcon.h"
int main(int argc, char **argv)
{
	@autoreleasepool {
		DockMetrics m = { 58, 99, 1, 3440 };
		const char *names[] = { "Finder", "Launchpad", "Chrome", "WhatsApp", "Terminal", "Mail", "Spotify", "Notes", "App Store", "Warp", "Settings", "Keyboard", "Premiere", "After Effects", "Anydesk", "Discord", "Claude", "", "Document", "Downloads", "Trash" };
		int N = 21; DockItem items[24]; DockTile tiles[24]; DockSlot slots[24]; DockBar bar;
		for (int i = 0; i < N; i++) { items[i].kind = i == 17 ? DOCK_SEPARATOR : (i == 18 || i == 19 ? DOCK_OTHER : (i == 20 ? DOCK_TRASH : DOCK_APP)); tiles[i] = (DockTile){ names[i], i == 20 ? "trash" : (i == 19 ? "folder" : "generic"), 0, 0, 0 }; }
		dock_layout(&m, items, N, 2266, slots, &bar);
		DockFan fan; memset(&fan, 0, sizeof fan);
		const char *lab[] = { "MSD81_RSADelete_0044CC0IJE0S.zip", "I8A0S_RSA_Bypass.0pa", "I8A0S_RSA_Bypass.zip", "E93 Tune", "S8619727.0da.zip", "7611396A.0pa.zip", "S8619717.bin", "Chitanta_IfnDejuSRL12359882_6.pdf", "Factura_IfnDejuSRL_EBF_77.pdf", "Factura_PATRUELENAALEHANDRA_EBF_2 (1).pdf", "Factura_PATRUELENAALEHANDRA_EBF_3 (1).pdf", "Factura_BotanicalSRL_EBF_76.pdf", "import_26_09_2026.xlsx", "Alacritty-v0.17.0.dmg", "Raport (1).pdf" };
		fan.n = 15; for (int k = 0; k < 15; k++) { fan.labels[k] = lab[k]; fan.glyphs[k] = k == 3 ? "folder" : "doc"; fan.icons[k] = LSIconCreateForKind(k == 3 ? @"folder" : LSKindForPath(@(lab[k])), 128); }
		fan.anchor = 19; fan.t = argc > 2 ? atof(argv[2]) : 1.0; fan.u = 1;
		int W = 900, H = 1100; double ox = 1800;
		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
		CGContextRef c = CGBitmapContextCreate(NULL, W, H, 8, W * 4, cs, kCGImageAlphaPremultipliedLast);
		CGContextSetRGBFillColor(c, 0, 0, 0, 1); CGContextFillRect(c, CGRectMake(0, 0, W, H));
		DockScene sc = { m, items, tiles, N, slots, bar, ox, H, -1, &fan };
		DockRender(c, &sc);
		CGImageRef im = CGBitmapContextCreateImage(c);
		CFURLRef u = (__bridge CFURLRef)[NSURL fileURLWithPath: @(argv[1])];
		CGImageDestinationRef d = CGImageDestinationCreateWithURL(u, CFSTR("public.png"), 1, NULL); CGImageDestinationAddImage(d, im, NULL); CGImageDestinationFinalize(d);
	}
	return 0;
}
