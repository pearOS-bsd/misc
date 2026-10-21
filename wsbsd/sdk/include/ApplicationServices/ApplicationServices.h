/* <ApplicationServices/ApplicationServices.h>: Core Graphics, Core Text, Core Services and the event types of this stack. */
#ifndef WSBSD_APPLICATIONSERVICES_H
#define WSBSD_APPLICATIONSERVICES_H
#include <CoreServices/CoreServices.h>
#include <CoreGraphics/CoreGraphics.h>
#if __has_include(<CoreText/CoreText.h>)
#include <CoreText/CoreText.h>
#endif
#include <wsbsd/CGEvent.h>
/* UniversalAccess: the screen magnifier is not there */
#ifdef __cplusplus
extern "C" {
#endif
enum { kUAZoomFocusTypeOther = 0, kUAZoomFocusTypeInsertionPoint = 1 };
typedef int UAZoomFocusType;
static inline Boolean UAZoomEnabled(void) { return false; }
static inline OSStatus UAZoomChangeFocus(const CGRect *viewRect, const CGRect *selectedRect, UAZoomFocusType type) { (void)viewRect; (void)selectedRect; (void)type; return 0; }
#ifdef __cplusplus
}
#endif
#endif
