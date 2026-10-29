/* The volumes of the machine as the Finder lists them: the startup disk (Macintosh HD) and what is mounted under /media, /mnt, /Volumes (external disks, discs, servers), found through getmntinfo(3). */
#import "TFinderViews.h"
#import <CoreServices/CoreServices.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ucred.h>

NSArray *TFVolumes(void)
{
	struct statfs *fs = NULL; int n = getmntinfo(&fs, MNT_NOWAIT); NSMutableArray *out = [NSMutableArray array]; NSSet *skip = [NSSet setWithObjects: @"devfs", @"tmpfs", @"procfs", @"fdescfs", @"linprocfs", @"linsysfs", @"nullfs", @"autofs", @"unionfs", nil];
	for (int i = 0; i < n; i++) {
		NSString *type = @(fs[i].f_fstypename), *on = @(fs[i].f_mntonname), *from = @(fs[i].f_mntfromname); if ([skip containsObject: type]) continue;
		BOOL root = [on isEqual: @"/"]; BOOL ext = [on hasPrefix: @"/media/"] || [on hasPrefix: @"/mnt/"] || [on hasPrefix: @"/Volumes/"] || [on hasPrefix: @"/run/media/"]; if (!root && !ext) continue;
		NSString *kind = root ? @"internal" : [type isEqual: @"cd9660"] || [type isEqual: @"udf"] ? @"optical" : ([type isEqual: @"nfs"] || [type isEqual: @"smbfs"]) ? @"server" : @"external";
		[out addObject: @{ @"path": on, @"name": root ? @"Macintosh HD" : [on lastPathComponent], @"type": type, @"from": from, @"kind": kind, @"eject": @(!root) }];
	}
	/* disk images (.dmg) "mounted" by dmgtool: folders of /Volumes that carry the marker .wsbsd-diskimage (the path of the image) */
	NSFileManager *fm = [NSFileManager defaultManager]; NSMutableSet *have = [NSMutableSet set]; for (NSDictionary *v in out) [have addObject: v[@"path"]];
	for (NSString *n in [fm contentsOfDirectoryAtPath: @"/Volumes" error: NULL]) { NSString *p = [@"/Volumes" stringByAppendingPathComponent: n]; if ([n hasPrefix: @"."] || [have containsObject: p]) continue;
		if ([fm fileExistsAtPath: [p stringByAppendingPathComponent: @".wsbsd-diskimage"]]) [out addObject: @{ @"path": p, @"name": n, @"type": @"diskimage", @"from": [NSString stringWithContentsOfFile: [p stringByAppendingPathComponent: @".wsbsd-diskimage"] encoding: NSUTF8StringEncoding error: NULL] ?: @"", @"kind": @"external", @"eject": @YES }]; }
	return out;
}
static NSString *DmgTool(void) { for (NSString *c in @[ @"/usr/local/bin/dmgtool", @"/usr/bin/dmgtool", @"/root/dmgtool" ]) if ([[NSFileManager defaultManager] isExecutableFileAtPath: c]) return c; return nil; }
/* Opening a .dmg as the Mac does: the image is "mounted" as a volume under /Volumes/<its name> (dmgtool reads the UDIF container and the HFS+ volume and extracts the files: the volume is a folder of the in-memory /Volumes, ejecting it removes it). Returns the volume's path, nil with a reason on failure. Runs for as long as the extraction takes: call it off the main thread. */
NSString *TFMountDiskImage(NSString *dmg, NSString **err)
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSString *tool = DmgTool(); if (!tool) { if (err) *err = @"dmgtool is not installed"; return nil; }
	for (NSDictionary *v in TFVolumes()) if ([v[@"type"] isEqual: @"diskimage"] && [v[@"from"] isEqual: dmg]) return v[@"path"];       /* already mounted */
	NSString *tmp = [NSString stringWithFormat: @"/Volumes/.mounting-%d-%u", (int)getpid(), arc4random()];
	NSTask *t = [[NSTask alloc] init]; NSPipe *out = [NSPipe pipe], *er = [NSPipe pipe]; [t setLaunchPath: tool]; [t setArguments: @[ @"extract", dmg, tmp ]]; [t setStandardOutput: out]; [t setStandardError: er];
	@try { [t launch]; } @catch (NSException *e) { if (err) *err = @"dmgtool did not start"; return nil; }
	NSData *od = [[out fileHandleForReading] readDataToEndOfFile], *ed = [[er fileHandleForReading] readDataToEndOfFile]; [t waitUntilExit];
	NSString *name = [[[NSString alloc] initWithData: od encoding: NSUTF8StringEncoding] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([t terminationStatus] != 0 && [t terminationStatus] != 3) { [fm removeItemAtPath: tmp error: NULL]; if (err) *err = [[NSString alloc] initWithData: ed encoding: NSUTF8StringEncoding]; return nil; }
	if (![name length]) name = [[dmg lastPathComponent] stringByDeletingPathExtension]; name = [name stringByReplacingOccurrencesOfString: @"/" withString: @":"];
	NSString *dest = [@"/Volumes" stringByAppendingPathComponent: name]; for (int i = 1; [fm fileExistsAtPath: dest]; i++) dest = [@"/Volumes" stringByAppendingPathComponent: [NSString stringWithFormat: @"%@ %d", name, i]];
	if (![fm moveItemAtPath: tmp toPath: dest error: NULL]) { [fm removeItemAtPath: tmp error: NULL]; if (err) *err = @"the volume could not be created in /Volumes"; return nil; }
	[dmg writeToFile: [dest stringByAppendingPathComponent: @".wsbsd-diskimage"] atomically: NO encoding: NSUTF8StringEncoding error: NULL];
	return dest;
}
NSString *TFDisplayName(NSString *path) { if ([path isEqual: @"/"]) return @"Macintosh HD"; if ([path isEqual: [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]]) return @"Trash"; return [path lastPathComponent]; }
BOOL TFEject(NSString *mount)                                                              /* the volume is unmounted (and an optical disc ejected) */
{
	if ([[NSFileManager defaultManager] fileExistsAtPath: [mount stringByAppendingPathComponent: @".wsbsd-diskimage"]]) return [[NSFileManager defaultManager] removeItemAtPath: mount error: NULL];       /* a disk image: its folder goes away */
	NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: @"/sbin/umount"]; [t setArguments: @[ mount ]]; @try { [t launch]; [t waitUntilExit]; } @catch (NSException *e) { return NO; } return [t terminationStatus] == 0;
}

