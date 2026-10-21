/* Launch Services, Spotlight and the Process Manager as far as a system without them can answer: nothing is known, the calls say so. */
#include <CoreServices/CoreServices.h>
CFArrayRef LSCopyApplicationURLsForURL(CFURLRef inURL, LSRolesMask inRoleMask) { (void)inURL; (void)inRoleMask; return CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks); }
CFURLRef LSCopyDefaultApplicationURLForURL(CFURLRef inURL, LSRolesMask inRoleMask, CFErrorRef *outError) { (void)inURL; (void)inRoleMask; if (outError) *outError = NULL; return NULL; }
MDItemRef MDItemCreateWithURL(CFAllocatorRef allocator, CFURLRef url) { (void)allocator; (void)url; return NULL; }
MDItemRef MDItemCreate(CFAllocatorRef allocator, CFStringRef path) { (void)allocator; (void)path; return NULL; }
CFTypeRef MDItemCopyAttribute(MDItemRef item, CFStringRef name) { (void)item; (void)name; return NULL; }
CFDictionaryRef MDItemCopyAttributes(MDItemRef item, CFArrayRef names) { (void)item; (void)names; return NULL; }
OSStatus GetProcessForPID(pid_t pid, ProcessSerialNumber *psn) { (void)pid; if (psn) psn->highLongOfPSN = psn->lowLongOfPSN = 0; return procNotFound; }
OSStatus CopyProcessName(const ProcessSerialNumber *psn, CFStringRef *name) { (void)psn; if (name) *name = NULL; return paramErr; }

/* AudioToolbox: the alert sound is the bell of the terminal this process was started from (no sound server) */
#include <unistd.h>
void AudioServicesPlayAlertSound(uint32_t id) { (void)id; if (write(2, "\a", 1) < 0) { } }
void AudioServicesPlaySystemSound(uint32_t id) { AudioServicesPlayAlertSound(id); }
