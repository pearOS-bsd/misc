/* The symbols the Finder and the shell use, drawn from simple paths, for an image that has no SF Symbols catalogue (CoreGlyphs.car is Apple's and is not on the images built by the workflow): outline icons on a unit square, stroked at 8 % of it, in the colour of the symbol; the shapes are an approximation of the SF Symbols' (no measurement against the Mac was possible: the catalogue's glyphs are used whenever the catalogue is there). */
#import <AppKit/AppKit.h>

typedef void (^SymBuild)(NSBezierPath *p, BOOL *fill);
static NSBezierPath *Circle(CGFloat cx, CGFloat cy, CGFloat r) { return [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(cx - r, cy - r, 2 * r, 2 * r)]; }
static void Line(NSBezierPath *p, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) { [p moveToPoint: NSMakePoint(x1, y1)]; [p lineToPoint: NSMakePoint(x2, y2)]; }
static void RRect(NSBezierPath *p, CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat r) { [p appendBezierPath: [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(x, y, w, h) xRadius: r yRadius: r]]; }
static void Dot(NSBezierPath *p, CGFloat x, CGFloat y) { [p appendBezierPath: Circle(x, y, 0.035)]; }
static void Arc(NSBezierPath *p, CGFloat cx, CGFloat cy, CGFloat r, CGFloat a0, CGFloat a1) { [p moveToPoint: NSMakePoint(cx + r * cos(a0 * M_PI / 180), cy + r * sin(a0 * M_PI / 180))]; [p appendBezierPathWithArcWithCenter: NSMakePoint(cx, cy) radius: r startAngle: a0 endAngle: a1]; }

