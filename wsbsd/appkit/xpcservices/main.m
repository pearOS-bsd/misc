/* Open and Save Panel Service (com.apple.appkit.xpc.openAndSavePanelService): the process in which the Open and Save panels of the programs run, as on the Mac (NSOpenPanel / NSSavePanel of a program talk to this service).
 * Here the programs are the Mach-O ones of the "open" layer (appkit/decompiled/src/OpenPanels.m); the panel itself is the one of the system (appkit/back-wsd/WsdFilePanel.m, GNUstep's NSOpenPanel / NSSavePanel with the pearOS theme).
 * Service name = socket WSBSD_XPC_DIR (default /var/run/xpc) / com.apple.appkit.xpc.openAndSavePanelService; frames of a 4 byte big endian length and a JSON object.
 *   request  {"id":1,"kind":"open"|"save","directory":"/path","name":"Untitled.txt","types":["txt"],"files":true,"dirs":false,"multiple":false,"prompt":"Open","message":"","createDirs":true,"hidden":false,"other":false}
 *   reply    {"id":1,"response":1 (OK) | 0 (Cancel),"urls":["/path/file"]} */
#import <AppKit/AppKit.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <dispatch/dispatch.h>

@interface PanelClient : NSObject { @public int fd; dispatch_source_t src; NSMutableData *buf; } @end
@implementation PanelClient @end
static NSMutableArray *sClients;

static void Reply(PanelClient *c, NSDictionary *o)
{
	NSData *j = [NSJSONSerialization dataWithJSONObject: o options: 0 error: NULL]; unsigned char h[4] = { (unsigned char)([j length] >> 24), (unsigned char)([j length] >> 16), (unsigned char)([j length] >> 8), (unsigned char)[j length] };
	write(c->fd, h, 4); write(c->fd, [j bytes], [j length]);
}

static void Run(PanelClient *c, NSDictionary *r)
{
	BOOL open = [r[@"kind"] isEqual: @"open"]; NSSavePanel *p = open ? [NSOpenPanel openPanel] : [NSSavePanel savePanel];
	if (open) { NSOpenPanel *o = (NSOpenPanel *)p; [o setCanChooseFiles: r[@"files"] ? [r[@"files"] boolValue] : YES]; [o setCanChooseDirectories: [r[@"dirs"] boolValue]]; [o setAllowsMultipleSelection: [r[@"multiple"] boolValue]]; }
	if ([r[@"directory"] length]) [p setDirectoryURL: [NSURL fileURLWithPath: r[@"directory"]]];
	if (!open && [r[@"name"] length]) [p setNameFieldStringValue: r[@"name"]];
	if ([r[@"types"] count]) [p setAllowedFileTypes: r[@"types"]];
	if ([r[@"prompt"] length]) [p setPrompt: r[@"prompt"]];
	if ([r[@"message"] length]) [p setMessage: r[@"message"]];
	[p setCanCreateDirectories: r[@"createDirs"] ? [r[@"createDirs"] boolValue] : YES]; [p setShowsHiddenFiles: [r[@"hidden"] boolValue]]; [p setAllowsOtherFileTypes: [r[@"other"] boolValue]];
	[NSApp activateIgnoringOtherApps: YES];
	NSInteger resp = [p runModal];
	NSMutableArray *urls = [NSMutableArray new];
	if (resp == NSOKButton) { if (open) for (NSURL *u in [(NSOpenPanel *)p URLs]) [urls addObject: [u path]]; else if ([p URL]) [urls addObject: [[p URL] path]]; }
	Reply(c, @{ @"id": r[@"id"] ?: @0, @"response": @(resp == NSOKButton ? 1 : 0), @"urls": urls });
}

static void Drop(PanelClient *c) { dispatch_source_cancel(c->src); [sClients removeObject: c]; }
static void Readable(PanelClient *c)
{
	char tmp[4096]; ssize_t n = read(c->fd, tmp, sizeof tmp); if (n <= 0) { Drop(c); return; }
	[c->buf appendBytes: tmp length: (NSUInteger)n];
	while ([c->buf length] >= 4) {
		const unsigned char *p = [c->buf bytes]; NSUInteger len = ((NSUInteger)p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]; if ([c->buf length] < 4 + len) return;
		id o = [NSJSONSerialization JSONObjectWithData: [c->buf subdataWithRange: NSMakeRange(4, len)] options: 0 error: NULL]; [c->buf replaceBytesInRange: NSMakeRange(0, 4 + len) withBytes: NULL length: 0];
		if ([o isKindOfClass: [NSDictionary class]]) Run(c, o);
		if (![sClients containsObject: c]) return;
	}
}

int main(int argc, char *argv[])
{
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		const char *dir = getenv("WSBSD_XPC_DIR") ?: "/var/run/xpc"; mkdir(dir, 0777);
		char path[512]; snprintf(path, sizeof path, "%s/com.apple.appkit.xpc.openAndSavePanelService", dir);
		int ls = socket(AF_UNIX, SOCK_STREAM, 0); struct sockaddr_un a; memset(&a, 0, sizeof a); a.sun_family = AF_UNIX; strlcpy(a.sun_path, path, sizeof a.sun_path);
		unlink(path); if (bind(ls, (struct sockaddr *)&a, sizeof a) != 0 || listen(ls, 16) != 0) { NSLog(@"openAndSavePanelService: cannot listen on %s", path); return 1; }
		chmod(path, 0666); fcntl(ls, F_SETFL, O_NONBLOCK); sClients = [NSMutableArray new];
		dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, ls, 0, dispatch_get_main_queue());
		dispatch_source_set_event_handler(src, ^{
			int fd = accept(ls, NULL, NULL); if (fd < 0) return;
			PanelClient *c = [PanelClient new]; c->fd = fd; c->buf = [NSMutableData new];
			c->src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_main_queue());
			dispatch_source_set_event_handler(c->src, ^{ Readable(c); }); dispatch_source_set_cancel_handler(c->src, ^{ close(fd); });
			dispatch_resume(c->src); [sClients addObject: c];
		});
		dispatch_resume(src);
		static dispatch_source_t keep; keep = src;
		[app run];
	}
	return 0;
}