BOOL TFIsPackage(NSString *p)                                                         /* a folder the Finder shows as one item: an application, a bundle, a document package */
{
	static NSSet *known; if (!known) known = [NSSet setWithObjects: @"app", @"bundle", @"framework", @"plugin", @"kext", @"rtfd", @"pages", @"numbers", @"key", @"xcodeproj", @"xcworkspace", @"playground", @"photoslibrary", @"pkg", @"mpkg", @"prefpane", @"saver", @"qlgenerator", @"mdimporter", @"xpc", @"appex", @"wdgt", @"dSYM", @"workflow", @"sparsebundle", @"theater", @"fcpbundle", @"band", nil];
	NSString *e = [[p pathExtension] lowercaseString]; if (![e length]) return NO; if ([known containsObject: e] || [known containsObject: [p pathExtension]]) return YES;
	NSString *uti = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)e, NULL); return uti && ![uti hasPrefix: @"dyn."] && UTTypeConformsTo((__bridge CFStringRef)uti, CFSTR("com.apple.package"));
}

NSString *TFKindCategory(NSString *path, BOOL dir)                                    /* the kinds of the search bar's Kind filter */
{
	if (TFIsPackage(path) && [[[path pathExtension] lowercaseString] isEqual: @"app"]) return @"Applications"; if (dir) return @"Folders"; NSString *e = [[path pathExtension] lowercaseString];
	if ([@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"tif", @"bmp", @"heic", @"webp", @"svg", @"icns", @"psd" ] containsObject: e]) return @"Images"; if ([@[ @"mp3", @"m4a", @"wav", @"aac", @"flac", @"ogg", @"aiff", @"opus" ] containsObject: e]) return @"Audio";
	if ([@[ @"mov", @"mp4", @"m4v", @"avi", @"mkv", @"webm", @"mpg", @"mpeg" ] containsObject: e]) return @"Movies"; if ([e isEqual: @"pdf"]) return @"PDF"; if ([@[ @"key", @"ppt", @"pptx", @"odp" ] containsObject: e]) return @"Presentations";
	if ([@[ @"txt", @"md", @"rtf", @"doc", @"docx", @"pages", @"odt", @"html", @"xml", @"json", @"csv", @"log" ] containsObject: e]) return @"Documents"; return @"Other";
}
