/* Per type identifier: conformances to a fixed list of roots, preferred tags, description, whether it is declared. Mac and wsbsd, diff. */
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static NSString *Tag(NSString *u, CFStringRef cls) { CFStringRef r = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)u, cls); return r ? CFBridgingRelease(r) : @"-"; }
int main(int argc, char **argv)
{
	@autoreleasepool {
		id top = [NSJSONSerialization JSONObjectWithData: [NSData dataWithContentsOfFile: [NSString stringWithUTF8String: argv[1]]] options: 0 error: NULL]; NSArray *db = [top isKindOfClass: [NSDictionary class]] ? top[@"types"] : top;
		NSArray *roots = @[ @"public.item", @"public.data", @"public.content", @"public.text", @"public.image", @"public.audio", @"public.movie", @"public.archive", @"public.executable", @"public.directory", @"public.folder", @"public.plain-text", @"public.xml", @"public.source-code", @"com.apple.bundle", @"com.apple.package", @"public.composite-content", @"public.database", @"public.font", @"public.url", @"public.message", @"public.contact", @"public.disk-image", @"public.script", @"public.html", @"public.json", @"com.adobe.pdf" ];
		NSMutableArray *ids = [NSMutableArray array]; for (NSDictionary *t in db) [ids addObject: t[@"uti"]];
		[ids addObjectsFromArray: @[ @"dyn.age81c", @"dyn.ah62d4rv4ge80k2py", @"dyn.ah62d4uv4ge81y8x4", @"dyn.agq80cp5c", @"not.a.real.type", @"com.example.unknown", @"PUBLIC.TEXT", @"public.Plain-Text" ]];
		for (NSString *u in ids) {
			NSMutableString *bits = [NSMutableString string]; for (NSString *r in roots) [bits appendString: UTTypeConformsTo((__bridge CFStringRef)u, (__bridge CFStringRef)r) ? @"1" : @"0"];
			CFDictionaryRef decl = UTTypeCopyDeclaration((__bridge CFStringRef)u); BOOL declared = decl != NULL; if (decl) CFRelease(decl);
			printf("%s conf=%s ext=%s mime=%s os=%s decl=%d dyn=%d\n", [u UTF8String], [bits UTF8String], [Tag(u, kUTTagClassFilenameExtension) UTF8String], [Tag(u, kUTTagClassMIMEType) UTF8String], [Tag(u, kUTTagClassOSType) UTF8String], declared, [u hasPrefix: @"dyn."]);
		}
	}
	return 0;
}
