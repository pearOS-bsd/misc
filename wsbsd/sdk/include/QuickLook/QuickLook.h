/* QuickLook: the preview panel is Quartz.h's (it never previews anything); thumbnails are not generated */
#ifndef WSBSD_QUICKLOOK_H
#define WSBSD_QUICKLOOK_H
#import <Quartz/Quartz.h>
CGImageRef QLThumbnailImageCreate(CFAllocatorRef allocator, CFURLRef url, CGSize maxThumbnailSize, CFDictionaryRef options);
#endif
