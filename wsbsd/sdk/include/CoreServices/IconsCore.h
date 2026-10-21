/* Icon Services: IconRef for the system icons an application asks for by type (GetIconRef with a creator and a type code) and -[NSImage initWithIconRef:]. The images come from the symbol set. */
#ifndef WSBSD_ICONSCORE_H
#define WSBSD_ICONSCORE_H
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct OpaqueIconRef *IconRef;
typedef int16_t SInt16_wsbsd;
enum { kOnSystemDisk = -32768 };
enum { kSystemIconsCreator = 'macs', kAliasBadgeIcon = 'abdg', kLockedBadgeIcon = 'lbdg', kGenericDocumentIcon = 'docu', kToolbarFavoritesIcon = 'tfav' };      /* kGenericFolderIcon and kGenericApplicationIcon are in CoreServices.h */
OSStatus GetIconRef(int16_t vRefNum, OSType creator, OSType iconType, IconRef *theIconRef);
OSStatus ReleaseIconRef(IconRef theIconRef);
#ifdef __cplusplus
}
#endif
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>
@interface NSImage (WsbsdIconRef)
- (instancetype)initWithIconRef:(IconRef)iconRef;
@end
#endif
#endif
