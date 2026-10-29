/* Terminal: a terminal emulator application for the wsbsd stack: the menus, tabs, profiles, find bar and commands of Terminal.app (structure taken from the real application), built against the public Cocoa API. */
#import <AppKit/AppKit.h>
#import "TermView.h"
#import "TermWindow.h"
#import "TermProfile.h"
#import "TermSettings.h"
#import "TermInspector.h"

@interface TermApp : NSObject
- (TermWindowController *)wc;
@end

@implementation TermApp
- (TermWindowController *)wc { NSWindow *w = [NSApp keyWindow] ?: [NSApp mainWindow]; for (TermWindowController *c in [TermWindowController all]) if ([c window] == w) return c; return [[TermWindowController all] lastObject]; }
- (TermProfile *)profileOf:(id)sender { id r = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil; return [r isKindOfClass:[TermProfile class]] ? r : nil; }

- (NSString *)promptFor:(NSString *)title message:(NSString *)msg initial:(NSString *)init
{
	NSAlert *a = [[[NSAlert alloc] init] autorelease]; [a setMessageText:title]; [a setInformativeText:msg]; [a addButtonWithTitle:@"OK"]; [a addButtonWithTitle:@"Cancel"];
	NSTextField *f = [[[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)] autorelease]; [f setStringValue:init ?: @""]; [a setAccessoryView:f];
	return [a runModal] == NSAlertFirstButtonReturn ? [f stringValue] : nil;
}
- (void)newCommand:(id)sender
{
	(void)sender; NSString *c = [self promptFor:@"New Command" message:@"Command (complete path):" initial:@"/bin/sh"]; if (![c length]) return;
	[[TermWindowController alloc] initWithProfile:nil command:c];
}
- (void)openDocument:(id)sender
{
	(void)sender; NSOpenPanel *op = [NSOpenPanel openPanel]; if ([op runModal] != NSOKButton) return;
	NSString *p = [[[op URLs] objectAtIndex:0] path]; if ([[NSFileManager defaultManager] isExecutableFileAtPath:p]) [[TermWindowController alloc] initWithProfile:nil command:p];
}
- (void)editTitle:(id)sender
{
	(void)sender; TermWindowController *c = [self wc]; if (!c) return; NSString *t = [self promptFor:@"Edit Title" message:@"Tab title:" initial:[[c term] titleString]]; if (t) [[c term] setCustomTitle:t];
}
- (void)editBackground:(id)sender { (void)sender; [[NSColorPanel sharedColorPanel] setTarget:self]; [[NSColorPanel sharedColorPanel] setAction:@selector(backgroundColorPicked:)]; [[NSColorPanel sharedColorPanel] orderFront:nil]; }
- (void)showColors:(id)sender { (void)sender; [[NSColorPanel sharedColorPanel] orderFront:nil]; }
- (void)backgroundColorPicked:(id)sender
{
	TermWindowController *c = [self wc]; if (!c) return; TermProfile *p = [[c term] profile]; NSColor *n = [[(NSColorPanel *)sender color] colorWithAlphaComponent:[p->background alphaComponent]];
	[p->background release]; p->background = [n retain]; [p changed];
}
- (void)showInspector:(id)sender { (void)sender; TermWindowController *c = [self wc]; if (c) [TermInspector showForTerm:[c term]]; }
- (void)showSettings:(id)sender { (void)sender; [TermSettings show]; }
- (void)newWindow:(id)sender { [[TermWindowController alloc] initWithProfile:[self profileOf:sender] command:nil]; }
- (void)newTab:(id)sender { TermWindowController *c = [self wc]; if (c) [c newTabWithProfile:[self profileOf:sender] command:nil]; else [self newWindow:sender]; }
- (void)splitPane:(id)sender { [[self wc] splitPane:sender]; }
- (void)closeSplitPane:(id)sender { [[self wc] closeSplitPane:sender]; }
- (void)closeTab:(id)sender { [[self wc] closeCurrentTab:sender]; }
- (void)closeWindow:(id)sender { (void)sender; [[[self wc] window] performClose:nil]; }
- (void)nextTab:(id)sender { [[self wc] nextTab:sender]; }
- (void)previousTab:(id)sender { [[self wc] previousTab:sender]; }
- (void)toggleTabBar:(id)sender { [[self wc] toggleTabBar:sender]; }
- (void)showFindBar:(id)sender { [[self wc] showFindBar:sender]; }
- (void)findNext:(id)sender { [[self wc] findNext:sender]; }
- (void)findPrevious:(id)sender { [[self wc] findPrevious:sender]; }
- (void)useSelectionForFind:(id)sender { [[self wc] useSelectionForFind:sender]; }
- (void)hideFindBar:(id)sender { [[self wc] hideFindBar:sender]; }
- (void)changeProfile:(id)sender { TermProfile *p = [self profileOf:sender]; if (p) [[self wc] applyProfileToCurrent:p]; }
- (void)useSettingsAsDefault:(id)sender { (void)sender; TermWindowController *c = [self wc]; if (c) [TermProfile setDefaultProfile:[[c term] profile]]; }
- (void)toggleAutoMark:(id)sender { (void)sender; [TermView setAutoMarkPrompts:![TermView autoMarkPrompts]]; }
- (void)toggleShowMarks:(id)sender { (void)sender; [TermView setShowMarks:![TermView showMarks]]; }
- (void)toggleOptionAsMeta:(id)sender { (void)sender; [TermView setOptionAsMeta:![TermView optionAsMeta]]; }
- (void)toggleMouseReporting:(id)sender { (void)sender; [TermView setAllowMouseReporting:![TermView allowMouseReporting]]; }
- (void)toggleSecureKeyboard:(id)sender { (void)sender; [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:@"SecureKeyboardEntry"] forKey:@"SecureKeyboardEntry"]; }
- (void)exportText:(id)sender
{
	(void)sender; NSSavePanel *sp = [NSSavePanel savePanel]; [sp setNameFieldStringValue:@"Terminal Saved Output.txt"];
	if ([sp runModal] == NSOKButton) [[[[self wc] term] allText] writeToFile:[[sp URL] path] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}
- (void)exportSelectedText:(id)sender
{
	(void)sender; NSSavePanel *sp = [NSSavePanel savePanel]; [sp setNameFieldStringValue:@"Terminal Selection.txt"];
	if ([sp runModal] == NSOKButton) [[[[self wc] term] selectedText] writeToFile:[[sp URL] path] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}
- (void)pasteSelection:(id)sender { (void)sender; [[[self wc] term] writeString:[[[self wc] term] selectedText]]; }
- (void)pasteEscaped:(id)sender
{
	(void)sender; NSString *s = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType]; if (!s) return;
	NSMutableString *o = [NSMutableString string]; for (NSUInteger i = 0; i < [s length]; i++) { unichar c = [s characterAtIndex:i]; if (strchr(" \\\"'()&;|<>$`!*?[]{}#~", c) && c < 128) [o appendString:@"\\"]; [o appendFormat:@"%C", c]; }
	[[[self wc] term] writeString:o];
}
- (void)copyPlain:(id)sender { [[[self wc] term] copy:sender]; }
- (void)orderFrontAllWindows:(id)sender { (void)sender; for (TermWindowController *c in [TermWindowController all]) [[c window] orderFront:nil]; }
- (void)cycleWindows:(id)sender
{
	(void)sender; NSArray *a = [TermWindowController all]; if ([a count] < 2) return; NSUInteger i = 0; for (NSUInteger k = 0; k < [a count]; k++) if ([[a objectAtIndex:k] window] == [NSApp keyWindow]) i = k;
	[[[a objectAtIndex:(i + 1) % [a count]] window] makeKeyAndOrderFront:nil];
}
- (void)showHelp:(id)sender { (void)sender; [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://support.apple.com/guide/terminal/welcome/mac"]]; }

- (BOOL)validateMenuItem:(NSMenuItem *)mi
{
	SEL a = [mi action];
	if (a == @selector(toggleOptionAsMeta:)) { [mi setState:[TermView optionAsMeta] ? NSOnState : NSOffState]; return YES; }
	if (a == @selector(toggleAutoMark:)) { [mi setState:[TermView autoMarkPrompts] ? NSOnState : NSOffState]; return YES; }
	if (a == @selector(toggleShowMarks:)) { [mi setState:[TermView showMarks] ? NSOnState : NSOffState]; return YES; }
	if (a == @selector(toggleMouseReporting:)) { [mi setState:[TermView allowMouseReporting] ? NSOnState : NSOffState]; return YES; }
	if (a == @selector(toggleSecureKeyboard:)) { [mi setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"SecureKeyboardEntry"] ? NSOnState : NSOffState]; return YES; }
	if (a == @selector(toggleTabBar:)) { TermWindowController *c = [self wc]; [mi setTitle:[c tabBarShown] ? @"Hide Tab Bar" : @"Show Tab Bar"]; return c != nil; }
	if (a == @selector(changeProfile:)) { TermWindowController *c = [self wc]; [mi setState:c && [[[c term] profile] isEqual:[mi representedObject]] ? NSOnState : NSOffState]; return c != nil; }
	if (a == @selector(closeSplitPane:)) return [[self wc] hasSplitPanes];
	if (a == @selector(nextTab:) || a == @selector(previousTab:)) return [[[self wc] tabs] count] > 1;
	if ([mi target] == self && ![self respondsToSelector:a]) return NO;                         /* not implemented (yet): disabled */
	return [[TermWindowController all] count] > 0 || a == @selector(newWindow:) || a == @selector(newTab:);
}

- (void)finish:(NSTimer *)t
{
	const char *dump = getenv("TERMINAL_DUMP");                                          /* automated runs: write the screen text, then quit */
	if (dump && *dump) { TermWindowController *c = [[TermWindowController all] firstObject]; if (c) [[c term] dumpScreenToFile:[NSString stringWithUTF8String:dump]]; }
	[NSApp terminate:nil];
}
- (void)typeInitial:(NSTimer *)t { [[(TermWindowController *)[t userInfo] term] writeString:[NSString stringWithUTF8String:getenv("TERMINAL_INITIAL_INPUT")]]; }
- (void)applicationDidFinishLaunching:(NSNotification *)n
{
	(void)n; TermProfile *p = getenv("TERMINAL_PROFILE") ? [TermProfile profileNamed:[NSString stringWithUTF8String:getenv("TERMINAL_PROFILE")]] : nil;
	TermWindowController *c = [[TermWindowController alloc] initWithProfile:p command:nil];
	const char *init = getenv("TERMINAL_INITIAL_INPUT"), *quitAfter = getenv("TERMINAL_EXIT_AFTER");
	if (getenv("TERMINAL_SETTINGS")) [TermSettings show];
	if (getenv("TERMINAL_INSPECTOR")) [TermInspector showForTerm:[c term]];
	if (quitAfter && atof(quitAfter) > 0) [NSTimer scheduledTimerWithTimeInterval:atof(quitAfter) target:self selector:@selector(finish:) userInfo:nil repeats:NO];
	if (init && *init) [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(typeInitial:) userInfo:c repeats:NO];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)a { (void)a; return NO; }       /* as on the Mac: closing the last window leaves the application running until Command-Q */
@end

/* ---- the menus (titles, order and key equivalents of Terminal.app's MainMenu) ---- */
static NSMenuItem *M(NSMenu *m, NSString *title, SEL sel, NSString *key, NSUInteger mask, id target)
{
	NSMenuItem *i = [[NSMenuItem alloc] initWithTitle:title action:sel keyEquivalent:key ?: @""]; if (mask) [i setKeyEquivalentModifierMask:mask]; if (target) [i setTarget:target]; [m addItem:i]; return [i autorelease];
}
static NSMenu *SUB(NSMenu *m, NSString *title) { NSMenuItem *i = [[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""]; NSMenu *s = [[NSMenu alloc] initWithTitle:title]; [i setSubmenu:s]; [m addItem:i]; [i release]; return [s autorelease]; }
static void SEP(NSMenu *m) { [m addItem:[NSMenuItem separatorItem]]; }
static void profileItems(NSMenu *m, SEL sel, id target)
{
	for (TermProfile *p in [TermProfile allProfiles]) { NSMenuItem *i = M(m, p->name, sel, nil, 0, target); [i setRepresentedObject:p]; }
}

int main(int argc, char **argv)
{
	(void)argc; (void)argv;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSApplication *app = [NSApplication sharedApplication];
	TermApp *d = [[TermApp alloc] init]; [app setDelegate:(id)d];
	const NSUInteger CMD = NSCommandKeyMask, SH = NSShiftKeyMask, OPT = NSAlternateKeyMask, CTL = NSControlKeyMask;
	NSMenu *bar = [[[NSMenu alloc] initWithTitle:@"MainMenu"] autorelease];
	NSMenu *m = SUB(bar, @"Terminal");
	M(m, @"About Terminal", @selector(orderFrontStandardAboutPanel:), nil, 0, nil); SEP(m);
	M(m, @"Settings…", @selector(showSettings:), @",", CMD, d);                       /* the Settings window follows */
	NSMenu *sv = SUB(m, @"Services"); [app setServicesMenu:sv]; SEP(m);
	M(m, @"Secure Keyboard Entry", @selector(toggleSecureKeyboard:), nil, 0, d); SEP(m);
	M(m, @"Hide Terminal", @selector(hide:), @"h", CMD, nil); M(m, @"Hide Others", @selector(hideOtherApplications:), @"h", CMD | OPT, nil); M(m, @"Show All", @selector(unhideAllApplications:), nil, 0, nil); SEP(m);
	M(m, @"Quit Terminal", @selector(terminate:), @"q", CMD, nil);

	m = SUB(bar, @"Shell");
	NSMenuItem *nw = M(m, @"New Window", @selector(newWindow:), @"n", CMD, d); (void)nw;
	profileItems(SUB(m, @"New Window with Profile"), @selector(newWindow:), d);
	M(m, @"New Tab", @selector(newTab:), @"t", CMD, d);
	profileItems(SUB(m, @"New Tab with Profile"), @selector(newTab:), d);
	M(m, @"New Command…", @selector(newCommand:), @"n", CMD | SH, d); M(m, @"New Remote Connection…", @selector(newRemoteConnection:), @"k", CMD | SH, d); SEP(m);
	M(m, @"Open…", @selector(openDocument:), @"o", CMD, d); SUB(m, @"Open Recent"); SEP(m);
	M(m, @"Close Tab", @selector(closeTab:), @"w", CMD, d); M(m, @"Close Window", @selector(closeWindow:), @"w", CMD | SH, d); M(m, @"Split Pane", @selector(splitPane:), @"d", CMD, d); M(m, @"Close Split Pane", @selector(closeSplitPane:), @"d", CMD | SH, d); SEP(m);
	M(m, @"Save Windows as Group…", @selector(saveWindowGroup:), nil, 0, d); M(m, @"Open Window Group", @selector(openWindowGroup:), nil, 0, d); SEP(m);
	M(m, @"Export Settings…", @selector(exportSettings:), nil, 0, d); M(m, @"Export Text As…", @selector(exportText:), @"s", CMD | OPT, d); M(m, @"Export Selected Text As…", @selector(exportSelectedText:), nil, 0, d); SEP(m);
	M(m, @"Print…", @selector(print:), @"p", CMD, nil); M(m, @"Page Setup…", @selector(runPageLayout:), @"p", CMD | SH, nil); SEP(m);
	M(m, @"Show Inspector", @selector(showInspector:), @"i", CMD, d); M(m, @"Edit Title", @selector(editTitle:), nil, 0, d); M(m, @"Edit Background Colour", @selector(editBackground:), nil, 0, d); SEP(m);
	NSMenu *st = SUB(m, @"Settings"); profileItems(st, @selector(changeProfile:), d); SEP(st); M(st, @"Use Settings as Default", @selector(useSettingsAsDefault:), nil, 0, d);

	m = SUB(bar, @"Edit");
	M(m, @"Undo", @selector(undo:), @"z", CMD, nil); M(m, @"Redo", @selector(redo:), @"z", CMD | SH, nil); SEP(m);
	M(m, @"Cut", @selector(cut:), @"x", CMD, nil); M(m, @"Copy", @selector(copy:), @"c", CMD, nil);
	NSMenu *cs = SUB(m, @"Copy Special"); M(cs, @"Copy Plain Text", @selector(copyPlain:), nil, 0, d); M(cs, @"Copy Without Background Colour", @selector(copyPlain:), nil, 0, d);
	M(m, @"Paste", @selector(paste:), @"v", CMD, nil); M(m, @"Paste Selection", @selector(pasteSelection:), nil, 0, d); M(m, @"Paste Escaped Text", @selector(pasteEscaped:), nil, 0, d); SEP(m);
	M(m, @"Select All", @selector(selectAll:), @"a", CMD, nil); SEP(m);
	NSMenu *fm = SUB(m, @"Find");
	M(fm, @"Find…", @selector(showFindBar:), @"f", CMD, d); M(fm, @"Find Next", @selector(findNext:), @"g", CMD, d); M(fm, @"Find Previous", @selector(findPrevious:), @"g", CMD | SH, d);
	M(fm, @"Use Selection for Find", @selector(useSelectionForFind:), @"e", CMD, d); M(fm, @"Hide Find Bar", @selector(hideFindBar:), nil, 0, d);
	SEP(m); M(m, @"Clear Screen", @selector(clearScreen:), @"k", CMD, nil); M(m, @"Clear Scrollback", @selector(clearScrollback:), @"k", CMD | OPT, nil); M(m, @"Clear to Start", @selector(clearToStart:), nil, 0, nil);
	SEP(m); M(m, @"Reset", @selector(resetTerminal:), nil, 0, nil); M(m, @"Hard Reset", @selector(hardResetTerminal:), nil, 0, nil);

	m = SUB(bar, @"View");
	M(m, @"Show Tab Bar", @selector(toggleTabBar:), @"t", CMD | SH, d); SEP(m);
	M(m, @"Bigger", @selector(biggerFont:), @"+", CMD, nil); M(m, @"Smaller", @selector(smallerFont:), @"-", CMD, nil); M(m, @"Default Font Size", @selector(defaultFontSize:), @"0", CMD, nil); SEP(m);
	M(m, @"Show Colours", @selector(showColors:), @"c", CMD | SH, d); SEP(m);
	M(m, @"Allow Mouse Reporting", @selector(toggleMouseReporting:), nil, 0, d); M(m, @"Use Option as Meta Key", @selector(toggleOptionAsMeta:), nil, 0, d); SEP(m);
	NSMenu *nv = SUB(m, @"Navigate");
	M(nv, @"Line Up", @selector(scrollLineUp:), nil, 0, nil); M(nv, @"Line Down", @selector(scrollLineDown:), nil, 0, nil); M(nv, @"Page Up", @selector(scrollPageUp:), nil, 0, nil); M(nv, @"Page Down", @selector(scrollPageDown:), nil, 0, nil);
	M(nv, @"Scroll to Top", @selector(scrollToTop:), nil, 0, nil); M(nv, @"Scroll to Bottom", @selector(scrollToBottom:), nil, 0, nil); SEP(m);
	M(m, @"Enter Full Screen", @selector(toggleFullScreen:), @"f", CMD | CTL, nil);

	m = SUB(bar, @"Marks"); NSMenuItem *dummy = nil; (void)dummy;
	M(m, @"Mark", @selector(markLine:), @"u", CMD, nil); M(m, @"Unmark", @selector(unmarkLine:), @"u", CMD | SH, nil); M(m, @"Mark as Bookmark", @selector(markAsBookmark:), @"b", CMD | OPT, nil);
	M(m, @"Insert Bookmark", @selector(insertBookmark:), nil, 0, nil); SEP(m);
	M(m, @"Jump to Previous Mark", @selector(jumpToPreviousMark:), @"\uf700", CMD | CTL, nil); M(m, @"Jump to Next Mark", @selector(jumpToNextMark:), @"\uf701", CMD | CTL, nil);
	M(m, @"Jump to Previous Bookmark", @selector(jumpToPreviousBookmark:), @"\uf700", CMD | OPT, nil); M(m, @"Jump to Next Bookmark", @selector(jumpToNextBookmark:), @"\uf701", CMD | OPT, nil); SEP(m);
	M(m, @"Clear to Previous Mark", @selector(clearToPreviousMark:), nil, 0, nil); SEP(m);
	M(m, @"Automatically Mark Prompt Lines", @selector(toggleAutoMark:), nil, 0, d); M(m, @"Show Marks", @selector(toggleShowMarks:), nil, 0, d);

	m = SUB(bar, @"Window"); [app setWindowsMenu:m];
	M(m, @"Minimise", @selector(performMiniaturize:), @"m", CMD, nil); M(m, @"Zoom", @selector(performZoom:), nil, 0, nil); SEP(m);
	M(m, @"Show Previous Tab", @selector(previousTab:), @"\t", CTL | SH, d); M(m, @"Show Next Tab", @selector(nextTab:), @"\t", CTL, d); SEP(m);
	M(m, @"Cycle Through Windows", @selector(cycleWindows:), @"`", CMD, d); M(m, @"Bring All to Front", @selector(orderFrontAllWindows:), nil, 0, d);

	m = SUB(bar, @"Help"); if ([app respondsToSelector:@selector(setHelpMenu:)]) [app performSelector:@selector(setHelpMenu:) withObject:m];
	M(m, @"Terminal Help", @selector(showHelp:), @"?", CMD, d);
	[app setMainMenu:bar];
	[app run];
	[pool release];
	return 0;
}
