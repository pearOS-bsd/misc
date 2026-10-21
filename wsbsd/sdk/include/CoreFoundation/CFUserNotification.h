/* CFUserNotification: a modal alert (NSAlert); implemented in sdk/src/AppKitCompat2.m */
#ifndef WSBSD_CFUSERNOTIFICATION_H
#define WSBSD_CFUSERNOTIFICATION_H
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
enum { kCFUserNotificationStopAlertLevel = 0, kCFUserNotificationNoteAlertLevel = 1, kCFUserNotificationCautionAlertLevel = 2, kCFUserNotificationPlainAlertLevel = 3 };
enum { kCFUserNotificationDefaultResponse = 0, kCFUserNotificationAlternateResponse = 1, kCFUserNotificationOtherResponse = 2, kCFUserNotificationCancelResponse = 3 };
int32_t CFUserNotificationDisplayAlert(CFTimeInterval timeout, CFOptionFlags flags, CFURLRef iconURL, CFURLRef soundURL, CFURLRef localizationURL, CFStringRef alertHeader, CFStringRef alertMessage,
                                       CFStringRef defaultButtonTitle, CFStringRef alternateButtonTitle, CFStringRef otherButtonTitle, CFOptionFlags *responseFlags);
#ifdef __cplusplus
}
#endif
#endif
