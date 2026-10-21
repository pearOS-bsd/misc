/* CFPlugIn over dlopen: a plug-in is a bundle whose Info.plist lists CFPlugInFactories (factory UUID -> function name) and CFPlugInTypes (type UUID -> factory UUIDs). The executable is loaded the first time
 * a factory is asked for; instances are counted per factory the way CFPlugInAddInstanceForFactory / RemoveInstanceForFactory report them. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CFPlugIn.h>
#include <dlfcn.h>

@interface WsbsdPlugInInfo : NSObject { @public CFBundleRef bundle; void *handle; NSString *path; NSDictionary *info; } @end
@implementation WsbsdPlugInInfo @end

static NSMutableDictionary *gFactories;                                  /* UUID string -> NSValue(function pointer) */
static NSMutableDictionary *gFactoryPlugIn;                              /* UUID string -> WsbsdPlugInInfo (for by-name lookups) */
static NSMutableDictionary *gInstances;                                  /* UUID string -> NSNumber (live instances) */
static NSMutableDictionary *gPlugIns;                                    /* bundle path -> WsbsdPlugInInfo */
static NSLock *gLock;

static void Init(void) { static dispatch_once_t once; dispatch_once(&once, ^{ gFactories = [NSMutableDictionary new]; gFactoryPlugIn = [NSMutableDictionary new]; gInstances = [NSMutableDictionary new]; gPlugIns = [NSMutableDictionary new]; gLock = [NSLock new]; }); }
static NSString *UUIDKey(CFUUIDRef u) { return u ? [(NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, u)) uppercaseString] : nil; }
static WsbsdPlugInInfo *InfoFor(CFBundleRef b) { Init(); for (WsbsdPlugInInfo *p in [gPlugIns allValues]) if (p->bundle == b) return p; return nil; }

/* the executable of the bundle: Contents/<platform>/<CFBundleExecutable> or the same under the bundle's top level, with .so appended when plain names are not found */
static NSString *ExecutablePath(NSString *bundlePath, NSDictionary *info)
{
	NSString *exec = info[@"CFBundleExecutable"]; if (![exec length]) exec = [[bundlePath lastPathComponent] stringByDeletingPathExtension];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *dir in @[ @"Contents/FreeBSD", @"Contents/MacOS", @"Contents", @"" ])
		for (NSString *name in @[ exec, [exec stringByAppendingString: @".so"], [@"lib" stringByAppendingString: [exec stringByAppendingString: @".so"]] ]) {
			NSString *p = [[bundlePath stringByAppendingPathComponent: dir] stringByAppendingPathComponent: name];
			BOOL isDir; if ([fm fileExistsAtPath: p isDirectory: &isDir] && !isDir) return p;
		}
	return nil;
}
static BOOL LoadPlugIn(WsbsdPlugInInfo *p)
{
	if (p->handle) return YES;
	NSString *exec = ExecutablePath(p->path, p->info); if (!exec) return NO;
	p->handle = dlopen([exec fileSystemRepresentation], RTLD_NOW | RTLD_LOCAL);
	if (!p->handle) NSLog(@"CFPlugIn: %@: %s", exec, dlerror());
	return p->handle != NULL;
}

CFPlugInRef CFPlugInCreate(CFAllocatorRef allocator, CFURLRef url)
{
	Init(); (void)allocator;
	NSString *path = [(__bridge NSURL *)url path]; if (!path) return NULL;
	[gLock lock]; WsbsdPlugInInfo *p = gPlugIns[path];
	if (!p) {
		NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: [path stringByAppendingPathComponent: @"Contents/Info.plist"]] ?: [NSDictionary dictionaryWithContentsOfFile: [path stringByAppendingPathComponent: @"Info.plist"]];
		if (!info || !info[@"CFPlugInFactories"]) { [gLock unlock]; return NULL; }
		p = [WsbsdPlugInInfo new]; p->path = path; p->info = info; p->bundle = CFBundleCreate(NULL, url); gPlugIns[path] = p;
		for (NSString *uuid in info[@"CFPlugInFactories"]) gFactoryPlugIn[[uuid uppercaseString]] = p;
	}
	[gLock unlock]; return p->bundle;
}
CFBundleRef CFPlugInGetBundle(CFPlugInRef plugIn) { return plugIn; }

CFArrayRef CFPlugInFindFactoriesForPlugInTypeInPlugIn(CFUUIDRef typeUUID, CFPlugInRef plugIn)
{
	WsbsdPlugInInfo *p = InfoFor(plugIn); if (!p) return NULL;
	NSArray *ids = p->info[@"CFPlugInTypes"][UUIDKey(typeUUID)]; if (!ids) return NULL;
	NSMutableArray *out = [NSMutableArray array];
	for (NSString *s in ids) { CFUUIDRef u = CFUUIDCreateFromString(NULL, (__bridge CFStringRef)s); if (u) { [out addObject: (__bridge id)u]; CFRelease(u); } }
	return (CFArrayRef)CFBridgingRetain(out);
}

Boolean CFPlugInRegisterFactoryFunction(CFUUIDRef factoryUUID, CFPlugInFactoryFunction func)
{
	Init(); if (!factoryUUID || !func) return false;
	[gLock lock]; gFactories[UUIDKey(factoryUUID)] = [NSValue valueWithPointer: (void *)func]; [gLock unlock]; return true;
}
Boolean CFPlugInRegisterFactoryFunctionByName(CFUUIDRef factoryUUID, CFPlugInRef plugIn, CFStringRef functionName)
{
	WsbsdPlugInInfo *p = InfoFor(plugIn); if (!p || !LoadPlugIn(p)) return false;
	void *f = dlsym(p->handle, [(__bridge NSString *)functionName UTF8String]); if (!f) return false;
	return CFPlugInRegisterFactoryFunction(factoryUUID, (CFPlugInFactoryFunction)f);
}
Boolean CFPlugInUnregisterFactory(CFUUIDRef factoryUUID) { Init(); [gLock lock]; [gFactories removeObjectForKey: UUIDKey(factoryUUID)]; [gLock unlock]; return true; }

void *CFPlugInInstanceCreate(CFAllocatorRef allocator, CFUUIDRef factoryUUID, CFUUIDRef typeUUID)
{
	Init(); NSString *key = UUIDKey(factoryUUID); [gLock lock];
	NSValue *fv = gFactories[key]; WsbsdPlugInInfo *p = gFactoryPlugIn[key]; [gLock unlock];
	if (!fv && p && LoadPlugIn(p)) {                                                          /* the function the Info.plist names for this factory */
		NSString *name = p->info[@"CFPlugInFactories"][key]; void *f = name ? dlsym(p->handle, [name UTF8String]) : NULL;
		if (f) { [gLock lock]; gFactories[key] = fv = [NSValue valueWithPointer: f]; [gLock unlock]; }
	}
	if (!fv) return NULL;
	CFPlugInFactoryFunction fn = (CFPlugInFactoryFunction)[fv pointerValue]; return fn(allocator, typeUUID);
}
void CFPlugInAddInstanceForFactory(CFUUIDRef factoryID) { Init(); NSString *k = UUIDKey(factoryID); [gLock lock]; gInstances[k] = @([gInstances[k] integerValue] + 1); [gLock unlock]; }
void CFPlugInRemoveInstanceForFactory(CFUUIDRef factoryID) { Init(); NSString *k = UUIDKey(factoryID); [gLock lock]; gInstances[k] = @(MAX(0, [gInstances[k] integerValue] - 1)); [gLock unlock]; }
