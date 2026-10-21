/* The Resource Manager: files here have no resource forks; opening one reports that there is none (ResFileRefNum 0), so no resource is ever returned. Implemented in sdk/src/CoreServicesMisc.c */
#ifndef WSBSD_RESOURCEMANAGER_H
#define WSBSD_RESOURCEMANAGER_H
#include <stdint.h>
#include <CoreServices/CoreServices.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef uint32_t ResType;
typedef int16_t ResID, ResFileRefNum;
typedef char **Handle;
enum { fsRdPerm = 1, kFSPathMakeRefDoNotFollowLeafSymlink = 1 };
ResFileRefNum FSOpenResFile(const FSRef *ref, int8_t permission);
void CloseResFile(ResFileRefNum refNum);
Handle Get1Resource(ResType theType, ResID theID);
void HLock(Handle h);
void HUnlock(Handle h);
long GetHandleSize(Handle h);
void ReleaseResource(Handle h);
int32_t FSPathMakeRefWithOptions(const uint8_t *path, uint32_t options, FSRef *ref, Boolean *isDirectory);
#ifdef __cplusplus
}
#endif
#endif
