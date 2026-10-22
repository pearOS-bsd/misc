/* String constants of the system frameworks the shims stand in for. Static NSString literals (toll-free with CFString), compiled WITHOUT ARC, so they need no code to run
 * before main(): GNUstep captures the process arguments in its own main(), and creating a CFString in a constructor would run before it. Deliberately includes none of
 * the shim headers: those declare some of the names const (Apple's way) and others not. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#define CFS(x) ((CFStringRef)@x)
/* ServiceManagement */
CFStringRef kSMDomainSystemLaunchd = CFS("com.apple.ServiceManagement.systemdomain");
CFStringRef kSMDomainUserLaunchd = CFS("com.apple.ServiceManagement.userdomain");
CFStringRef kSMRightBlessPrivilegedHelper = CFS("com.apple.ServiceManagement.blesshelper");
CFStringRef kSMRightModifySystemDaemons = CFS("com.apple.ServiceManagement.daemons.modify");
/* DiskArbitration (const, as in Apple's header) */
const CFStringRef kDADiskDescriptionVolumeNameKey = CFS("DAVolumeName");
const CFStringRef kDADiskDescriptionVolumeNetworkKey = CFS("DAVolumeNetwork");
const CFStringRef kDADiskDescriptionMediaNameKey = CFS("DAMediaName");
const CFStringRef kDADiskDescriptionMediaWholeKey = CFS("DAMediaWhole");
const CFStringRef kDADiskDescriptionMediaBSDNameKey = CFS("DAMediaBSDName");
const CFStringRef kDADiskDescriptionBusNameKey = CFS("DABusName");
const CFStringRef kDADiskDescriptionMediaSizeKey = CFS("DAMediaSize");
const CFStringRef kDADiskDescriptionMediaWritableKey = CFS("DAMediaWritable");
const CFStringRef kDADiskDescriptionVolumePathKey = CFS("DAVolumePath");
const CFStringRef kDADiskDescriptionDeviceModelKey = CFS("DADeviceModel");
/* uniform type identifiers */
const CFStringRef kUTTagClassFilenameExtension = CFS("public.filename-extension");
const CFStringRef kUTTagClassOSType = CFS("com.apple.ostype");
const CFStringRef kUTTagClassNSPboardType = CFS("com.apple.nspboard-type");
const CFStringRef kUTTagClassMIMEType = CFS("public.mime-type");
const CFStringRef kUTTypeData = CFS("public.data");
const CFStringRef kUTTypeItem = CFS("public.item");
const CFStringRef kUTTypeContent = CFS("public.content");
const CFStringRef kUTTypePlainText = CFS("public.plain-text");
const CFStringRef kUTTypeText = CFS("public.text");
const CFStringRef kUTTypeApplicationBundle = CFS("com.apple.application-bundle");
const CFStringRef kUTTypeDescriptionKey = CFS("UTTypeDescription");
const CFStringRef kUTTypeConformsToKey = CFS("UTTypeConformsTo");
const CFStringRef kUTTypeIdentifierKey = CFS("UTTypeIdentifier");
const CFStringRef kUTTypeTagSpecificationKey = CFS("UTTypeTagSpecification");
const CFStringRef kUTTypeFolder = CFS("public.folder");
const CFStringRef kUTTypeDirectory = CFS("public.directory");
const CFStringRef kUTTypeBundle = CFS("com.apple.bundle");

#import <QuartzCore/QuartzCore.h>
NSString *const kCAMediaTimingFunctionLinear = @"linear", *const kCAMediaTimingFunctionEaseIn = @"easeIn", *const kCAMediaTimingFunctionEaseOut = @"easeOut", *const kCAMediaTimingFunctionEaseInEaseOut = @"easeInEaseOut", *const kCAMediaTimingFunctionDefault = @"default";
const CFStringRef kSecCodeInfoEntitlementsDict = CFS("entitlements-dict"), kSecCodeInfoEntitlements = CFS("entitlements"), kSecCodeInfoIdentifier = CFS("identifier");
/* Spotlight attribute names */
CFStringRef kMDItemContentType = CFS("kMDItemContentType"), kMDItemDisplayName = CFS("kMDItemDisplayName"), kMDItemKind = CFS("kMDItemKind"), kMDItemFSSize = CFS("kMDItemFSSize"),
	kMDItemLastUsedDate = CFS("kMDItemLastUsedDate"), kMDItemContentTypeTree = CFS("kMDItemContentTypeTree");
NSString *NSWorkspaceDidRenameVolumeNotification = @"NSWorkspaceDidRenameVolumeNotification";
/* QuickLook */
const CFStringRef kQLPreviewPropertyDisplayNameKey = CFS("DisplayName");
const CFStringRef kQLPreviewPropertyWidthKey = CFS("Width");
const CFStringRef kQLPreviewPropertyHeightKey = CFS("Height");
const CFStringRef kQLPreviewPropertyMIMETypeKey = CFS("MIMEType");
const CFStringRef kQLPreviewPropertyTextEncodingNameKey = CFS("TextEncodingName");
const CFStringRef kQLPreviewPropertyBackgroundColorKey = CFS("BackgroundColor");
const CFStringRef kQLThumbnailPropertyExtensionKey = CFS("Extension");
const CFStringRef kQLThumbnailPropertyBadgeImageKey = CFS("BadgeImage");
/* more uniform type identifiers */
const CFStringRef kUTTypeRTF = CFS("public.rtf");
const CFStringRef kUTTypeHTML = CFS("public.html");
const CFStringRef kUTTypeXML = CFS("public.xml");
const CFStringRef kUTTypeImage = CFS("public.image");
const CFStringRef kUTTypePNG = CFS("public.png");
const CFStringRef kUTTypeJPEG = CFS("public.jpeg");
const CFStringRef kUTTypeGIF = CFS("com.compuserve.gif");
const CFStringRef kUTTypeTIFF = CFS("public.tiff");
const CFStringRef kUTTypePDF = CFS("com.adobe.pdf");
const CFStringRef kUTTypeSourceCode = CFS("public.source-code");
const CFStringRef kUTTypeUTF8PlainText = CFS("public.utf8-plain-text");
const CFStringRef kUTTypeURL = CFS("public.url");
/* NSImage names */
NSString *const NSImageNameStatusAvailable = @"NSStatusAvailable";
NSString *const NSImageNameStatusUnavailable = @"NSStatusUnavailable";
NSString *const NSImageNameStatusPartiallyAvailable = @"NSStatusPartiallyAvailable";
NSString *const NSImageNameStatusNone = @"NSStatusNone";
