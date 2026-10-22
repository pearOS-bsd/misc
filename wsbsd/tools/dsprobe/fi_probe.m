/* Prints what the Finder's node model (FINode of DesktopServicesPriv) says about the files of the test tree: sh make_tree.sh DIR; fi_probe DIR. Run on the Mac (real framework) and on wsbsd, diff. */
#import <Foundation/Foundation.h>
#include <dlfcn.h>
static NSString *Norm(NSString *s) { NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern: @"/\\.file/id=[0-9.]+" options: 0 error: NULL]; return [r stringByReplacingMatchesInString: s options: 0 range: NSMakeRange(0, [s length]) withTemplate: @"<fileref>"]; }
int main(int argc, char **argv)
{
	@autoreleasepool {
		const char *fw = getenv("FI_FRAMEWORK") ?: "/System/Library/PrivateFrameworks/DesktopServicesPriv.framework/DesktopServicesPriv"; void *h = dlopen(fw, RTLD_NOW); if (!h) { printf("dlopen: %s\n", dlerror()); return 1; }
		Class c = NSClassFromString(@"FINode"); if ([c respondsToSelector: NSSelectorFromString(@"start")]) [c performSelector: NSSelectorFromString(@"start")];
		NSString *root = [NSString stringWithUTF8String: argv[1]]; NSArray *props = @[ @"displayName", @"fileName", @"isFolder", @"isPackage", @"isContainer", @"typeIdentifier", @"contentModificationDate", @"creationDate", @"documentSize", @"isVisible", @"isTrashed", @"childItemCount", @"isPopulated", @"isShared", @"isValid", @"fileURL", @"sanitizedName" ];
		NSMutableArray *paths = [NSMutableArray array]; NSDirectoryEnumerator *en = [[NSFileManager defaultManager] enumeratorAtPath: root]; for (NSString *p in en) [paths addObject: p]; [paths addObject: @""]; [paths sortUsingSelector: @selector(compare:)];
		for (NSString *rel in paths) {
			NSURL *u = [NSURL fileURLWithPath: [root stringByAppendingPathComponent: rel]]; id n = [c performSelector: NSSelectorFromString(@"fiNodeFromURL:") withObject: u]; printf("== %s\n", [rel UTF8String]);
			if (!n) { printf("  (nil)\n"); continue; }
			for (NSString *k in props) { id v = nil; @try { v = [n valueForKey: k]; } @catch (id e) { v = @"<exc>"; } NSString *t = Norm([v description] ?: @"(nil)"); if ([k isEqual: @"fileURL"]) t = [t stringByReplacingOccurrencesOfString: root withString: @"ROOT"]; printf("  %s = %s\n", [k UTF8String], [t UTF8String]); }
		}
	}
	return 0;
}
