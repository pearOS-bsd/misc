/* Uniform type identifier probe: sh -c 'ut_probe DB.json' prints what the system says for every tag of the table and for made-up tags (dynamic identifiers). Mac and wsbsd, diff. */
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static NSString *Pref(CFStringRef cls, NSString *tag, NSString *conf) { CFStringRef r = UTTypeCreatePreferredIdentifierForTag(cls, (__bridge CFStringRef)tag, conf ? (__bridge CFStringRef)conf : NULL); return r ? CFBridgingRelease(r) : @"(nil)"; }
int main(int argc, char **argv)
{
	@autoreleasepool {
		id top = [NSJSONSerialization JSONObjectWithData: [NSData dataWithContentsOfFile: [NSString stringWithUTF8String: argv[1]]] options: 0 error: NULL]; NSArray *db = [top isKindOfClass: [NSDictionary class]] ? top[@"types"] : top;
		NSMutableOrderedSet *exts = [NSMutableOrderedSet orderedSet], *mimes = [NSMutableOrderedSet orderedSet], *oss = [NSMutableOrderedSet orderedSet];
		for (NSDictionary *t in db) { [exts addObjectsFromArray: t[@"tags"][@"ext"]]; [mimes addObjectsFromArray: t[@"tags"][@"mime"]]; [oss addObjectsFromArray: t[@"tags"][@"ostype"]]; }
		[exts addObjectsFromArray: @[ @"zzz", @"dat", @"abc123", @"x", @"verylongextensionname", @"ÄÖ", @"a.b", @"", @"TXT", @"Txt", @"JPG" ]]; [mimes addObjectsFromArray: @[ @"application/x-unknown-thing", @"text/x-foo", @"image/x-bar" ]]; [oss addObjectsFromArray: @[ @"ZZZZ", @"abcd" ]];
		for (NSString *e in exts) printf("ext %s -> %s\n", [e UTF8String], [Pref(kUTTagClassFilenameExtension, e, nil) UTF8String]);
		for (NSString *e in @[ @"txt", @"zzz", @"dat", @"jpg", @"mp3" ]) for (NSString *c in @[ @"public.data", @"public.image", @"public.audio", @"public.text" ]) printf("ext %s conf %s -> %s\n", [e UTF8String], [c UTF8String], [Pref(kUTTagClassFilenameExtension, e, c) UTF8String]);
		for (NSString *m in mimes) printf("mime %s -> %s\n", [m UTF8String], [Pref(kUTTagClassMIMEType, m, nil) UTF8String]);
		for (NSString *o in oss) printf("ostype %s -> %s\n", [o UTF8String], [Pref(kUTTagClassOSType, o, nil) UTF8String]);
	}
	return 0;
}
