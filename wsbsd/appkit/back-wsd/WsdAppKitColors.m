/* NSColor's semantic and system colours that GNUstep lacks, with the values AppKit of macOS 27 returns in the light and the dark appearance (read from the real class on a Mac, sRGB);
 * the appearance is the one the theme uses (WSD_APPEARANCE=light, dark otherwise). */
#import <AppKit/AppKit.h>
static BOOL WsdDark(void) { const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }
static NSColor *C(double r, double g, double b, double a) { return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: a]; }
#define PICK(l0, l1, l2, l3, d0, d1, d2, d3) return WsdDark() ? C(d0, d1, d2, d3) : C(l0, l1, l2, l3)
@implementation NSColor (WsdAppKit)
+ (NSColor *)controlAccentColor { PICK(0.0000, 0.4784, 1.0000, 1.0000, 0.0000, 0.4784, 1.0000, 1.0000); }
+ (NSColor *)findHighlightColor { PICK(1.0000, 1.0000, 0.0000, 1.0000, 1.0000, 1.0000, 0.0000, 1.0000); }
+ (NSColor *)linkColor { PICK(0.0000, 0.4078, 0.8549, 1.0000, 0.2549, 0.6118, 1.0000, 1.0000); }
+ (NSColor *)placeholderTextColor { PICK(0.0000, 0.0000, 0.0000, 0.4980, 1.0000, 1.0000, 1.0000, 0.5490); }
+ (NSColor *)quaternarySystemFillColor { PICK(0.0000, 0.0000, 0.0000, 0.0275, 1.0000, 1.0000, 1.0000, 0.0275); }
+ (NSColor *)quinaryLabelColor { PICK(0.0000, 0.0000, 0.0000, 0.0471, 1.0000, 1.0000, 1.0000, 0.0471); }
+ (NSColor *)quinarySystemFillColor { PICK(0.0000, 0.0000, 0.0000, 0.0078, 1.0000, 1.0000, 1.0000, 0.0078); }
+ (NSColor *)secondarySystemFillColor { PICK(0.0000, 0.0000, 0.0000, 0.0784, 1.0000, 1.0000, 1.0000, 0.0784); }
+ (NSColor *)selectedContentBackgroundColor { PICK(0.0000, 0.3922, 0.8824, 1.0000, 0.0000, 0.3490, 0.8196, 1.0000); }
+ (NSColor *)separatorColor { PICK(0.0000, 0.0000, 0.0000, 0.0980, 1.0000, 1.0000, 1.0000, 0.0980); }
+ (NSColor *)systemCyanColor { PICK(0.0000, 0.7529, 0.9098, 1.0000, 0.2353, 0.8275, 0.9961, 1.0000); }
+ (NSColor *)systemFillColor { PICK(0.0000, 0.0000, 0.0000, 0.0980, 1.0000, 1.0000, 1.0000, 0.0980); }
+ (NSColor *)systemMintColor { PICK(0.0000, 0.7843, 0.7020, 1.0000, 0.0000, 0.8549, 0.7647, 1.0000); }
+ (NSColor *)tertiarySystemFillColor { PICK(0.0000, 0.0000, 0.0000, 0.0471, 1.0000, 1.0000, 1.0000, 0.0471); }
+ (NSColor *)textInsertionPointColor { PICK(0.0000, 0.4784, 1.0000, 1.0000, 0.0000, 0.4784, 1.0000, 1.0000); }
+ (NSColor *)underPageBackgroundColor { PICK(0.9647, 0.9647, 0.9647, 1.0000, 0.1569, 0.1569, 0.1569, 1.0000); }
+ (NSColor *)unemphasizedSelectedContentBackgroundColor { PICK(0.8627, 0.8627, 0.8627, 1.0000, 0.2745, 0.2745, 0.2745, 1.0000); }
+ (NSColor *)unemphasizedSelectedTextBackgroundColor { PICK(0.8627, 0.8627, 0.8627, 1.0000, 0.2745, 0.2745, 0.2745, 1.0000); }
+ (NSColor *)unemphasizedSelectedTextColor { PICK(0.0000, 0.0000, 0.0000, 1.0000, 1.0000, 1.0000, 1.0000, 1.0000); }
+ (NSArray *)alternatingContentBackgroundColors { return WsdDark() ? @[ C(0.1176, 0.1176, 0.1176, 1.0000), C(1.0000, 1.0000, 1.0000, 0.0471) ] : @[ C(1.0000, 1.0000, 1.0000, 1.0000), C(0.9569, 0.9608, 0.9608, 1.0000) ]; }
@end
