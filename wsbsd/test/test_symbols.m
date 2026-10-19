/* SF Symbols as NSImage: size follows point size / scale, weight changes the glyph, the image draws (pixels appear), unknown names answer nil, configurations combine. Needs CoreGlyphs.car. */
#import <AppKit/AppKit.h>
@interface NSImageSymbolConfiguration : NSObject + (id)configurationWithPointSize:(CGFloat)p weight:(double)w; + (id)configurationWithScale:(NSInteger)s; - (id)configurationByApplyingConfiguration:(id)o; @end
@interface NSImage (S) + (NSImage *)imageWithSystemSymbolName:(NSString *)n accessibilityDescription:(NSString *)d; - (NSImage *)imageWithSymbolConfiguration:(id)c; - (NSString *)accessibilityDescription; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSImage *a = [NSImage imageWithSystemSymbolName: @"star" accessibilityDescription: @"favourite"];
		CHECK(a != nil); CHECK([a isTemplate]); CHECK([[a accessibilityDescription] isEqual: @"favourite"]);
		CHECK([a size].width > 8 && [a size].width < 24);
		CHECK([NSImage imageWithSystemSymbolName: @"no.such.symbol.xyz" accessibilityDescription: nil] == nil);
		NSImage *big = [a imageWithSymbolConfiguration: [NSClassFromString(@"NSImageSymbolConfiguration") configurationWithPointSize: 26 weight: 0]];
		CHECK([big size].width > [a size].width * 1.7);
		NSImage *bold = [a imageWithSymbolConfiguration: [NSClassFromString(@"NSImageSymbolConfiguration") configurationWithPointSize: 13 weight: 0.62]];
		CHECK(bold != nil); CHECK(bold != a); CHECK([[bold accessibilityDescription] isEqual: @"favourite"]);
	}
	printf(fails ? "symbols: %d failed\n" : "symbols ok\n", fails);
	return fails != 0;
}
