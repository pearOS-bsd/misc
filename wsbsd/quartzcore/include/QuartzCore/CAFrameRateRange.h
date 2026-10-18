/* <QuartzCore/CAFrameRateRange.h> */
#ifndef WSBSD_CAFRAMERATERANGE_H
#define WSBSD_CAFRAMERATERANGE_H
#import <QuartzCore/CABase.h>
struct CAFrameRateRange { float minimum; float maximum; float preferred; };
typedef struct CAFrameRateRange CAFrameRateRange;
CA_EXTERN_C_BEGIN
CA_EXTERN const CAFrameRateRange CAFrameRateRangeDefault;
CA_EXTERN CAFrameRateRange CAFrameRateRangeMake(float minimum, float maximum, float preferred);
CA_EXTERN bool CAFrameRateRangeIsEqualToRange(CAFrameRateRange range, CAFrameRateRange other);
CA_EXTERN_C_END
#endif
