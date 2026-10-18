/* mkicon: renders a built-in Dock glyph (DockDrawIcon) into an .icns file (PNG entries of 128, 256 and 512 px): mkicon GLYPH out.icns */
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#include "../DockRender.h"
static NSData *PNG(const char *glyph, int px)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef c = CGBitmapContextCreate(NULL, px, px, 8, px * 4, cs, kCGImageAlphaPremultipliedLast);
	double m = px * 0.0977;                                  /* the margin of an application icon: the art is 80 % of the image */
	DockDrawIcon(c, glyph, CGRectMake(m, m, px - 2 * m, px - 2 * m));
	CGImageRef im = CGBitmapContextCreateImage(c); NSMutableData *d = [NSMutableData data];
	CGImageDestinationRef dst = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)d, CFSTR("public.png"), 1, NULL); CGImageDestinationAddImage(dst, im, NULL); CGImageDestinationFinalize(dst);
	CGImageRelease(im); CGContextRelease(c); CGColorSpaceRelease(cs); return d;
}
int main(int argc, char **argv)
{
	@autoreleasepool {
		if (argc < 3) return 1;
		struct { const char *t; int px; } e[] = { { "ic07", 128 }, { "ic08", 256 }, { "ic09", 512 } };
		NSMutableData *out = [NSMutableData data]; uint32_t total = 8;
		NSMutableArray *chunks = [NSMutableArray array];
		for (int i = 0; i < 3; i++) { NSData *p = PNG(argv[1], e[i].px); NSMutableData *ch = [NSMutableData data]; uint32_t len = htonl((uint32_t)p.length + 8); [ch appendBytes: e[i].t length: 4]; [ch appendBytes: &len length: 4]; [ch appendData: p]; [chunks addObject: ch]; total += (uint32_t)ch.length; }
		uint32_t tl = htonl(total); [out appendBytes: "icns" length: 4]; [out appendBytes: &tl length: 4]; for (NSData *ch in chunks) [out appendData: ch];
		[out writeToFile: @(argv[2]) atomically: YES];
	}
	return 0;
}
