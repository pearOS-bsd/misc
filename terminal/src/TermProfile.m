#import "TermProfile.h"

typedef struct { const char *name; float bg[4], fg[4], bold[4], cursor[4], sel[4]; const char *font; float fontSize, widthSpacing, blur; int cols, rows, blink, antialias; float ansi[16][4]; } ProfileData;
static const ProfileData DATA[] = {
#include "Profiles.inc"
};
/* Terminal's own ANSI palette (the profiles that do not define one use it) */
static const uint32_t DEFAULT_ANSI[16] = { 0x000000, 0x990000, 0x00A600, 0x999900, 0x0000B2, 0xB200B2, 0x00A6B2, 0xBFBFBF, 0x666666, 0xE50000, 0x00D900, 0xE5E500, 0x0000FF, 0xE500E5, 0x00E5E5, 0xE5E5E5 };

static NSColor *col(const float *c, double r, double g, double b)
{
	if (c[0] < 0) return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1.0];
	return [NSColor colorWithCalibratedRed: c[0] green: c[1] blue: c[2] alpha: c[3]];
}

@implementation TermProfile
+ (NSArray *)allProfiles
{
	static NSMutableArray *all;
	if (!all) {
		all = [[NSMutableArray alloc] init];
		static const char *order[] = { "Basic", "Clear Dark", "Clear Light", "Grass", "Homebrew", "Man Page", "Novel", "Ocean", "Pro", "Red Sands", "Silver Aerogel", "Solid Colors" };
		for (size_t o = 0; o < sizeof order / sizeof order[0]; o++) for (size_t i = 0; i < sizeof DATA / sizeof DATA[0]; i++) if (!strcmp(DATA[i].name, order[o])) {
			const ProfileData *d = &DATA[i]; TermProfile *p = [[TermProfile alloc] init];
			p->name = [[NSString stringWithUTF8String: d->name] retain];
			p->background = [col(d->bg, 1, 1, 1) retain]; p->text = [col(d->fg, 0, 0, 0) retain]; p->boldText = [col(d->bold, 0, 0, 0) retain];
			p->cursor = [col(d->cursor, 0.5, 0.5, 0.5) retain]; p->selection = [col(d->sel, 0.7, 0.8, 1.0) retain];
			p->fontName = [[NSString stringWithUTF8String: d->font] retain]; p->fontSize = d->fontSize; p->widthSpacing = d->widthSpacing; p->blur = d->blur; p->cols = d->cols; p->rows = d->rows; p->blink = d->blink; p->antialias = d->antialias;
			for (int k = 0; k < 16; k++) {
				if (d->ansi[k][0] >= 0) p->ansi[k] = ((uint32_t)(d->ansi[k][0] * 255 + 0.5) << 16) | ((uint32_t)(d->ansi[k][1] * 255 + 0.5) << 8) | (uint32_t)(d->ansi[k][2] * 255 + 0.5);
				else p->ansi[k] = DEFAULT_ANSI[k];
			}
			[all addObject: p]; [p release];
		}
		[self loadOverrides];
	}
	return all;
}
+ (void)loadOverrides
{
	NSDictionary *o = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Window Settings"];
	for (TermProfile *p in [self allProfiles]) {
		NSDictionary *d = [o objectForKey:p->name]; if (![d isKindOfClass:[NSDictionary class]]) continue;
		#define COL(key, field) { NSArray *a = [d objectForKey:key]; if ([a count] == 4) { [p->field release]; p->field = [[NSColor colorWithCalibratedRed:[[a objectAtIndex:0] doubleValue] green:[[a objectAtIndex:1] doubleValue] blue:[[a objectAtIndex:2] doubleValue] alpha:[[a objectAtIndex:3] doubleValue]] retain]; } }
		COL(@"BackgroundColor", background) COL(@"TextColor", text) COL(@"TextBoldColor", boldText) COL(@"CursorColor", cursor) COL(@"SelectionColor", selection)
		if ([d objectForKey:@"FontSize"]) p->fontSize = [[d objectForKey:@"FontSize"] doubleValue];
		if ([d objectForKey:@"BackgroundBlur"]) p->blur = [[d objectForKey:@"BackgroundBlur"] doubleValue];
		if ([d objectForKey:@"columnCount"]) p->cols = [[d objectForKey:@"columnCount"] intValue];
		if ([d objectForKey:@"rowCount"]) p->rows = [[d objectForKey:@"rowCount"] intValue];
		if ([d objectForKey:@"CursorBlink"]) p->blink = [[d objectForKey:@"CursorBlink"] boolValue];
		if ([d objectForKey:@"FontAntialias"]) p->antialias = [[d objectForKey:@"FontAntialias"] boolValue];
	}
}
+ (TermProfile *)profileNamed:(NSString *)n { for (TermProfile *p in [self allProfiles]) if ([p->name isEqualToString: n]) return p; return nil; }
+ (TermProfile *)defaultProfile
{
	NSString *n = [[NSUserDefaults standardUserDefaults] stringForKey: @"Default Window Settings"]; TermProfile *p = n ? [self profileNamed: n] : nil;
	return p ?: [self profileNamed: @"Pro"] ?: [[self allProfiles] objectAtIndex: 0];
}
+ (void)setDefaultProfile:(TermProfile *)p { [[NSUserDefaults standardUserDefaults] setObject: p->name forKey: @"Default Window Settings"]; [[NSUserDefaults standardUserDefaults] synchronize]; }
static NSArray *colArray(NSColor *c) { NSColor *r = [c colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; return [NSArray arrayWithObjects:[NSNumber numberWithDouble:[r redComponent]], [NSNumber numberWithDouble:[r greenComponent]], [NSNumber numberWithDouble:[r blueComponent]], [NSNumber numberWithDouble:[r alphaComponent]], nil]; }
- (void)changed
{
	NSMutableDictionary *all = [[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Window Settings"] mutableCopy] autorelease] ?: [NSMutableDictionary dictionary];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:colArray(background), @"BackgroundColor", colArray(text), @"TextColor", colArray(boldText), @"TextBoldColor", colArray(cursor), @"CursorColor", colArray(selection), @"SelectionColor",
		[NSNumber numberWithDouble:fontSize], @"FontSize", [NSNumber numberWithDouble:blur], @"BackgroundBlur", [NSNumber numberWithInt:cols], @"columnCount", [NSNumber numberWithInt:rows], @"rowCount", [NSNumber numberWithBool:blink], @"CursorBlink", [NSNumber numberWithBool:antialias], @"FontAntialias", nil];
	[all setObject:d forKey:name]; [[NSUserDefaults standardUserDefaults] setObject:all forKey:@"Window Settings"]; [[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TermProfileChanged" object:self];
}
- (NSFont *)fontWithSize:(CGFloat)size bold:(BOOL)bold
{
	/* the faces of Terminal.app are SF Mono (the "SFMonoTerminal" faces), Monaco, Andale Mono, Courier: use them when the system has them, else the system's fixed pitch face */
	NSString *n = fontName; if ([n hasPrefix: @"SFMonoTerminal"]) n = bold ? @"SFMono-Bold" : @"SFMono-Regular";
	NSFont *f = [NSFont fontWithName: n size: size];
	if (!f && bold) f = [NSFont fontWithName: [fontName stringByAppendingString: @"-Bold"] size: size];
	if (!f) f = [NSFont fontWithName: bold ? @"Menlo-Bold" : @"Menlo-Regular" size: size];
	if (!f) f = [NSFont userFixedPitchFontOfSize: size];
	return f;
}
@end
