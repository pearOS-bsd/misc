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

/* ---- the controls, ported from WsdMacTheme.m (dark appearance, window colour 30): every number is the one of the theme ---- */
static int Mix(int base, int top, double a) { return (int)(base * (1 - a) + top * a + 0.5); }
static void OnBG(double a, CGFloat *c) { int v = Mix(30, 255, a); c[0] = c[1] = c[2] = v / 255.0; }
static void FillRound(CGContextRef cg, CGRect r, CGFloat rad, CGFloat R, CGFloat G, CGFloat B, CGFloat A)
{
    if (rad * 2 > r.size.height) rad = r.size.height / 2; if (rad * 2 > r.size.width) rad = r.size.width / 2;
    CGPathRef p = CGPathCreateWithRoundedRect(r, rad, rad, NULL); CGContextSetRGBFillColor(cg, R, G, B, A); CGContextAddPath(cg, p); CGContextFillPath(cg); CGPathRelease(p);
}
static void Label(NSString *t, CGPoint left, CGFloat alpha, BOOL bold)
{
    NSDictionary *at = @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:alpha] };
    CGSize ts = [t sizeWithAttributes:at]; [t drawAtPoint:CGPointMake(left.x, left.y - ts.height / 2) withAttributes:at];
}
/* push button: a rounded rectangle (radius 5) 24 pt high centred in the frame, filled with the window colour lightened by 8 % (17 % pressed), the accent for the default button */
void OpenDrawPushButton(CGContextRef cg, CGRect frame, NSString *title, BOOL isDefault, BOOL enabled, BOOL pressed)
{
    CGRect r = frame; if (r.size.height > 24) { r.origin.y += (r.size.height - 24) / 2; r.size.height = 24; }
    CGFloat c[3];
    if (isDefault && enabled) { if (pressed) { c[0] = 25 / 255.0; c[1] = 135 / 255.0; c[2] = 1; } else { c[0] = 0; c[1] = 122 / 255.0; c[2] = 1; } }
    else { double a = pressed ? 0.17 : 0.08; if (!enabled) a *= 0.5; OnBG(a, c); }
    FillRound(cg, r, 5, c[0], c[1], c[2], 1);
    NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:(isDefault && enabled) ? 1 : (enabled ? 0.85 : 0.25)] };
    CGSize ts = [title sizeWithAttributes:at]; [title drawAtPoint:CGPointMake(r.origin.x + (r.size.width - ts.width) / 2, r.origin.y + (r.size.height - ts.height) / 2) withAttributes:at];
}
/* text field bezel: a 1 px ring (the window colour lightened by 5 %) round a field of the text background (23,24,25), radius 6 */
void OpenDrawTextBezel(CGContextRef cg, CGRect frame)
{
    CGFloat c[3]; OnBG(0.05, c); FillRound(cg, frame, 6, c[0], c[1], c[2], 1);
    FillRound(cg, CGRectInset(frame, 1, 1), 5, 23 / 255.0, 24 / 255.0, 25 / 255.0, 1);
}
/* slider: a 6 pt capsule track (window colour + 12 %), the part before the knob in the accent colour, a 20 pt knob (218,220,222) with a soft shadow */
void OpenDrawSlider(CGContextRef cg, CGRect b, double f, BOOL enabled)
{
    CGFloat cy = CGRectGetMidY(b), th = 6, c[3]; OnBG(0.12, c); CGRect track = CGRectMake(b.origin.x + 10, cy - th / 2, b.size.width - 20, th);
    FillRound(cg, track, th / 2, c[0], c[1], c[2], 1);
    CGFloat x = track.origin.x + f * track.size.width;
    if (enabled) FillRound(cg, CGRectMake(track.origin.x, track.origin.y, x - track.origin.x, th), th / 2, 0, 122 / 255.0, 1, 1); else { OnBG(0.28, c); FillRound(cg, CGRectMake(track.origin.x, track.origin.y, x - track.origin.x, th), th / 2, c[0], c[1], c[2], 1); }
    CGRect k = CGRectMake(x - 9, cy - 9, 18, 18);
    CGContextSetRGBFillColor(cg, 0, 0, 0, 0.25); CGContextFillEllipseInRect(cg, CGRectOffset(k, 0, -1));
    if (enabled) CGContextSetRGBFillColor(cg, 218 / 255.0, 220 / 255.0, 222 / 255.0, 1); else CGContextSetRGBFillColor(cg, 150 / 255.0, 152 / 255.0, 154 / 255.0, 1);
    CGContextFillEllipseInRect(cg, k);
}
/* determinate progress bar: an 8 pt capsule (window colour + 10 %), the done part in the accent colour */
void OpenDrawProgress(CGContextRef cg, CGRect b, double f)
{
    CGFloat h = b.size.height > 8 ? 8 : b.size.height, c[3]; OnBG(0.10, c); CGRect t = CGRectMake(b.origin.x, CGRectGetMidY(b) - h / 2, b.size.width, h);
    FillRound(cg, t, h / 2, c[0], c[1], c[2], 1);
    if (f > 0) { CGFloat w = t.size.width * (f > 1 ? 1 : f); if (w < h) w = h; FillRound(cg, CGRectMake(t.origin.x, t.origin.y, w, h), h / 2, 0, 122 / 255.0, 1, 1); }
}
/* check box (rounded square, radius 4) / radio button (disc) 16 x 16: window colour + 10 % off, the accent on; the mark white (the theme's segments, y down in the picture) */
void OpenDrawCheck(CGContextRef cg, CGRect box, BOOL radio, BOOL on)
{
    CGFloat c[3]; OnBG(0.10, c);
    CGRect r = CGRectMake(box.origin.x, box.origin.y, 16, 16);
    if (radio) { if (on) CGContextSetRGBFillColor(cg, 0, 122 / 255.0, 1, 1); else CGContextSetRGBFillColor(cg, c[0], c[1], c[2], 1); CGContextFillEllipseInRect(cg, r); }
    else FillRound(cg, r, 4, on ? 0 : c[0], on ? 122 / 255.0 : c[1], on ? 1 : c[2], 1);
    if (!on) return;
    CGContextSetRGBFillColor(cg, 1, 1, 1, 1); CGContextSetRGBStrokeColor(cg, 1, 1, 1, 1);
    if (radio) CGContextFillEllipseInRect(cg, CGRectMake(r.origin.x + 5, r.origin.y + 5, 6, 6));
    else {
        CGContextSetLineWidth(cg, 1.8); CGContextSetLineCap(cg, kCGLineCapRound); CGContextSetLineJoin(cg, kCGLineJoinRound);
        CGContextMoveToPoint(cg, r.origin.x + 4, r.origin.y + 16 - 7.8); CGContextAddLineToPoint(cg, r.origin.x + 6.9, r.origin.y + 16 - 11); CGContextAddLineToPoint(cg, r.origin.x + 12, r.origin.y + 16 - 4.8); CGContextStrokePath(cg);
    }
}
/* pop-up button: the push button look with the title 11 pt in and the two chevrons (1.4 pt strokes) 14 pt from the right edge */
void OpenDrawPopUp(CGContextRef cg, CGRect frame, NSString *title, BOOL enabled)
{
    CGRect r = frame; if (r.size.height > 24) { r.origin.y += (r.size.height - 24) / 2; r.size.height = 24; }
    CGFloat c[3]; OnBG(enabled ? 0.08 : 0.04, c); FillRound(cg, r, 5, c[0], c[1], c[2], 1);
    Label(title ?: @"", CGPointMake(r.origin.x + 11, CGRectGetMidY(r)), enabled ? 0.85 : 0.25, NO);
    CGFloat cx = CGRectGetMaxX(r) - 14;
    CGContextSetRGBStrokeColor(cg, 1, 1, 1, enabled ? 0.85 : 0.25); CGContextSetLineWidth(cg, 1.4); CGContextSetLineCap(cg, kCGLineCapRound); CGContextSetLineJoin(cg, kCGLineJoinRound);
    for (int k = 0; k < 2; k++) { CGFloat cy = CGRectGetMidY(r) + (k == 0 ? 3.5 : -3.5), d = k == 0 ? 1 : -1;			/* y up: the upper chevron points up */
        CGContextMoveToPoint(cg, cx - 3, cy - d * 1.5); CGContextAddLineToPoint(cg, cx, cy + d * 1.5); CGContextAddLineToPoint(cg, cx + 3, cy - d * 1.5); CGContextStrokePath(cg); }
}
