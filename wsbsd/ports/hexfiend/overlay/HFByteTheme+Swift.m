/* Port of HFByteTheme.swift: the JSON byte colour themes of the application */
#import "Hex_Fiend-Swift.h"

static NSColor *RGB(NSColor *c) { NSColor *r = [c colorUsingColorSpaceName: NSCalibratedRGBColorSpace]; return r ? r : c; }

static NSDictionary<NSString *, NSColor *> *NamesToColors(void)
{
	static NSDictionary *map;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		map = @{ @"black": RGB([NSColor blackColor]), @"blue": RGB([NSColor blueColor]), @"brown": RGB([NSColor brownColor]), @"clear": RGB([NSColor clearColor]),
		         @"cyan": RGB([NSColor cyanColor]), @"darkGray": RGB([NSColor darkGrayColor]), @"gray": RGB([NSColor grayColor]), @"green": RGB([NSColor greenColor]),
		         @"lightGray": RGB([NSColor lightGrayColor]), @"magenta": RGB([NSColor magentaColor]), @"orange": RGB([NSColor orangeColor]), @"purple": RGB([NSColor purpleColor]),
		         @"red": RGB([NSColor redColor]), @"white": RGB([NSColor whiteColor]), @"yellow": RGB([NSColor yellowColor]),
		         @"systemBlue": RGB([NSColor blueColor]), @"systemBrown": RGB([NSColor brownColor]), @"systemGray": RGB([NSColor grayColor]), @"systemGreen": RGB([NSColor greenColor]),
		         @"systemMint": RGB([NSColor colorWithCalibratedRed: 0.0 green: 0.78 blue: 0.75 alpha: 1]), @"systemOrange": RGB([NSColor orangeColor]),
		         @"systemPink": RGB([NSColor colorWithCalibratedRed: 1.0 green: 0.18 blue: 0.33 alpha: 1]), @"systemPurple": RGB([NSColor purpleColor]), @"systemRed": RGB([NSColor redColor]),
		         @"systemTeal": RGB([NSColor colorWithCalibratedRed: 0.19 green: 0.69 blue: 0.78 alpha: 1]), @"systemYellow": RGB([NSColor yellowColor]),
		         @"systemIndigo": RGB([NSColor colorWithCalibratedRed: 0.35 green: 0.34 blue: 0.84 alpha: 1]), @"systemCyan": RGB([NSColor cyanColor]) };
	});
	return map;
}

static NSColor *ValueToColor(id value)
{
	if ([value isKindOfClass: [NSString class]]) {
		NSColor *c = NamesToColors()[value];
		if (!c) NSLog(@"Unknown color %@", value);
		return c;
	}
	if ([value isKindOfClass: [NSNumber class]]) {
		NSUInteger v = [value unsignedIntegerValue];
		return RGB([NSColor colorWithCalibratedRed: ((v & 0xFF0000) >> 16) / 255.0 green: ((v & 0x00FF00) >> 8) / 255.0 blue: (v & 0x0000FF) / 255.0 alpha: 1.0]);
	}
	NSLog(@"Unknown color value %@", value);
	return nil;
}

static struct HFByteThemeColor ThemeColor(NSColor *color)
{
	CGFloat r = 0, g = 0, b = 0; [color getRed: &r green: &g blue: &b alpha: NULL];
	return (struct HFByteThemeColor){ r, g, b, YES };
}

static struct HFByteThemeColor *ColorTable(NSDictionary *dict)
{
	struct HFByteThemeColor *table = calloc(256, sizeof *table);
	NSArray *custom = [dict[@"custom"] isKindOfClass: [NSArray class]] ? dict[@"custom"] : @[];
	for (int b = 0; b < 256; b++) {
		BOOL done = NO;
		for (NSDictionary<NSString *, NSString *> *item in custom) {
			for (NSString *format in item) {
				__block BOOL evaluated = NO;
				NSException *exception = HFTry(^{ evaluated = [[NSPredicate predicateWithFormat: format] evaluateWithObject: nil substitutionVariables: @{ @"b": @(b) }]; });
				if (exception) { NSLog(@"Predicate error: %@", exception); continue; }
				NSColor *color = evaluated ? ValueToColor(item[format]) : nil;
				if (color) { table[b] = ThemeColor(color); done = YES; break; }
			}
			if (done) break;
		}
		if (done) continue;
		const char *key;
		if (b == ' ' || b == '\n' || b == '\r' || b == '\t') key = "whitespace";
		else if (b >= 33 && b <= 126) key = "printable";
		else if (b == 0) key = "null";
		else if (b & 0x80) key = "extended";
		else key = "other";
		id value = dict[@(key)];
		NSColor *color = value ? ValueToColor(value) : nil;
		if (color) table[b] = ThemeColor(color);
	}
	return table;
}

@implementation HFByteTheme (HFByteThemeFromURL)
+ (instancetype)fromUrl: (NSURL *)url
{
	NSData *data = [NSData dataWithContentsOfURL: url];
	NSError *error = nil;
	NSDictionary *top = data ? [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error] : nil;
	if (![top isKindOfClass: [NSDictionary class]]) { NSLog(@"Invalid json at %@: %@", url, error); return nil; }
	if (![top[@"dark"] isKindOfClass: [NSDictionary class]]) { NSLog(@"Invalid \"dark\" at %@!", url); return nil; }
	if (![top[@"light"] isKindOfClass: [NSDictionary class]]) { NSLog(@"Invalid \"light\" at %@!", url); return nil; }
	HFByteTheme *theme = [[self alloc] init];
	theme.darkColorTable = ColorTable(top[@"dark"]);
	theme.lightColorTable = ColorTable(top[@"light"]);
	return theme;
}
@end
