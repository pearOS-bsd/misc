/* the Core Graphics object kinds, for the tests (type ids on macOS, the classes of Opal elsewhere) */
#ifndef CACOMPAT_H
#define CACOMPAT_H
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#ifdef __APPLE__
static inline BOOL CAIsColor(id v) { return v && CFGetTypeID((__bridge CFTypeRef)v) == CGColorGetTypeID(); }
#else
static inline BOOL CAIsColor(id v) { Class c = objc_lookUpClass("CGColor"); return v && c && [v isKindOfClass:c]; }
#endif
#endif
