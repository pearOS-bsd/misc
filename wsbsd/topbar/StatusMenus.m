/* The menus of the status items that are plain menus on the Mac. Battery (measured: 304 wide under the item, the title "Battery" in bold, the source and the state dimmed, "Energy Mode" and the
 * mode, "Battery Settings…" last). The menu is a NSMenu: the theme draws it as the Mac's. */
#import <AppKit/AppKit.h>
#import <objc/message.h>
#include <sys/sysctl.h>

static int Sys(const char *name, int def) { int v = def; size_t n = sizeof v; if (sysctlbyname(name, &v, &n, NULL, 0)) return def; return v; }
@interface StatusMenuTarget : NSObject @end
@implementation StatusMenuTarget
- (void)settings:(id)s { for (NSString *a in @[ @"/System/Applications/System Settings.app", @"/Applications/System Settings.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; return; } NSBeep(); }
@end
static NSMenuItem *Row(NSMenu *m, NSString *t, BOOL dim, BOOL bold)
{
	NSMenuItem *i = [m addItemWithTitle: t action: dim ? NULL : @selector(self) keyEquivalent: @""]; if (bold) [i setAttributedTitle: [[NSAttributedString alloc] initWithString: t attributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13] }]]; [i setEnabled: !dim]; return i;
}
void ShowBatteryMenu(NSView *v, double rightEdge)
{
	static StatusMenuTarget *tg; if (!tg) tg = [StatusMenuTarget new];
	int pct = Sys("hw.acpi.battery.life", -1), state = Sys("hw.acpi.battery.state", 0), ac = Sys("hw.acpi.acline", 1), mins = Sys("hw.acpi.battery.time", -1);
	NSMenu *m = [[NSMenu alloc] initWithTitle: @"Battery"]; [m setAutoenablesItems: NO];
	Row(m, @"Battery", NO, YES);
	Row(m, [NSString stringWithFormat: @"Power Source: %@", ac ? @"Power Adapter" : @"Battery"], YES, NO);
	NSString *st = (state & 2) ? [NSString stringWithFormat: @"Charging, %d%%", pct] : (pct >= 100 ? @"Fully Charged" : (mins > 0 ? [NSString stringWithFormat: @"%d:%02d remaining", mins / 60, mins % 60] : [NSString stringWithFormat: @"%d%%", pct])); Row(m, st, YES, NO);
	[m addItem: [NSMenuItem separatorItem]];
	Row(m, @"Energy Mode", YES, NO); Row(m, @"Automatic", NO, NO);
	[m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *set = [m addItemWithTitle: @"Battery Settings…" action: @selector(settings:) keyEquivalent: @""]; [set setTarget: tg];
	if ([m respondsToSelector: @selector(setMinimumWidth:)]) ((void (*)(id, SEL, double))objc_msgSend)(m, @selector(setMinimumWidth:), 304.0);
	NSPoint p = NSMakePoint(rightEdge - 304, 31); NSEvent *ev = [NSEvent mouseEventWithType: NSLeftMouseDown location: [v convertPoint: p toView: nil] modifierFlags: 0 timestamp: 0 windowNumber: [[v window] windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1];
	[NSMenu popUpContextMenu: m withEvent: ev forView: v];
}
