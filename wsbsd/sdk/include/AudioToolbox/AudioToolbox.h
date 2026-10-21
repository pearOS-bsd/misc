/* System sounds of AudioToolbox: the alert sound is the terminal bell of the controlling terminal (there is no sound server); implemented in sdk/src/CoreServicesMisc.c */
#ifndef WSBSD_AUDIOTOOLBOX_H
#define WSBSD_AUDIOTOOLBOX_H
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef uint32_t SystemSoundID;
#define kSystemSoundID_UserPreferredAlert 0x00001000
#define kSystemSoundID_FlashScreen 0x00000FFE
OSStatus AudioServicesCreateSystemSoundID(CFURLRef inFileURL, SystemSoundID *outSystemSoundID);
OSStatus AudioServicesDisposeSystemSoundID(SystemSoundID inSystemSoundID);
void AudioServicesPlayAlertSound(SystemSoundID id);
void AudioServicesPlaySystemSound(SystemSoundID id);
#ifdef __cplusplus
}
#endif
#endif
