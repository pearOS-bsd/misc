/* Port of HFByteTheme.swift: the JSON byte colour themes of the application */
#import "Hex_Fiend-Swift.h"
#include <ctype.h>

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


/* ---- JSON5 (what the .json5 theme files are): unquoted keys, 0x numbers, comments, trailing commas, single quotes. Foundation's JSON reader on Apple takes the .json5Allowed option;
 * GNUstep's has none, so this small recursive reader does the part the themes use. ---- */
@interface WsbsdJSON5 : NSObject { const char *p, *end; }
- (id)parse: (NSData *)data;
@end
@implementation WsbsdJSON5
- (void)skip
{
	for (;;) {
		while (p < end && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
		if (p + 1 < end && p[0] == '/' && p[1] == '/') { while (p < end && *p != '\n') p++; }
		else if (p + 1 < end && p[0] == '/' && p[1] == '*') { p += 2; while (p + 1 < end && !(p[0] == '*' && p[1] == '/')) p++; p += 2; }
		else break;
	}
}
- (NSString *)string
{
	char q = *p++; NSMutableString *r = [NSMutableString string];
	while (p < end && *p != q) {
		if (*p == '\\' && p + 1 < end) { p++; char c = *p; r = (NSMutableString *)[r stringByAppendingFormat: @"%c", c == 'n' ? '\n' : c == 't' ? '\t' : c]; p++; continue; }
		[r appendFormat: @"%c", *p]; p++;
	}
	p++; return r;
}
- (NSString *)identifier
{
	const char *s = p; while (p < end && (isalnum((unsigned char)*p) || *p == '_' || *p == '$')) p++;
	return [[NSString alloc] initWithBytes: s length: (NSUInteger)(p - s) encoding: NSUTF8StringEncoding];
}
- (id)value
{
	[self skip]; if (p >= end) return nil;
	if (*p == '{') {
		p++; NSMutableDictionary *d = [NSMutableDictionary dictionary];
		for (;;) {
			[self skip]; if (p >= end) return nil; if (*p == '}') { p++; return d; }
			NSString *k = (*p == '"' || *p == '\'') ? [self string] : [self identifier]; if (![k length]) return nil;
			[self skip]; if (p >= end || *p != ':') return nil; p++;
			id v = [self value]; if (!v) return nil; d[k] = v;
			[self skip]; if (p < end && *p == ',') p++;
		}
	}
	if (*p == '[') {
		p++; NSMutableArray *a = [NSMutableArray array];
		for (;;) { [self skip]; if (p >= end) return nil; if (*p == ']') { p++; return a; } id v = [self value]; if (!v) return nil; [a addObject: v]; [self skip]; if (p < end && *p == ',') p++; }
	}
	if (*p == '"' || *p == '\'') return [self string];
	if (*p == '-' || *p == '+' || isdigit((unsigned char)*p)) {
		char *e; BOOL neg = *p == '-'; if (*p == '-' || *p == '+') p++;
		unsigned long long v = strtoull(p, &e, (p + 1 < end && p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) ? 16 : 10);
		if (e && (*e == '.' || *e == 'e' || *e == 'E')) { double dv = strtod(p, &e); p = e; return @(neg ? -dv : dv); }
		p = e; return neg ? @(-(long long)v) : @(v);
	}
	NSString *w = [self identifier];
	if ([w isEqualToString: @"true"]) return @YES; if ([w isEqualToString: @"false"]) return @NO; if ([w isEqualToString: @"null"]) return [NSNull null];
	return nil;
}
- (id)parse: (NSData *)data { p = [data bytes]; end = p + [data length]; return [self value]; }
@end

@implementation HFByteTheme (HFByteThemeFromURL)
+ (instancetype)fromUrl: (NSURL *)url
{
	NSData *data = [NSData dataWithContentsOfURL: url];
	NSError *error = nil;
	NSDictionary *top = data ? [[[WsbsdJSON5 alloc] init] parse: data] : nil;
	if (![top isKindOfClass: [NSDictionary class]]) { NSLog(@"Invalid json at %@: %@", url, error); return nil; }
	if (![top[@"dark"] isKindOfClass: [NSDictionary class]]) { NSLog(@"Invalid \"dark\" at %@!", url); return nil; }
	if (![top[@"light"] isKindOfClass: [NSDictionary class]]) { NSLog(@"Invalid \"light\" at %@!", url); return nil; }
	HFByteTheme *theme = [[self alloc] init];
	theme.darkColorTable = ColorTable(top[@"dark"]);
	theme.lightColorTable = ColorTable(top[@"light"]);
	return theme;
}
@end
