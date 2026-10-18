/* <QuartzCore/CABase.h>: shared definitions of the Core Animation headers. */
#ifndef WSBSD_CABASE_H
#define WSBSD_CABASE_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <float.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
# define CA_EXTERN_C_BEGIN extern "C" {
# define CA_EXTERN_C_END   }
#else
# define CA_EXTERN_C_BEGIN
# define CA_EXTERN_C_END
#endif
#ifndef CA_EXTERN
# define CA_EXTERN extern __attribute__((visibility("default")))
#endif
#ifndef CA_INLINE
# define CA_INLINE static inline
#endif
#ifndef NS_TYPED_ENUM
# define NS_TYPED_ENUM
#endif
#ifndef NS_TYPED_EXTENSIBLE_ENUM
# define NS_TYPED_EXTENSIBLE_ENUM
#endif

CA_EXTERN_C_BEGIN
/* the current time of the media timebase, in seconds (a monotonic clock) */
CA_EXTERN CFTimeInterval CACurrentMediaTime(void);
CA_EXTERN_C_END
#endif
