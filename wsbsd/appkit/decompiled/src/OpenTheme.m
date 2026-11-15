/* OpenTheme.m — the look of the windows of pearOS in the programs of the "open" layer, ported from appkit/back-wsd/WsdMacTheme.m and WsdFilePanel.m onto CoreGraphics:
 * the title bar (32 pt; fill derived from the window colour, the title in the title colours, 16 x 16 pt buttons at x = 8, 31, 54 from the left and 8 from the top) and the window
 * buttons themselves, the pictures of the Mac's own catalogue (Aqua.car / DarkAqua.car, "WindowFrame_WindowControlButtons_Regular": Dimension1 the button 0 close 1 minimize 2 zoom
 * 3 close of an edited document, State 0 rest 1 pointer over the group (the glyph) 2 pressed), read with coreui/car.c. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import "NSFont.h"
#import "NSApplication.h"
#include "car.h"
#include <math.h>

static CarFile *CarOpen(const char *name)
{
    static CarFile *cars[2]; static BOOL tried[2]; int k = !strcmp(name, "DarkAqua");
    if (!tried[k]) {
        tried[k] = YES; char p[512];
        const char *dirs[] = { getenv("WSBSD_COREUI") ?: "/open/coreui", "/usr/local/share/wsbsd/coreui", "/root/wsbsd/coreui/assets", NULL };
        for (int i = 0; dirs[i] && !cars[k]; i++) { snprintf(p, sizeof p, "%s/%s.car", dirs[i], name); cars[k] = car_open(p); }
        if (!cars[k] && getenv("OPEN_DEBUG")) fprintf(stderr, "open: %s.car not found\n", name);
    }
    return cars[k];
}

/* the picture of a window button: BGRA premultiplied pixels of the catalogue as a CGImage (cached) */
CGImageRef OpenWindowButtonImage(int kind, int state, BOOL dark)
{
    static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary new];
    NSString *key = [NSString stringWithFormat:@"%d.%d.%d", kind, state, dark]; id hit = cache[key]; if (hit) return hit == [NSNull null] ? NULL : (__bridge CGImageRef)hit;
    CGImageRef img = NULL; CarFile *car = CarOpen(dark ? "DarkAqua" : "Aqua"); if (!car) car = CarOpen(dark ? "Aqua" : "DarkAqua");
    if (car) {
        int at[32]; for (int i = 0; i < 32; i++) at[i] = -1; at[1] = 24; at[2] = 1; at[8] = kind; at[10] = state; at[12] = 1; at[14] = 0;
        CarRendition r; int w, h, bpp; uint8_t *px = NULL;
        if (!car_find_attrs(car, "WindowFrame_WindowControlButtons_Regular.psd", at, &r)) px = car_bitmap_linked(car, &r, &w, &h, &bpp);
        if (px && bpp == 4) {
            NSData *d = [NSData dataWithBytes:px length:(NSUInteger)w * h * 4]; CGDataProviderRef dp = CGDataProviderCreateWithCFData((__bridge CFDataRef)d);
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            img = CGImageCreate(w, h, 8, 32, (size_t)w * 4, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, dp, NULL, false, kCGRenderingIntentDefault);
            CGColorSpaceRelease(cs); CGDataProviderRelease(dp);
        }
        free(px);
    }
    cache[key] = img ? (__bridge_transfer id)img : (id)[NSNull null]; return img;
}

/* a grey disc: the buttons of a window that is not the key one (until the pointer comes over them) */
static void GreyDisc(CGContextRef cg, CGRect r)
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat c[12] = { 67 / 255.0, 67 / 255.0, 67 / 255.0, 1, 71 / 255.0, 71 / 255.0, 71 / 255.0, 1, 76 / 255.0, 76 / 255.0, 76 / 255.0, 1 }, loc[3] = { 0, 0.45, 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, c, loc, 3);
    CGContextSaveGState(cg); CGContextAddEllipseInRect(cg, CGRectInset(r, 0.5, 0.5)); CGContextClip(cg);
    CGContextDrawLinearGradient(cg, g, CGPointMake(0, r.origin.y + r.size.height), CGPointMake(0, r.origin.y), 0); CGContextRestoreGState(cg);
    CGContextSetRGBStrokeColor(cg, 0, 0, 0, 0.06); CGContextSetLineWidth(cg, 1); CGContextStrokeEllipseInRect(cg, CGRectInset(r, 0.5, 0.5));
    CGGradientRelease(g); CGColorSpaceRelease(cs);
}

/* the title bar into the top TB points of the window (CG: y up, the bar is at the top) */
#define OPEN_TB 32.0
void OpenDrawTitleBar(CGContextRef cg, CGFloat W, CGFloat H, NSString *title, BOOL key, BOOL hover, int pressed, BOOL edited, BOOL hasClose, BOOL hasMini, BOOL hasZoom)
{
    int wb = 30, bg = key ? (int)(wb * (1 - 0.035) + 255 * 0.035 + 0.5) : wb + 4;			/* WsdMacTheme.m: dark, windowBG 30 */
    CGContextSetRGBFillColor(cg, bg / 255.0, bg / 255.0, bg / 255.0, 1); CGContextFillRect(cg, CGRectMake(0, H - OPEN_TB, W, OPEN_TB));
    if ([title length]) {
        int tc = key ? 160 : 110;
        NSDictionary *at = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:tc / 255.0 alpha:1] };
        CGSize ts = [title sizeWithAttributes:at]; [title drawAtPoint:CGPointMake(82, H - OPEN_TB + 8 + (16 - ts.height) / 2) withAttributes:at];
    }
    BOOL en[3] = { hasClose, hasMini, hasZoom };
    for (int i = 0; i < 3; i++) {
        CGRect r = CGRectMake(8 + 23 * i, H - OPEN_TB + 8, 16, 16);
        BOOL p = pressed == i;
        if (en[i] && (key || hover || p)) {
            int kind = (i == 0 && edited) ? 3 : i, state = p ? 2 : (hover ? 1 : 0); CGImageRef im = OpenWindowButtonImage(kind, state, YES);
            if (im) { if (p) { double k = 1.143; r = CGRectMake(CGRectGetMidX(r) - 8 * k, CGRectGetMidY(r) - 8 * k, 16 * k, 16 * k); } CGContextDrawImage(cg, r, im); continue; }
        }
        GreyDisc(cg, CGRectInset(r, 1, 1));
    }
}
