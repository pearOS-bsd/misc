/* Runs in GNUstep: for each "Class +|- selector" line of the file given as argument (the selectors of the SDK's headers, tools/appkit_coverage.py) asks the runtime whether the class answers it;
 * prints the totals and, per class, the missing ones. usage: appkit_probe LIST [CLASS] */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
int main(int argc, char **argv) { @autoreleasepool { [NSApplication sharedApplication];
	NSString *all = [NSString stringWithContentsOfFile: [NSString stringWithUTF8String: argv[1]] encoding: NSUTF8StringEncoding error: NULL];
	NSMutableDictionary *tot = [NSMutableDictionary dictionary], *have = [NSMutableDictionary dictionary]; NSMutableDictionary *miss = [NSMutableDictionary dictionary]; long T = 0, H = 0;
	for (NSString *l in [all componentsSeparatedByString: @"\n"]) {
		NSArray *p = [l componentsSeparatedByString: @" "]; if ([p count] != 3) continue; Class c = NSClassFromString(p[0]); SEL s = NSSelectorFromString(p[2]); BOOL cls = [p[1] isEqual: @"+"];
		BOOL ok = c && (cls ? [c respondsToSelector: s] : [c instancesRespondToSelector: s]); T++; if (ok) H++;
		tot[p[0]] = @([tot[p[0]] intValue] + 1); if (ok) have[p[0]] = @([have[p[0]] intValue] + 1); else { NSMutableArray *m = miss[p[0]]; if (!m) miss[p[0]] = m = [NSMutableArray array]; [m addObject: [p[1] stringByAppendingString: p[2]]]; }
	}
	printf("selectors answered by the runtime: %ld of %ld = %.1f %%\n", H, T, 100.0 * H / (T ? T : 1));
	if (argc > 2) { printf("%s missing: %s\n", argv[2], [[miss[[NSString stringWithUTF8String: argv[2]]] componentsJoinedByString: @" "] UTF8String]); return 0; }
	NSArray *ks = [tot keysSortedByValueUsingComparator: ^NSComparisonResult(id a, id b) { return [@([tot[b] intValue] - [have[b] intValue]) compare: @([tot[a] intValue] - [have[a] intValue])]; }];
	for (NSString *k in [ks subarrayWithRange: NSMakeRange(0, MIN(30, [ks count]))]) printf("%-34s apple %4d  answered %4d\n", [k UTF8String], [tot[k] intValue], [have[k] intValue]);
} return 0; }
