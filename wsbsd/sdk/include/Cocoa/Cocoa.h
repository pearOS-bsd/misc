/* <Cocoa/Cocoa.h>: GNUstep's, followed by the modern AppKit names and methods the stack adds (wsbsd/AppKitCompat.h). */
#include_next <Cocoa/Cocoa.h>
#if __has_include(<CoreGraphics/CoreGraphics.h>)
#import <CoreGraphics/CoreGraphics.h>
#endif
#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>
#endif
#import <wsbsd/CGEvent.h>
#import <wsbsd/AppKitCompat.h>
#import <wsbsd/AppKitCompat3.h>
#if !GS_HAVE_NSURLSESSION
#import <wsbsd/NSURLSession.h>
#endif
