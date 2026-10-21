/* CFPreferences over NSUserDefaults: the current application's domain is the standard defaults, another application id is a persistent domain of that name (sdk/src/AppKitCompat2.m) */
#ifndef WSBSD_CFPREFERENCES_H
#define WSBSD_CFPREFERENCES_H
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
extern const CFStringRef kCFPreferencesAnyApplication, kCFPreferencesCurrentApplication, kCFPreferencesAnyHost, kCFPreferencesCurrentHost, kCFPreferencesAnyUser, kCFPreferencesCurrentUser;
CFPropertyListRef CFPreferencesCopyAppValue(CFStringRef key, CFStringRef applicationID);
Boolean CFPreferencesGetAppBooleanValue(CFStringRef key, CFStringRef applicationID, Boolean *keyExistsAndHasValidFormat);
CFIndex CFPreferencesGetAppIntegerValue(CFStringRef key, CFStringRef applicationID, Boolean *keyExistsAndHasValidFormat);
void CFPreferencesSetAppValue(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID);
Boolean CFPreferencesAppSynchronize(CFStringRef applicationID);
CFPropertyListRef CFPreferencesCopyValue(CFStringRef key, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
void CFPreferencesSetValue(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
Boolean CFPreferencesSynchronize(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CFArrayRef CFPreferencesCopyKeyList(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
#ifdef __cplusplus
}
#endif
#endif
