/* Gestalt: the version of the system and a few capabilities; the system version answers as macOS 10.16 (what Apple's compatibility mode reports), implemented in sdk/src/CoreServicesMisc.c */
#ifndef WSBSD_GESTALT_H
#define WSBSD_GESTALT_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef int32_t OSErr_wsbsd;
typedef uint32_t OSType_wsbsd;
enum { gestaltSystemVersion = 0x73797376, gestaltSystemVersionMajor = 0x73797331, gestaltSystemVersionMinor = 0x73797332, gestaltSystemVersionBugFix = 0x73797333,
       gestaltPhysicalRAMSize = 0x72616d20, gestaltProcessorCount = 0x6e707573 };
int16_t Gestalt(uint32_t selector, int32_t *response);
#ifdef __cplusplus
}
#endif
#endif
