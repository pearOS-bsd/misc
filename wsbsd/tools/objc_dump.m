/* objc_dump FRAMEWORK_BINARY [PREFIX]: loads the image with dlopen and prints every Objective-C class and protocol that comes from it (superclass, protocols, ivars with offsets and type encodings,
 * class and instance methods with type encodings, properties with attributes). The inventory the reimplementations are checked against.
 * clang -fobjc-arc -framework Foundation tools/objc_dump.m -o /tmp/objc_dump */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
int main(int argc, char **argv)
{
	if (argc < 2) { fprintf(stderr, "usage: objc_dump image [prefix]\n"); return 1; }
	void *h = dlopen(argv[1], RTLD_NOW); if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
	const char *prefix = argc > 2 ? argv[2] : "";
	unsigned n = 0; Class *all_classes = objc_copyClassList(&n); const char *base = strrchr(argv[1], '/'); base = base ? base + 1 : argv[1];
	NSMutableArray *sorted = [NSMutableArray array];                                  /* the image path of a class is the one dyld resolved: match on the file name */
	for (unsigned i = 0; i < n; i++) { const char *img = class_getImageName(all_classes[i]); if (img && strlen(img) >= strlen(base) && strcmp(img + strlen(img) - strlen(base), base) == 0) [sorted addObject: @(class_getName(all_classes[i]))]; }
	[sorted sortUsingSelector: @selector(compare:)]; free(all_classes);
	for (NSString *nm in sorted) {
		if (*prefix && ![nm hasPrefix: @(prefix)]) continue; Class c = objc_getClass([nm UTF8String]); if (!c) continue;
		printf("@class %s : %s", [nm UTF8String], class_getSuperclass(c) ? class_getName(class_getSuperclass(c)) : "-");
		unsigned pc = 0; Protocol * __unsafe_unretained *ps = class_copyProtocolList(c, &pc); if (pc) { printf(" <"); for (unsigned i = 0; i < pc; i++) printf("%s%s", i ? ", " : "", protocol_getName(ps[i])); printf(">"); } free(ps);
		printf(" instanceSize=%zu\n", class_getInstanceSize(c));
		unsigned ic = 0; Ivar *iv = class_copyIvarList(c, &ic); for (unsigned i = 0; i < ic; i++) printf("  ivar +%td %s %s\n", ivar_getOffset(iv[i]), ivar_getName(iv[i]), ivar_getTypeEncoding(iv[i]) ?: ""); free(iv);
		unsigned prc = 0; objc_property_t *pr = class_copyPropertyList(c, &prc); for (unsigned i = 0; i < prc; i++) printf("  property %s (%s)\n", property_getName(pr[i]), property_getAttributes(pr[i])); free(pr);
		for (int meta = 1; meta >= 0; meta--) {
			Class k = meta ? object_getClass(c) : c; unsigned mc = 0; Method *ms = class_copyMethodList(k, &mc);
			NSMutableArray *lines = [NSMutableArray array];
			for (unsigned i = 0; i < mc; i++) [lines addObject: [NSString stringWithFormat: @"  %c%s %s  imp=+0x%lx", meta ? '+' : '-', sel_getName(method_getName(ms[i])), method_getTypeEncoding(ms[i]) ?: "", (unsigned long)((uintptr_t)method_getImplementation(ms[i]))]];
			[lines sortUsingSelector: @selector(compare:)]; for (NSString *l in lines) printf("%s\n", [l UTF8String]); free(ms);
		}
	}
	unsigned pcount = 0; Protocol * __unsafe_unretained *all = objc_copyProtocolList(&pcount); NSMutableArray *pn = [NSMutableArray array];
	for (unsigned i = 0; i < pcount; i++) { const char *nm = protocol_getName(all[i]); if (strncmp(nm, prefix, strlen(prefix)) == 0 && ([@(nm) hasPrefix: @"CW"] || [@(nm) hasPrefix: @"CWF"] || strlen(prefix))) [pn addObject: @(nm)]; }
	[pn sortUsingSelector: @selector(compare:)];
	for (NSString *nm in pn) { Protocol *p = objc_getProtocol([nm UTF8String]); printf("@protocol %s\n", [nm UTF8String]);
		for (int req = 1; req >= 0; req--) for (int inst = 1; inst >= 0; inst--) { unsigned mc = 0; struct objc_method_description *d = protocol_copyMethodDescriptionList(p, req, inst, &mc); for (unsigned i = 0; i < mc; i++) printf("  %s %c%s %s\n", req ? "required" : "optional", inst ? '-' : '+', sel_getName(d[i].name), d[i].types ?: ""); free(d); } }
	return 0;
}
