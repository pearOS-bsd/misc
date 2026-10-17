/* Gatekeeper's quarantine, as an application sees it. A file that came from the network carries the extended attribute com.apple.quarantine: "<flags>;<time in hex>;<agent>;<UUID>" (flags: 0x0001
 * downloaded, 0x0002 ..., 0x0040 the user approved it, 0x0080 ...). Launch Services asks the user before it opens an application or a document carrying it ("... is an app downloaded from the
 * Internet. Are you sure you want to open it?"); when the user agrees the approved flag is set and the question is not asked again. Applications that download (and this system's own tools)
 * mark what they write with WsbsdQuarantineMark. NSWorkspace's open calls do the check here; command line tools are not asked, as on a Mac. */
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <sys/xattr.h>
#include <stdio.h>
#include <uuid.h>
#include <stdlib.h>
#include <string.h>

NSString *const WsbsdQuarantineAttribute = @"com.apple.quarantine";

static NSString *readQuarantine(NSString *path)
{
	char buf[512]; ssize_t n = getxattr([path fileSystemRepresentation], "com.apple.quarantine", buf, sizeof buf - 1, 0, 0);
	if (n <= 0) return nil;
	buf[n] = 0; return [NSString stringWithUTF8String: buf];
}
BOOL WsbsdQuarantineMark(NSString *path, NSString *agent)
{
	uuid_t u; char *us = NULL; uint32_t st; uuid_create(&u, &st); uuid_to_string(&u, &us, &st);
	for (char *c = us; c && *c; c++) if (*c >= 'a' && *c <= 'f') *c -= 32;
	NSString *v = [NSString stringWithFormat: @"0083;%08lx;%@;%s", (unsigned long)[[NSDate date] timeIntervalSince1970], agent ?: @"wsbsd", us ?: ""];
	free(us);
	const char *c = [v UTF8String];
	return setxattr([path fileSystemRepresentation], "com.apple.quarantine", c, strlen(c), 0, 0) == 0;
}
/* YES when the file is quarantined and the user has not yet approved it */
BOOL WsbsdQuarantineNeedsApproval(NSString *path)
{
	NSString *q = readQuarantine(path); if (!q) return NO;
	unsigned flags = 0; sscanf([q UTF8String], "%x", &flags);
	return (flags & 0x40) == 0;
}
static void approve(NSString *path)
{
	NSString *q = readQuarantine(path); if (!q) return;
	NSMutableArray *parts = [[q componentsSeparatedByString: @";"] mutableCopy]; unsigned flags = 0; sscanf([[parts objectAtIndex: 0] UTF8String], "%x", &flags);
	[parts replaceObjectAtIndex: 0 withObject: [NSString stringWithFormat: @"%04x", flags | 0x40]];
	const char *c = [[parts componentsJoinedByString: @";"] UTF8String]; setxattr([path fileSystemRepresentation], "com.apple.quarantine", c, strlen(c), 0, 0);
}
static BOOL askUser(NSString *path)
{
	NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
	BOOL app = [[path pathExtension] isEqualToString: @"app"];
	NSAlert *a = [[NSAlert alloc] init];
	[a setMessageText: [NSString stringWithFormat: @"“%@” is %@ downloaded from the Internet. Are you sure you want to open it?", name, app ? @"an app" : @"a file"]];
	[a setInformativeText: [NSString stringWithFormat: @"Apple cannot check it for malicious software.\n%@", path]];
	[a addButtonWithTitle: @"Open"]; [a addButtonWithTitle: @"Cancel"];
	BOOL ok = [a runModal] == NSAlertFirstButtonReturn;
	if (ok) approve(path);
	return ok;
}
static BOOL allowed(NSString *path) { return !path || !WsbsdQuarantineNeedsApproval(path) || askUser(path); }

static IMP origLaunch, origOpenFile, origOpenFileWith, origOpenURL;
static BOOL wsLaunch(id self, SEL _cmd, NSString *app) { NSString *p = [self fullPathForApplication: app] ?: app; return allowed(p) ? ((BOOL (*)(id, SEL, id))origLaunch)(self, _cmd, app) : NO; }
static BOOL wsOpenFile(id self, SEL _cmd, NSString *f) { return allowed(f) ? ((BOOL (*)(id, SEL, id))origOpenFile)(self, _cmd, f) : NO; }
static BOOL wsOpenFileWith(id self, SEL _cmd, NSString *f, NSString *app) { return (allowed(f) && allowed(app)) ? ((BOOL (*)(id, SEL, id, id))origOpenFileWith)(self, _cmd, f, app) : NO; }
static BOOL wsOpenURL(id self, SEL _cmd, NSURL *u) { return ([u isFileURL] && !allowed([u path])) ? NO : ((BOOL (*)(id, SEL, id))origOpenURL)(self, _cmd, u); }

@interface WsbsdGatekeeper : NSObject @end
@implementation WsbsdGatekeeper
+ (void)load
{
	Class c = objc_getClass("NSWorkspace");
	if (!c) return;
	Method m;
	if ((m = class_getInstanceMethod(c, sel_registerName("launchApplication:"))) && !origLaunch) origLaunch = method_setImplementation(m, (IMP)wsLaunch);
	if ((m = class_getInstanceMethod(c, sel_registerName("openFile:"))) && !origOpenFile) origOpenFile = method_setImplementation(m, (IMP)wsOpenFile);
	if ((m = class_getInstanceMethod(c, sel_registerName("openFile:withApplication:"))) && !origOpenFileWith) origOpenFileWith = method_setImplementation(m, (IMP)wsOpenFileWith);
	if ((m = class_getInstanceMethod(c, sel_registerName("openURL:"))) && !origOpenURL) origOpenURL = method_setImplementation(m, (IMP)wsOpenURL);
}
@end
