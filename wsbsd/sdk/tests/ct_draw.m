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
		{ /* what Hex Fiend's ASCII column asks: the font's character set, a substitution font for a character the font lacks, glyph ids for printable characters */
			NSCharacterSet *cov = (__bridge_transfer NSCharacterSet *)CTFontCopyCharacterSet(f);
			printf("character set %p: a=%d space=%d newline=%d\n", (void *)cov, cov ? (int)[cov characterIsMember: 'a'] : -1, cov ? (int)[cov characterIsMember: ' '] : -1, cov ? (int)[cov characterIsMember: '\n'] : -1);
			UniChar pc[4] = { ' ', '/', '*', 'z' }; CGGlyph pg[4] = { 0, 0, 0, 0 };
			bool pok = CTFontGetGlyphsForCharacters(f, pc, pg, 4);
			printf("printable glyphs ok=%d: %d %d %d %d\n", pok, pg[0], pg[1], pg[2], pg[3]);
			CFStringRef nl = CFSTR("\n"); CTFontRef sub = CTFontCreateForString(f, nl, CFRangeMake(0, 1));
			printf("substitution font for newline: %p\n", (void *)sub);
		}
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
		{ /* an unmapped glyph id (0xFFFF, or 0) in a run must not spoil the run or the context */
			CGGlyph bad[4] = { 43, 65535, 72, 0 }; CGPoint bp[4] = { { 5, 10 }, { 20, 10 }, { 35, 10 }, { 50, 10 } };
			CGContextSetRGBFillColor(c, 1, 1, 1, 1); CGContextFillRect(c, CGRectMake(0, 0, 120, 40));
			CGContextSetRGBFillColor(c, 0, 0, 0, 1);
			CGContextShowGlyphsAtPositions(c, bad, bp, 4);
			int changed = 0; for (int i = 0; i < 120 * 40; i++) if (d0[i * 4] != 255) changed++;
			printf("pixels changed by a run with unmapped glyphs: %d of %d (a bad glyph must not paint the whole area)\n", changed, 120 * 40);
			CGContextSetRGBFillColor(c, 1, 1, 1, 1); CGContextFillRect(c, CGRectMake(0, 0, 120, 40));
			CGContextSetRGBFillColor(c, 0, 0, 0, 1);
			CGContextSetTextMatrix(c, (CGAffineTransform){ 1, 0, 0, -1, 0, 0 });
			CGContextShowGlyphsAtPositions(c, g, pos, 3);
			changed = 0; for (int i = 0; i < 120 * 40; i++) if (d0[i * 4] != 255) changed++;
			printf("pixels changed with a flipped text matrix: %d\n", changed);
		}
		{ CGRect z = CGRectIntersection(CGRectZero, CGRectMake(0, 0, 80, 381)), o = CGRectIntersection(CGRectMake(100, 0, 2, 13), CGRectMake(0, 0, 80, 381)), q = CGRectIntersection(CGRectMake(3, 0, 2, 13), CGRectMake(0, 0, 80, 381));
		  printf("intersection: zero rect empty=%d, disjoint null=%d, caret %g %g %g %g\n", (int)CGRectIsEmpty(z), (int)CGRectIsNull(o), q.origin.x, q.origin.y, q.size.width, q.size.height); }
		return dark > 0 ? 0 : 1;
	}
}
