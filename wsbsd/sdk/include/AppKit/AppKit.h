/* <AppKit/AppKit.h>: GNUstep's, followed by the modern AppKit names and methods the stack adds (wsbsd/AppKitCompat.h). */
/* NSCollectionViewFlowLayout is the only GNUstep header that declares -itemSize (as NSSize); a program with its own -itemSize returning something else (GrandPerspective's file item
 * size) sent it to an `id` and the compiler took the NSSize declaration. The two accessors are renamed while GNUstep's headers are read; code that needs the flow layout's item size
 * has to go through the new names. */
/* likewise +sharedDocumentController is declared returning id, and dot syntax on its result (NSDocumentController.sharedDocumentController.recentDocumentURLs) needs the class property
 * that Apple declares; the property is declared with the right type in wsbsd/AppKitCompat.h, the method itself is GNUstep's. */
#define sharedDocumentController wsbsd_gsSharedDocumentController
#define itemSize wsbsd_flowLayoutItemSize
#define setItemSize wsbsd_setFlowLayoutItemSize
#include_next <AppKit/AppKit.h>
#undef sharedDocumentController
#undef itemSize
#undef setItemSize
#import <wsbsd/AppKitCompat.h>
#if !defined(__APPLE__)
#include <Security/Security.h>
#endif
