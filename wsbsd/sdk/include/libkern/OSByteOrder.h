/* <libkern/OSByteOrder.h> for the wsbsd SDK */
#ifndef WSBSD_OSBYTEORDER_H
#define WSBSD_OSBYTEORDER_H
#include <stdint.h>
#define OSSwapInt16(x) __builtin_bswap16(x)
#define OSSwapInt32(x) __builtin_bswap32(x)
#define OSSwapInt64(x) __builtin_bswap64(x)
#define OSSwapBigToHostInt16(x) __builtin_bswap16(x)
#define OSSwapBigToHostInt32(x) __builtin_bswap32(x)
#define OSSwapBigToHostInt64(x) __builtin_bswap64(x)
#define OSSwapHostToBigInt16(x) __builtin_bswap16(x)
#define OSSwapHostToBigInt32(x) __builtin_bswap32(x)
#define OSSwapHostToBigInt64(x) __builtin_bswap64(x)
#define OSSwapLittleToHostInt16(x) (x)
#define OSSwapLittleToHostInt32(x) (x)
#define OSSwapLittleToHostInt64(x) (x)
#define OSSwapHostToLittleInt16(x) (x)
#define OSSwapHostToLittleInt32(x) (x)
#define OSSwapHostToLittleInt64(x) (x)
#endif
