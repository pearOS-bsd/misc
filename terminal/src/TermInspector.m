#import "TermInspector.h"

@interface TermInspectorController : NSObject
{
	NSPanel *panel; NSTextField *profileF, *titleF, *sizeF, *shellF; NSTextView *procs; NSTimer *timer; TermView *term;
}
- (void)showFor:(TermView *)t; - (void)setTerm:(TermView *)t;
@end
static TermInspectorController *shared;

@implementation TermInspector
+ (void)showForTerm:(TermView *)t { if (!shared) shared = [[TermInspectorController alloc] init]; [shared showFor:t]; }
+ (void)setCurrentTerm:(TermView *)t { if (shared) [shared setTerm:t]; }
@end

static NSTextField *lab(NSString *s, NSRect r, BOOL bold) { NSTextField *t = [[[NSTextField alloc] initWithFrame:r] autorelease]; [t setStringValue:s]; [t setEditable:NO]; [t setSelectable:NO]; [t setBezeled:NO]; [t setBordered:NO]; [t setDrawsBackground:NO]; if (bold) [t setFont:[NSFont boldSystemFontOfSize:12]]; return t; }

@implementation TermInspectorController
- (instancetype)init
{
	if (!(self = [super init])) return nil;
	panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(900, 200, 330, 360) styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask) backing:NSBackingStoreBuffered defer:NO];
	[panel setTitle:@"Inspector"]; [panel setReleasedWhenClosed:NO]; [panel setFloatingPanel:YES];
	NSView *c = [panel contentView]; CGFloat y = 322;
	NSString *names[4] = { @"Profile", @"Title", @"Size", @"Shell" }; NSTextField **fields[4] = { &profileF, &titleF, &sizeF, &shellF };
	for (int i = 0; i < 4; i++) { [c addSubview:lab(names[i], NSMakeRect(14, y, 70, 18), YES)]; *fields[i] = lab(@"", NSMakeRect(90, y, 226, 18), NO); [c addSubview:*fields[i]]; y -= 26; }
	[c addSubview:lab(@"Running Processes", NSMakeRect(14, y - 4, 200, 18), YES)];
	NSScrollView *sc = [[[NSScrollView alloc] initWithFrame:NSMakeRect(14, 14, 302, y - 24)] autorelease]; [sc setHasVerticalScroller:YES]; [sc setBorderType:NSBezelBorder];
	procs = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 290, 200)] autorelease]; [procs setEditable:NO]; [procs setFont:[NSFont userFixedPitchFontOfSize:11]]; [sc setDocumentView:procs]; [c addSubview:sc];
	timer = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refresh:) userInfo:nil repeats:YES] retain];
	return self;
}
- (void)showFor:(TermView *)t { term = t; [self refresh:nil]; [panel makeKeyAndOrderFront:nil]; }
- (void)setTerm:(TermView *)t { term = t; [self refresh:nil]; }
- (void)refresh:(NSTimer *)tm
{
	if (![panel isVisible] || !term) return;
	[profileF setStringValue:term.profile ? [term profile]->name : @""]; [titleF setStringValue:[term titleString]]; [sizeF setStringValue:[NSString stringWithFormat:@"%d × %d", [term cols], [term rows]]];
	const char *sh = getenv("SHELL"); [shellF setStringValue:sh ? [NSString stringWithUTF8String:sh] : @"/bin/sh"];
	NSString *tty = [term ttyName]; NSString *txt = @"";
	if (tty) {
		NSTask *t = [[[NSTask alloc] init] autorelease]; NSPipe *p = [NSPipe pipe]; [t setLaunchPath:@"/bin/ps"]; [t setArguments:[NSArray arrayWithObjects:@"-t", [tty lastPathComponent], @"-o", @"pid=", @"-o", @"stat=", @"-o", @"command=", nil]]; [t setStandardOutput:p]; [t setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		@try { [t launch]; NSData *d = [[p fileHandleForReading] readDataToEndOfFile]; [t waitUntilExit]; txt = [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease] ?: @""; } @catch (id x) {}
	}
	[procs setString:txt];
}
@end
