/* Draws three glyphs with CoreText over Opal into a bitmap and counts the pixels that changed: 0 means text is not rendered. */
#import <Foundation/Foundation.h>
#include <CoreText/CoreText.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>
int main(void)
{
	@autoreleasepool {
		CTFontRef f = CTFontCreateWithName(CFSTR("DejaVuSansMono"), 16, NULL);
		printf("font %p size %g\n", (void *)f, f ? CTFontGetSize(f) : 0.0);
		if (!f) return 2;
		CFStringRef psn = CTFontCopyPostScriptName(f); char nb[96] = "(null)"; if (psn) CFStringGetCString(psn, nb, sizeof nb, kCFStringEncodingUTF8);
		printf("postscript name: %s\n", nb);
		UniChar ch[3] = { 'H', 'e', 'x' }; CGGlyph g[3] = { 0, 0, 0 };
		bool ok = CTFontGetGlyphsForCharacters(f, ch, g, 3);
		printf("glyphs ok=%d: %d %d %d\n", ok, g[0], g[1], g[2]);
		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
		unsigned char *px = calloc(120 * 40 * 4, 1);
		CGContextRef c = CGBitmapContextCreate(px, 120, 40, 8, 120 * 4, cs, kCGImageAlphaPremultipliedLast);
		if (!c) { printf("no bitmap context\n"); return 3; }
		CGContextSetRGBFillColor(c, 1, 1, 1, 1); CGContextFillRect(c, CGRectMake(0, 0, 120, 40));
		CGContextSetRGBFillColor(c, 0, 0, 0, 1);
		CGPoint pos[3] = { { 5, 10 }, { 20, 10 }, { 35, 10 } };
		CTFontDrawGlyphs(f, g, pos, 3, c);
		unsigned char *d0 = CGBitmapContextGetData(c);
		int dark = 0; for (int i = 0; i < 120 * 40; i++) if (d0[i * 4] < 128 && d0[i * 4 + 3] > 0) dark++;
		printf("data %p (own buffer %p); dark pixels after CTFontDrawGlyphs: %d of %d\n", (void *)d0, (void *)px, dark, 120 * 40);
		CGContextSetRGBFillColor(c, 1, 1, 1, 1); CGContextFillRect(c, CGRectMake(0, 0, 120, 40));
		CGContextSelectFont(c, "DejaVuSansMono", 16, kCGEncodingMacRoman);
		CGContextSetRGBFillColor(c, 0, 0, 0, 1);
		CGContextShowGlyphsAtPositions(c, g, pos, 3);
		dark = 0; for (int i = 0; i < 120 * 40; i++) if (d0[i * 4] < 128 && d0[i * 4 + 3] > 0) dark++;
		printf("dark pixels after CGContextShowGlyphsAtPositions: %d\n", dark);
		return dark > 0 ? 0 : 1;
	}
}
