/* The icons of NSWorkspace as the Mac chooses them: an application's own icon, the folder icon, and for any other item the icon of its type: the declaration of the type (or the first type it conforms to that has one) names an
 * .icns file of CoreTypes.bundle; the generic document icon is the fallback. The files are the Mac's own and live at /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources (imported when the image is built). */
#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>
#import <objc/runtime.h>
#import "LSIcon.h"
#include "icns.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *TypesDir(void) { const char *e = getenv("WSBSD_CORETYPES"); return e ? @(e) : @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources"; }
static NSString *IconFileForUTI(NSString *uti, int depth)
{
	if (depth > 12 || !uti) return nil; CFDictionaryRef d = UTTypeCopyDeclaration((__bridge CFStringRef)uti); if (!d) return nil; NSDictionary *decl = (__bridge_transfer NSDictionary *)d;
	NSString *f = decl[@"UTTypeIconFile"]; if ([f length] && [[NSFileManager defaultManager] fileExistsAtPath: [TypesDir() stringByAppendingPathComponent: f]]) return f;
	for (NSString *p in decl[@"UTTypeConformsTo"]) { NSString *r = IconFileForUTI(p, depth + 1); if (r) return r; }
	return nil;
}
static NSImage *ImageFromICNS(NSString *path, CGFloat pt)
{
	NSData *d = [NSData dataWithContentsOfFile: path]; if (!d) return nil; IcnsPick p; if (!icns_pick([d bytes], [d length], (int)(pt * 2), &p)) return nil; NSBitmapImageRep *rep = nil;
	if (p.png) rep = [NSBitmapImageRep imageRepWithData: [NSData dataWithBytes: p.png length: p.png_len]];
	else if (p.rgba) { rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: p.px pixelsHigh: p.px bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: p.px * 4 bitsPerPixel: 32]; memcpy([rep bitmapData], p.rgba, (size_t)p.px * p.px * 4); free(p.rgba); }
	if (!rep) return nil; NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(pt, pt)]; [rep setSize: NSMakeSize(pt, pt)]; [img addRepresentation: rep]; return img;
}
static NSString *UTIForPath(NSString *path)
{
	BOOL dir = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &dir]; NSString *ext = [path pathExtension];
	if (dir) { if ([ext length]) { NSString *u = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL); if (u && ![u hasPrefix: @"dyn."]) return u; } return @"public.folder"; }
	if ([ext length]) { NSString *u = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL); if (u && ![u hasPrefix: @"dyn."]) return u; }
	return @"public.data";
}
NSImage *WsbsdIconForPath(NSString *path)
{
	NSString *uti = UTIForPath(path); BOOL dir = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &dir];
	if ([[path pathExtension] isEqual: @"app"] && dir) { NSString *f = LSBundleIconPath(path); NSImage *i = f ? ImageFromICNS(f, 128) : nil; if (i) return i; return ImageFromICNS([TypesDir() stringByAppendingPathComponent: @"GenericApplicationIcon.icns"], 128); }
	NSString *file = IconFileForUTI(uti, 0); if (!file) file = dir ? @"GenericFolderIcon.icns" : @"GenericDocumentIcon.icns";
	return ImageFromICNS([TypesDir() stringByAppendingPathComponent: file], 128);
}
NSImage *WsbsdIconForUTI(NSString *uti) { NSString *file = IconFileForUTI(uti, 0) ?: @"GenericDocumentIcon.icns"; return ImageFromICNS([TypesDir() stringByAppendingPathComponent: file], 128); }

static IMP origIconForFile, origIconForFileType;
static id NewIconForFile(id self, SEL _cmd, NSString *path) { NSImage *i = path ? WsbsdIconForPath(path) : nil; return i ?: ((id (*)(id, SEL, id))origIconForFile)(self, _cmd, path); }
static id NewIconForFileType(id self, SEL _cmd, NSString *type)
{
	NSString *uti = nil; if ([type hasPrefix: @"."]) type = [type substringFromIndex: 1];
	if ([type length] && ![type containsString: @"."]) uti = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)type, NULL); else uti = type;
	NSImage *i = [uti length] && ![uti hasPrefix: @"dyn."] ? WsbsdIconForUTI(uti) : nil; return i ?: ((id (*)(id, SEL, id))origIconForFileType)(self, _cmd, type);
}
@interface WsbsdWorkspaceIcons : NSObject @end
@implementation WsbsdWorkspaceIcons
+ (void)load
{
	Class c = objc_getClass("NSWorkspace"); Method m;
	if ((m = class_getInstanceMethod(c, @selector(iconForFile:)))) { origIconForFile = method_getImplementation(m); method_setImplementation(m, (IMP)NewIconForFile); }
	if ((m = class_getInstanceMethod(c, @selector(iconForFileType:)))) { origIconForFileType = method_getImplementation(m); method_setImplementation(m, (IMP)NewIconForFileType); }
}
@end