static NSDictionary *Table(void)
{
	static NSDictionary *t; if (t) return t;
	NSDictionary *lit = @{
		@"wifi.slash": ^(NSBezierPath *p, BOOL *f) { Arc(p, .5, .18, .62, 48, 132); Arc(p, .5, .18, .4, 48, 132); Arc(p, .5, .18, .18, 48, 132); Line(p, .14, .9, .86, .1); },
		@"bluetooth": ^(NSBezierPath *p, BOOL *f) { Line(p, .5, .08, .5, .92); [p moveToPoint: NSMakePoint(.28, .7)]; [p lineToPoint: NSMakePoint(.72, .3)]; [p lineToPoint: NSMakePoint(.5, .08)]; [p moveToPoint: NSMakePoint(.28, .3)]; [p lineToPoint: NSMakePoint(.72, .7)]; [p lineToPoint: NSMakePoint(.5, .92)]; },
		@"moon.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.66, .1)]; [p curveToPoint: NSMakePoint(.66, .9) controlPoint1: NSMakePoint(.2, .12) controlPoint2: NSMakePoint(.2, .88)]; [p curveToPoint: NSMakePoint(.9, .5) controlPoint1: NSMakePoint(.5, .78) controlPoint2: NSMakePoint(.42, .22)]; [p curveToPoint: NSMakePoint(.66, .1) controlPoint1: NSMakePoint(.9, .34) controlPoint2: NSMakePoint(.8, .16)]; [p closePath]; },
		@"sun.max": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .17)]; for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; Line(p, .5 + .28 * cos(a), .5 + .28 * sin(a), .5 + .42 * cos(a), .5 + .42 * sin(a)); } },
		@"sun.max.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p appendBezierPath: Circle(.5, .5, .2)]; for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; [p appendBezierPath: Circle(.5 + .36 * cos(a), .5 + .36 * sin(a), .045)]; } },
		@"sun.min": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .11)]; for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; Line(p, .5 + .24 * cos(a), .5 + .24 * sin(a), .5 + .34 * cos(a), .5 + .34 * sin(a)); } },
		@"light.max": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .17)]; for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; Line(p, .5 + .28 * cos(a), .5 + .28 * sin(a), .5 + .42 * cos(a), .5 + .42 * sin(a)); } },
		@"display": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .26, .84, .58, .07); Line(p, .5, .26, .5, .14); Line(p, .3, .12, .7, .12); },
		@"circle.lefthalf.filled": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .4)]; [p moveToPoint: NSMakePoint(.5, .9)]; [p appendBezierPathWithArcWithCenter: NSMakePoint(.5, .5) radius: .4 startAngle: 90 endAngle: 270]; [p closePath]; *f = NO; },
		@"lock.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; RRect(p, .2, .12, .6, .46, .08); [p appendBezierPath: [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(.32, .5, .36, .36) xRadius: .18 yRadius: .18]]; [p setWindingRule: NSEvenOddWindingRule]; },
		@"play.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.28, .14)]; [p lineToPoint: NSMakePoint(.28, .86)]; [p lineToPoint: NSMakePoint(.84, .5)]; [p closePath]; },
		@"backward.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.5, .5)]; [p lineToPoint: NSMakePoint(.88, .8)]; [p lineToPoint: NSMakePoint(.88, .2)]; [p closePath]; [p moveToPoint: NSMakePoint(.12, .5)]; [p lineToPoint: NSMakePoint(.5, .8)]; [p lineToPoint: NSMakePoint(.5, .2)]; [p closePath]; },
		@"forward.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.5, .5)]; [p lineToPoint: NSMakePoint(.12, .8)]; [p lineToPoint: NSMakePoint(.12, .2)]; [p closePath]; [p moveToPoint: NSMakePoint(.88, .5)]; [p lineToPoint: NSMakePoint(.5, .8)]; [p lineToPoint: NSMakePoint(.5, .2)]; [p closePath]; },
		@"speaker.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.14, .38)]; [p lineToPoint: NSMakePoint(.3, .38)]; [p lineToPoint: NSMakePoint(.52, .18)]; [p lineToPoint: NSMakePoint(.52, .82)]; [p lineToPoint: NSMakePoint(.3, .62)]; [p lineToPoint: NSMakePoint(.14, .62)]; [p closePath]; },
		@"speaker.wave.2.fill": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.1, .38)]; [p lineToPoint: NSMakePoint(.24, .38)]; [p lineToPoint: NSMakePoint(.42, .2)]; [p lineToPoint: NSMakePoint(.42, .8)]; [p lineToPoint: NSMakePoint(.24, .62)]; [p lineToPoint: NSMakePoint(.1, .62)]; [p closePath]; Arc(p, .42, .5, .22, -40, 40); Arc(p, .42, .5, .38, -40, 40); },
		@"speaker.wave.3.fill": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.06, .38)]; [p lineToPoint: NSMakePoint(.2, .38)]; [p lineToPoint: NSMakePoint(.36, .22)]; [p lineToPoint: NSMakePoint(.36, .78)]; [p lineToPoint: NSMakePoint(.2, .62)]; [p lineToPoint: NSMakePoint(.06, .62)]; [p closePath]; Arc(p, .36, .5, .18, -40, 40); Arc(p, .36, .5, .32, -40, 40); Arc(p, .36, .5, .46, -40, 40); },
		@"airplay.audio": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .56, .08)]; Arc(p, .5, .56, .22, 40, 140); Arc(p, .5, .56, .22, 220, 320); Arc(p, .5, .56, .36, 40, 140); Arc(p, .5, .56, .36, 220, 320); [p moveToPoint: NSMakePoint(.5, .46)]; [p lineToPoint: NSMakePoint(.3, .1)]; [p lineToPoint: NSMakePoint(.7, .1)]; [p closePath]; },
		@"rectangle.3.group": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .12, .36, .76, .06); RRect(p, .54, .5, .36, .38, .06); RRect(p, .54, .12, .36, .3, .06); },
		@"rectangle.on.rectangle": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .4, .6, .46, .07); RRect(p, .32, .14, .6, .46, .07); },
		@"battery": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .3, .78, .4, .1); Line(p, .9, .44, .9, .56); },
		@"battery.50": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .3, .78, .4, .1); Line(p, .9, .44, .9, .56); RRect(p, .12, .36, .34, .28, .03); },
		@"battery.100percent": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .3, .78, .4, .1); Line(p, .9, .44, .9, .56); RRect(p, .12, .36, .66, .28, .03); },
		@"battery.100percent.bolt": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .3, .78, .4, .1); Line(p, .9, .44, .9, .56); RRect(p, .12, .36, .66, .28, .03); },
		@"person.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p appendBezierPath: Circle(.5, .68, .2)]; [p moveToPoint: NSMakePoint(.12, .08)]; [p curveToPoint: NSMakePoint(.88, .08) controlPoint1: NSMakePoint(.12, .56) controlPoint2: NSMakePoint(.88, .56)]; [p closePath]; },
		@"trash": ^(NSBezierPath *p, BOOL *f) { Line(p, .14, .78, .86, .78); Line(p, .38, .78, .38, .88); Line(p, .38, .88, .62, .88); Line(p, .62, .88, .62, .78); [p moveToPoint: NSMakePoint(.24, .78)]; [p lineToPoint: NSMakePoint(.3, .12)]; [p lineToPoint: NSMakePoint(.7, .12)]; [p lineToPoint: NSMakePoint(.76, .78)]; Line(p, .42, .6, .42, .3); Line(p, .58, .6, .58, .3); },
		@"ellipsis": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p appendBezierPath: Circle(.2, .5, .07)]; [p appendBezierPath: Circle(.5, .5, .07)]; [p appendBezierPath: Circle(.8, .5, .07)]; },
		@"xmark": ^(NSBezierPath *p, BOOL *f) { Line(p, .24, .24, .76, .76); Line(p, .24, .76, .76, .24); },
		@"plus": ^(NSBezierPath *p, BOOL *f) { Line(p, .5, .18, .5, .82); Line(p, .18, .5, .82, .5); },
		@"minus": ^(NSBezierPath *p, BOOL *f) { Line(p, .18, .5, .82, .5); },
		@"checkmark": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.18, .5)]; [p lineToPoint: NSMakePoint(.4, .26)]; [p lineToPoint: NSMakePoint(.84, .76)]; },
		@"square.and.arrow.up": ^(NSBezierPath *p, BOOL *f) { Line(p, .5, .12, .5, .62); Line(p, .34, .48, .5, .64); Line(p, .66, .48, .5, .64); Line(p, .5, .64, .5, .64); [p moveToPoint: NSMakePoint(.28, .4)]; [p lineToPoint: NSMakePoint(.18, .4)]; [p lineToPoint: NSMakePoint(.18, .88)]; [p lineToPoint: NSMakePoint(.82, .88)]; [p lineToPoint: NSMakePoint(.82, .4)]; [p lineToPoint: NSMakePoint(.72, .4)]; },
		@"bolt.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.56, .94)]; [p lineToPoint: NSMakePoint(.22, .46)]; [p lineToPoint: NSMakePoint(.46, .46)]; [p lineToPoint: NSMakePoint(.4, .06)]; [p lineToPoint: NSMakePoint(.78, .56)]; [p lineToPoint: NSMakePoint(.54, .56)]; [p closePath]; },
		@"battery.25percent": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .3, .78, .4, .1); Line(p, .9, .44, .9, .56); RRect(p, .12, .36, .16, .28, .03); },
		@"switch.2": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .56, .84, .28, .14); RRect(p, .08, .16, .84, .28, .14); [p appendBezierPath: Circle(.72, .7, .07)]; [p appendBezierPath: Circle(.28, .3, .07)]; },
		@"gear": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .16)]; [p appendBezierPath: Circle(.5, .5, .36)]; for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; Line(p, .5 + .36 * cos(a), .5 + .36 * sin(a), .5 + .46 * cos(a), .5 + .46 * sin(a)); } },
		@"clock": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .42)]; Line(p, .5, .5, .5, .78); Line(p, .5, .5, .7, .4); },
		@"person.2": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.36, .68, .13)]; Arc(p, .36, .22, .27, 25, 155); [p appendBezierPath: Circle(.68, .7, .11)]; Arc(p, .7, .3, .2, 30, 110); },
		@"app": ^(NSBezierPath *p, BOOL *f) { RRect(p, .12, .12, .76, .76, .16); },
		@"menubar.dock.rectangle": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .14, .84, .72, .1); Line(p, .08, .7, .92, .7); Line(p, .3, .26, .7, .26); },
		@"desktopcomputer": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .3, .8, .58, .07); Line(p, .5, .3, .5, .16); Line(p, .3, .14, .7, .14); },
		@"doc": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.22, .1)]; [p lineToPoint: NSMakePoint(.22, .9)]; [p lineToPoint: NSMakePoint(.58, .9)]; [p lineToPoint: NSMakePoint(.8, .68)]; [p lineToPoint: NSMakePoint(.8, .1)]; [p closePath]; Line(p, .58, .9, .58, .68); Line(p, .58, .68, .8, .68); },
		@"arrow.down.circle": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .42)]; Line(p, .5, .72, .5, .3); Line(p, .34, .46, .5, .3); Line(p, .66, .46, .5, .3); },
		@"icloud": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.28, .28)]; [p curveToPoint: NSMakePoint(.2, .55) controlPoint1: NSMakePoint(.06, .3) controlPoint2: NSMakePoint(.06, .55)]; [p curveToPoint: NSMakePoint(.5, .78) controlPoint1: NSMakePoint(.2, .72) controlPoint2: NSMakePoint(.36, .8)]; [p curveToPoint: NSMakePoint(.76, .58) controlPoint1: NSMakePoint(.64, .84) controlPoint2: NSMakePoint(.76, .72)]; [p curveToPoint: NSMakePoint(.76, .28) controlPoint1: NSMakePoint(.96, .58) controlPoint2: NSMakePoint(.96, .28)]; [p closePath]; },
		@"house": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.12, .48)]; [p lineToPoint: NSMakePoint(.5, .84)]; [p lineToPoint: NSMakePoint(.88, .48)]; Line(p, .22, .44, .22, .14); Line(p, .22, .14, .78, .14); Line(p, .78, .14, .78, .44); Line(p, .42, .14, .42, .34); Line(p, .42, .34, .58, .34); Line(p, .58, .34, .58, .14); },
		@"externaldrive": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .28, .8, .44, .1); Line(p, .1, .5, .9, .5); Dot(p, .74, .39); },
		@"internaldrive": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .28, .8, .44, .1); Line(p, .1, .5, .9, .5); Dot(p, .74, .39); },
		@"macwindow": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .16, .84, .68, .1); Line(p, .08, .68, .92, .68); Dot(p, .2, .76); Dot(p, .3, .76); Dot(p, .4, .76); },
		@"a.square": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .1, .8, .8, .14); [p moveToPoint: NSMakePoint(.32, .28)]; [p lineToPoint: NSMakePoint(.5, .72)]; [p lineToPoint: NSMakePoint(.68, .28)]; Line(p, .38, .44, .62, .44); },
		@"folder": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.08, .2)]; [p lineToPoint: NSMakePoint(.08, .78)]; [p lineToPoint: NSMakePoint(.36, .78)]; [p lineToPoint: NSMakePoint(.46, .68)]; [p lineToPoint: NSMakePoint(.92, .68)]; [p lineToPoint: NSMakePoint(.92, .2)]; [p closePath]; },
		@"airplayaudio": ^(NSBezierPath *p, BOOL *f) { Arc(p, .5, .55, .4, 140, 400); [p moveToPoint: NSMakePoint(.5, .5)]; [p lineToPoint: NSMakePoint(.28, .16)]; [p lineToPoint: NSMakePoint(.72, .16)]; [p closePath]; },
		@"wifi": ^(NSBezierPath *p, BOOL *f) { Arc(p, .5, .2, .66, 48, 132); Arc(p, .5, .2, .44, 48, 132); Arc(p, .5, .2, .22, 48, 132); Dot(p, .5, .22); },
		@"tag": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.1, .56)]; [p lineToPoint: NSMakePoint(.1, .86)]; [p lineToPoint: NSMakePoint(.4, .86)]; [p lineToPoint: NSMakePoint(.9, .36)]; [p lineToPoint: NSMakePoint(.62, .08)]; [p closePath]; [p appendBezierPath: Circle(.28, .72, .06)]; },
		@"circle": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .4)]; },
		@"magnifyingglass": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.42, .58, .3)]; Line(p, .64, .36, .88, .12); },
		@"chevron.left": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.62, .84)]; [p lineToPoint: NSMakePoint(.3, .5)]; [p lineToPoint: NSMakePoint(.62, .16)]; },
		@"chevron.right": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.38, .84)]; [p lineToPoint: NSMakePoint(.7, .5)]; [p lineToPoint: NSMakePoint(.38, .16)]; },
		@"chevron.down": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.16, .64)]; [p lineToPoint: NSMakePoint(.5, .32)]; [p lineToPoint: NSMakePoint(.84, .64)]; },
		@"chevron.up": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.16, .36)]; [p lineToPoint: NSMakePoint(.5, .68)]; [p lineToPoint: NSMakePoint(.84, .36)]; },
		@"chevron.up.chevron.down": ^(NSBezierPath *p, BOOL *f) { [p moveToPoint: NSMakePoint(.3, .62)]; [p lineToPoint: NSMakePoint(.5, .84)]; [p lineToPoint: NSMakePoint(.7, .62)]; [p moveToPoint: NSMakePoint(.3, .38)]; [p lineToPoint: NSMakePoint(.5, .16)]; [p lineToPoint: NSMakePoint(.7, .38)]; },
		@"square.grid.2x2": ^(NSBezierPath *p, BOOL *f) { RRect(p, .12, .12, .32, .32, .06); RRect(p, .56, .12, .32, .32, .06); RRect(p, .12, .56, .32, .32, .06); RRect(p, .56, .56, .32, .32, .06); },
		@"list.bullet": ^(NSBezierPath *p, BOOL *f) { Line(p, .34, .74, .9, .74); Line(p, .34, .5, .9, .5); Line(p, .34, .26, .9, .26); Dot(p, .14, .74); Dot(p, .14, .5); Dot(p, .14, .26); },
		@"rectangle.split.3x1": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .2, .88, .6, .08); Line(p, .35, .2, .35, .8); Line(p, .65, .2, .65, .8); },
		@"square.grid.3x1.below.line.grid.1x2": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .1, .84, .8, .1); Line(p, .08, .36, .92, .36); Line(p, .36, .36, .36, .1); Line(p, .64, .36, .64, .1); },
		@"sidebar.left": ^(NSBezierPath *p, BOOL *f) { RRect(p, .08, .16, .84, .68, .1); Line(p, .38, .16, .38, .84); },
		@"apps.iphone": ^(NSBezierPath *p, BOOL *f) { RRect(p, .26, .08, .48, .84, .1); Dot(p, .42, .62); Dot(p, .58, .62); Dot(p, .42, .46); Dot(p, .58, .46); },
		@"rectangle.grid.1x2": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .12, .8, .76, .08); Line(p, .1, .5, .9, .5); },
		@"rectangle.grid.3x2": ^(NSBezierPath *p, BOOL *f) { RRect(p, .06, .16, .88, .68, .08); Line(p, .06, .5, .94, .5); Line(p, .35, .16, .35, .84); Line(p, .65, .16, .65, .84); },
		@"square.and.arrow.down": ^(NSBezierPath *p, BOOL *f) { Line(p, .5, .86, .5, .42); Line(p, .34, .56, .5, .42); Line(p, .66, .56, .5, .42); [p moveToPoint: NSMakePoint(.28, .62)]; [p lineToPoint: NSMakePoint(.18, .62)]; [p lineToPoint: NSMakePoint(.18, .12)]; [p lineToPoint: NSMakePoint(.82, .12)]; [p lineToPoint: NSMakePoint(.82, .62)]; [p lineToPoint: NSMakePoint(.72, .62)]; },
		@"eject.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.5, .84)]; [p lineToPoint: NSMakePoint(.9, .36)]; [p lineToPoint: NSMakePoint(.1, .36)]; [p closePath]; [p appendBezierPath: [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(.1, .12, .8, .14) xRadius: .04 yRadius: .04]]; },
		@"ellipsis.circle": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .42)]; Dot(p, .3, .5); Dot(p, .5, .5); Dot(p, .7, .5); },
		@"pencil.tip.crop.circle": ^(NSBezierPath *p, BOOL *f) { [p appendBezierPath: Circle(.5, .5, .42)]; Line(p, .34, .34, .64, .64); Line(p, .34, .34, .3, .3); },
		@"rotate.left": ^(NSBezierPath *p, BOOL *f) { Arc(p, .5, .5, .34, 40, 330); Line(p, .22, .78, .3, .58); Line(p, .22, .78, .42, .84); },
		@"server.rack": ^(NSBezierPath *p, BOOL *f) { RRect(p, .1, .54, .8, .3, .06); RRect(p, .1, .16, .8, .3, .06); Dot(p, .24, .69); Dot(p, .24, .31); },
		@"trash.fill": ^(NSBezierPath *p, BOOL *f) { *f = YES; [p moveToPoint: NSMakePoint(.22, .74)]; [p lineToPoint: NSMakePoint(.28, .12)]; [p lineToPoint: NSMakePoint(.72, .12)]; [p lineToPoint: NSMakePoint(.78, .74)]; [p closePath]; [p appendBezierPath: [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(.14, .78, .72, .06) xRadius: .03 yRadius: .03]]; [p appendBezierPath: [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(.38, .86, .24, .06) xRadius: .03 yRadius: .03]]; },
	};
	NSMutableDictionary *heap = [NSMutableDictionary dictionary]; for (NSString *k in lit) heap[k] = [lit[k] copy];       /* the blocks of the literal live on the stack: the copies are kept (this file is compiled without ARC) */
	t = [heap copy]; return t;
}
BOOL WsdFallbackSymbolKnown(NSString *name) { return Table()[name] != nil; }
NSSize WsdFallbackSymbolSize(NSString *name, CGFloat pt) { return Table()[name] ? NSMakeSize(pt * 1.15, pt * 1.15) : NSZeroSize; }
int WsdSymbolFlip = -1;       /* a caller that knows the view it draws in sets this around the call (the context's own flag is not reliable in a menu row) */
BOOL WsdFallbackSymbolDraw(NSString *name, NSRect cell, CGFloat pt, NSColor *tint)
{
	SymBuild b = Table()[name]; if (!b) return NO; CGFloat s = pt * 1.15; NSBezierPath *p = [NSBezierPath bezierPath]; BOOL fill = NO; b(p, &fill);
	BOOL flipped = WsdSymbolFlip >= 0 ? (WsdSymbolFlip != 0) : [[NSGraphicsContext currentContext] isFlipped];       /* the paths are drawn with y up: in a flipped view (the Finder's, the top bar's) they are mirrored, else the symbols come out upside down */
	NSAffineTransform *t = [NSAffineTransform transform]; [t translateXBy: NSMidX(cell) - s / 2 yBy: flipped ? NSMidY(cell) + s / 2 : NSMidY(cell) - s / 2]; [t scaleXBy: s yBy: flipped ? -s : s]; NSBezierPath *q = [t transformBezierPath: p];
	[tint set]; if (fill) [q fill]; else { [q setLineWidth: MAX(1.0, s * 0.085)]; [q setLineCapStyle: NSRoundLineCapStyle]; [q setLineJoinStyle: NSRoundLineJoinStyle]; [q stroke]; }
	return YES;
}
