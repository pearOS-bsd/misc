/* Date conversions of CoreServices (UCConvert...): the uniform type identifiers are in UTI.m. */
#include <CoreFoundation/CoreFoundation.h>
#define MAC_EPOCH_TO_CF 3061152000.0
int32_t UCConvertSecondsToCFAbsoluteTime(uint32_t seconds, CFAbsoluteTime *t) { if (t) *t = (CFAbsoluteTime)seconds - MAC_EPOCH_TO_CF; return 0; }
#include <CoreServices/CoreServices.h>
OSStatus UCConvertUTCDateTimeToCFAbsoluteTime(const UTCDateTime *d, CFAbsoluteTime *t)
{
	if (!d || !t) return -50;
	double s = ((double)(((uint64_t)d->highSeconds << 32) | d->lowSeconds)) + d->fraction / 65536.0;
	*t = s - MAC_EPOCH_TO_CF; return 0;
}
OSStatus UCConvertCFAbsoluteTimeToUTCDateTime(CFAbsoluteTime t, UTCDateTime *d)
{
	if (!d) return -50;
	double s = t + MAC_EPOCH_TO_CF; if (s < 0) s = 0;
	uint64_t whole = (uint64_t)s; d->highSeconds = (UInt16)(whole >> 32); d->lowSeconds = (UInt32)whole; d->fraction = (UInt16)((s - (double)whole) * 65536.0); return 0;
}
int32_t UCConvertCFAbsoluteTimeToSeconds(CFAbsoluteTime t, uint32_t *seconds) { double s = t + MAC_EPOCH_TO_CF; if (seconds) *seconds = s < 0 ? 0 : (uint32_t)s; return 0; }
