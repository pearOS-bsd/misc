/* The volumes of the machine as the Finder lists them: the startup disk (Macintosh HD) and what is mounted under /media, /mnt, /Volumes (external disks, discs, servers), found through getmntinfo(3). */
#import "TFinderViews.h"
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
	return out;
}
NSString *TFDisplayName(NSString *path) { if ([path isEqual: @"/"]) return @"Macintosh HD"; if ([path isEqual: [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]]) return @"Trash"; return [path lastPathComponent]; }
BOOL TFEject(NSString *mount)                                                              /* the volume is unmounted (and an optical disc ejected) */
{
	NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: @"/sbin/umount"]; [t setArguments: @[ mount ]]; @try { [t launch]; [t waitUntilExit]; } @catch (NSException *e) { return NO; } return [t terminationStatus] == 0;
}
