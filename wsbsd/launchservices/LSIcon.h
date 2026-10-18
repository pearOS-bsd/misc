/* Icons the way LaunchServices / IconServices hand them out: the icon of an application bundle (its .icns), of a folder, of a file by type. Used by the Dock, the Finder-like clients and NSWorkspace. */
#ifndef WSBSD_LSICON_H
#define WSBSD_LSICON_H
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>

/* a square icon image of px x px pixels for the file or folder at path (follows application bundles' CFBundleIconFile); returns a +1 reference, never NULL for an existing path */
CGImageRef LSIconCreateForPath(NSString *path, int px);
/* the same for a filename extension or "folder" / "app" / "doc": the generic icons */
CGImageRef LSIconCreateForKind(NSString *kind, int px);
/* decodes the .icns file at path at the size that fits px best; NULL when not usable */
CGImageRef LSIconCreateFromICNS(NSString *path, int px);
/* the kind used for a path's extension: "doc", "zip", "bin", "dmg", "text", "image", "audio", "video", "pdf", "code", "sheet", "folder", "app" */
NSString *LSKindForPath(NSString *path);
#endif
