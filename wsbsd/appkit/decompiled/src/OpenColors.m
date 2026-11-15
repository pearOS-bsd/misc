/* OpenColors.m — the colours of the system (NSColor class methods of the catalogue), values of the dark appearance (docs/UI-MAC.md, appkit/back-wsd/WsdMacTheme.m): the programs ask for textColor, labelColor, windowBackgroundColor... */
#import <Foundation/Foundation.h>
#import "NSColor.h"

static NSColor *C(int r, int g, int b, double a) { return [NSColor colorWithCalibratedRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a]; }
@implementation NSColor (OpenSystemColors)
+ (NSColor *)labelColor { return C(255, 255, 255, 0.85); }
+ (NSColor *)secondaryLabelColor { return C(255, 255, 255, 0.55); }
+ (NSColor *)tertiaryLabelColor { return C(255, 255, 255, 0.25); }
+ (NSColor *)quaternaryLabelColor { return C(255, 255, 255, 0.10); }
+ (NSColor *)textColor { return C(255, 255, 255, 0.85); }
+ (NSColor *)controlTextColor { return C(255, 255, 255, 0.85); }
+ (NSColor *)disabledControlTextColor { return C(255, 255, 255, 0.25); }
+ (NSColor *)selectedTextColor { return C(255, 255, 255, 1); }
+ (NSColor *)selectedControlTextColor { return C(255, 255, 255, 1); }
+ (NSColor *)selectedMenuItemTextColor { return C(255, 255, 255, 1); }
+ (NSColor *)alternateSelectedControlTextColor { return C(255, 255, 255, 1); }
+ (NSColor *)headerTextColor { return C(255, 255, 255, 0.85); }
+ (NSColor *)placeholderTextColor { return C(255, 255, 255, 0.25); }
+ (NSColor *)windowFrameTextColor { return C(255, 255, 255, 0.85); }
+ (NSColor *)textBackgroundColor { return C(23, 24, 25, 1); }
+ (NSColor *)windowBackgroundColor { return C(30, 30, 30, 1); }
+ (NSColor *)controlBackgroundColor { return C(30, 30, 30, 1); }
+ (NSColor *)controlColor { return C(63, 63, 63, 1); }
+ (NSColor *)underPageBackgroundColor { return C(38, 38, 38, 1); }
+ (NSColor *)selectedTextBackgroundColor { return C(63, 96, 130, 1); }
+ (NSColor *)unemphasizedSelectedTextBackgroundColor { return C(72, 72, 72, 1); }
+ (NSColor *)selectedContentBackgroundColor { return C(0, 88, 208, 1); }
+ (NSColor *)unemphasizedSelectedContentBackgroundColor { return C(72, 72, 72, 1); }
+ (NSColor *)selectedControlColor { return C(72, 72, 72, 1); }
+ (NSColor *)selectedMenuItemColor { return C(0, 122, 255, 1); }
+ (NSColor *)alternatingContentBackgroundColors { return nil; }
+ (NSArray *)alternatingContentBackgroundColorsArray { return @[ C(30, 30, 30, 1), C(38, 38, 38, 1) ]; }
+ (NSColor *)separatorColor { return C(255, 255, 255, 0.10); }
+ (NSColor *)gridColor { return C(255, 255, 255, 0.10); }
+ (NSColor *)highlightColor { return C(255, 255, 255, 0.2); }
+ (NSColor *)shadowColor { return C(0, 0, 0, 1); }
+ (NSColor *)linkColor { return C(65, 156, 255, 1); }
+ (NSColor *)findHighlightColor { return C(255, 255, 0, 0.5); }
+ (NSColor *)keyboardFocusIndicatorColor { return C(0, 122, 255, 0.5); }
+ (NSColor *)controlAccentColor { return C(0, 122, 255, 1); }
+ (NSColor *)systemBlueColor { return C(10, 132, 255, 1); }
+ (NSColor *)systemRedColor { return C(255, 69, 58, 1); }
+ (NSColor *)systemGreenColor { return C(50, 215, 75, 1); }
+ (NSColor *)systemOrangeColor { return C(255, 159, 10, 1); }
+ (NSColor *)systemYellowColor { return C(255, 214, 10, 1); }
+ (NSColor *)systemPinkColor { return C(255, 55, 95, 1); }
+ (NSColor *)systemPurpleColor { return C(191, 90, 242, 1); }
+ (NSColor *)systemTealColor { return C(100, 210, 255, 1); }
+ (NSColor *)systemIndigoColor { return C(94, 92, 230, 1); }
+ (NSColor *)systemBrownColor { return C(172, 142, 104, 1); }
+ (NSColor *)systemGrayColor { return C(152, 152, 157, 1); }
+ (NSColor *)lightGrayColor { return C(170, 170, 170, 1); }
+ (NSColor *)darkGrayColor { return C(85, 85, 85, 1); }
+ (NSColor *)orangeColor { return C(255, 128, 0, 1); }
+ (NSColor *)purpleColor { return C(128, 0, 128, 1); }
+ (NSColor *)brownColor { return C(153, 102, 51, 1); }
@end

/* ---- colours of the asset catalogue of the program (+colorNamed:): layout 1009 renditions, "RLOC" 1 colourspace count + doubles (r g b a, or gray a) ---- */
#include "car.h"
#include <string.h>
static CarFile *CatalogOf(NSBundle *b)
{
    static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary new];
    NSString *p = [[b resourcePath] stringByAppendingPathComponent:@"Assets.car"]; NSValue *v = cache[p]; if (v) return [v pointerValue];
    CarFile *f = [[NSFileManager defaultManager] fileExistsAtPath:p] ? car_open([p fileSystemRepresentation]) : NULL; cache[p] = [NSValue valueWithPointer:f]; return f;
}
@implementation NSColor (OpenCatalog)
+ (NSColor *)colorNamed:(NSString *)name bundle:(NSBundle *)bundle
{
    NSBundle *b = bundle ?: [NSBundle mainBundle]; CarFile *f = CatalogOf(b);
    if (f) {
        int n = car_count(f);
        for (int i = 0; i < n; i++) {
            CarRendition r; if (car_rendition(f, i, &r) || r.layout != 1009 || strcmp(r.name, [name UTF8String])) continue;
            if (r.payload_len < 16 || memcmp(r.payload, "RLOC", 4)) continue;
            uint32_t cnt; memcpy(&cnt, r.payload + 12, 4); double c[4] = { 0, 0, 0, 1 };
            if (cnt >= 4 && r.payload_len >= 16 + 32) memcpy(c, r.payload + 16, 32); else if (cnt >= 2 && r.payload_len >= 16 + 16) { double g[2]; memcpy(g, r.payload + 16, 16); c[0] = c[1] = c[2] = g[0]; c[3] = g[1]; }
            return [NSColor colorWithCalibratedRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
        }
    }
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: colour %s not in the catalogue\n", [name UTF8String]);
    return nil;
}
+ (NSColor *)colorNamed:(NSString *)name { return [self colorNamed:name bundle:nil]; }
@end
