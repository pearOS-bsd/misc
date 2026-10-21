/* <Foundation/Foundation.h>: GNUstep's, followed by NSURLSession when this GNUstep base was built without it (the FreeBSD package is: GS_HAVE_NSURLSESSION is 0; wsbsd/NSURLSession.h, sdk/src/NSURLSession.m, libcurl). */
#include_next <Foundation/Foundation.h>
#if !GS_HAVE_NSURLSESSION
#import <wsbsd/NSURLSession.h>
#endif
