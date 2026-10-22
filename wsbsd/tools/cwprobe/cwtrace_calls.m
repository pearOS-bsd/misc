/* cwtrace_calls (macOS only): calls every argument-less getter of CWInterface / CWWiFiClient with a MARK line before each; run under lldb with a breakpoint on -[CWFInterface *] to see which CoreWiFi calls each CoreWLAN
 * method makes (tools/cwprobe/trace.sh). clang -fobjc-arc -framework Foundation -framework CoreWLAN cwtrace_calls.m -o /tmp/cwtrace_calls */
#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
#import <objc/runtime.h>
static void CallAll(id obj, NSString *tag)
{
	unsigned n = 0; Method *ms = class_copyMethodList([obj class], &n); NSMutableArray *names = [NSMutableArray array];
	for (unsigned i = 0; i < n; i++) { SEL s = method_getName(ms[i]); NSString *nm = NSStringFromSelector(s); if ([nm containsString: @":"]) continue; if ([nm hasPrefix: @"."] || [@[ @"dealloc", @"init", @"copy", @"mutableCopy", @"autorelease", @"retain", @"release", @"enableHostAPMode", @"disableHostAPMode", @"disassociate", @"clearScanCache", @"description", @"hash" ] containsObject: nm]) continue; [names addObject: nm]; }
	free(ms); [names sortUsingSelector: @selector(compare:)];
	for (NSString *nm in names) { NSLog(@"MARK %@ %@", tag, nm); @try { NSMethodSignature *sig = [obj methodSignatureForSelector: NSSelectorFromString(nm)]; NSInvocation *inv = [NSInvocation invocationWithMethodSignature: sig]; [inv setSelector: NSSelectorFromString(nm)]; [inv setTarget: obj]; [inv invoke]; } @catch (NSException *e) { NSLog(@"MARK exception %@", e.name); } }
}
int main(int argc, char **argv)
{
	@autoreleasepool { CWWiFiClient *c = [CWWiFiClient sharedWiFiClient]; CWInterface *i = [c interface]; NSLog(@"MARK ready"); CallAll(i, @"CWInterface"); CallAll(c, @"CWWiFiClient"); NSLog(@"MARK done"); }
	return 0;
}
