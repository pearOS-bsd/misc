/* An NSBitmapImageRep with 3 samples in 32 bits per pixel (RGB + one unused byte, as GrandPerspective makes its tree image) drawn into a bitmap: the colour must arrive, opaque. */
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat.h>
extern char **environ;
int main(int argc, char *argv[])
{
#ifdef GNUSTEP
	[NSProcessInfo initializeWithArguments: argv count: argc environment: environ];
#endif
	int failures = 0;
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSBitmapImageRep *src = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: 8 pixelsHigh: 8 bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 0 bitsPerPixel: 32];
		uint8_t *d = [src bitmapData];
		for (int i = 0; i < 8 * 8; i++) { d[i * 4] = 200; d[i * 4 + 1] = 40; d[i * 4 + 2] = 10; d[i * 4 + 3] = 0; }
		NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(8, 8)]; [img addRepresentation: src];
		NSBitmapImageRep *dst = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: 8 pixelsHigh: 8 bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 0 bitsPerPixel: 32];
		NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep: dst];
		[NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext: gc];
		[img drawInRect: NSMakeRect(0, 0, 8, 8) fromRect: NSZeroRect operation: NSCompositingOperationCopy fraction: 1.0];
		[gc flushGraphics]; [NSGraphicsContext restoreGraphicsState];
		const uint8_t *q = [dst bitmapData];
		printf("dst pixel %d %d %d %d\n", q[0], q[1], q[2], q[3]); fflush(stdout);
		if (!(abs(q[0] - 200) < 3 && abs(q[1] - 40) < 3 && abs(q[2] - 10) < 3 && q[3] == 255)) { failures++; printf("FAIL: the colour of the 3-sample bitmap did not arrive opaque\n"); }
	}
	return failures != 0;
}
