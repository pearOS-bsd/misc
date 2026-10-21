/* CoreText spellings of the macOS 10.8+ SDK over the names Opal's CoreText declares */
#ifndef WSBSD_CORETEXTNAMES_H
#define WSBSD_CORETEXTNAMES_H
#include <CoreText/CoreText.h>
#ifndef kCTTextAlignmentLeft
#define kCTTextAlignmentLeft kCTLeftTextAlignment
#define kCTTextAlignmentRight kCTRightTextAlignment
#define kCTTextAlignmentCenter kCTCenterTextAlignment
#define kCTTextAlignmentJustified kCTJustifiedTextAlignment
#define kCTTextAlignmentNatural kCTNaturalTextAlignment
#endif
#endif
