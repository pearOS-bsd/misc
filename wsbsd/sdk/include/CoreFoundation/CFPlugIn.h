/* CFPlugIn: bundles with a CFPlugInFactories / CFPlugInTypes table in their Info.plist, loaded with dlopen (sdk/src/CFPlugIn.m) */
#ifndef WSBSD_CFPLUGIN_H
#define WSBSD_CFPLUGIN_H
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef CFBundleRef CFPlugInRef;
typedef void *(*CFPlugInFactoryFunction)(CFAllocatorRef allocator, CFUUIDRef typeUUID);
CFPlugInRef CFPlugInCreate(CFAllocatorRef allocator, CFURLRef plugInURL);
CFBundleRef CFPlugInGetBundle(CFPlugInRef plugIn);
CFArrayRef CFPlugInFindFactoriesForPlugInTypeInPlugIn(CFUUIDRef typeUUID, CFPlugInRef plugIn);
void *CFPlugInInstanceCreate(CFAllocatorRef allocator, CFUUIDRef factoryUUID, CFUUIDRef typeUUID);
Boolean CFPlugInRegisterFactoryFunction(CFUUIDRef factoryUUID, CFPlugInFactoryFunction func);
Boolean CFPlugInRegisterFactoryFunctionByName(CFUUIDRef factoryUUID, CFPlugInRef plugIn, CFStringRef functionName);
Boolean CFPlugInUnregisterFactory(CFUUIDRef factoryUUID);
void CFPlugInAddInstanceForFactory(CFUUIDRef factoryID);
void CFPlugInRemoveInstanceForFactory(CFUUIDRef factoryID);
#ifdef __cplusplus
}
#endif
#endif
