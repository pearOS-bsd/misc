/* Opal behaviour probe: two bitmap contexts drawing in turn into the same memory */
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>
int main(void)
{
	enum { W = 64, H = 64 };
	uint32_t *mem = calloc(W * H, 4);
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	for (int round = 0; round < 3; round++) {
		CGContextRef g = CGBitmapContextCreate(mem, W, H, 8, W * 4, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		CGContextSetRGBFillColor(g, round == 0 ? 1 : 0, round == 1 ? 1 : 0, round == 2 ? 1 : 0, 1);
		CGContextFillRect(g, CGRectMake(round * 10, 0, 8, 8));
		CGContextFlush(g);
		printf("round %d: ctx %p, pixel(%d,%d)=%08x (expected a colour)\n", round, (void *)g, round * 10 + 2, H - 4, mem[(H - 4) * W + round * 10 + 2]);
		CGContextRelease(g);
	}
	return 0;
}
