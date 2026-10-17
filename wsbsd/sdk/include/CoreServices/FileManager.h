/* The Carbon File Manager subset applications use to walk a directory tree: FSRef, FSCatalogInfo, FSIterator and the bulk catalog call (sdk/src/FileManager.c, over POSIX).
 * An FSRef holds the absolute path (80 bytes, as on Apple where it is opaque). */
#ifndef WSBSD_FILEMANAGER_H
#define WSBSD_FILEMANAGER_H
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#ifndef __APPLE__
#ifdef __cplusplus
extern "C" {
#endif
typedef int32_t FSVolumeRefNum; typedef uint32_t TextEncoding;          /* UInt8 ... UInt64 are CoreFoundation's */
#ifndef ULONG_LONG_MAX
#define ULONG_LONG_MAX 0xffffffffffffffffULL
#endif
typedef struct FSRef { UInt8 hidden[80]; } FSRef;
typedef struct HFSUniStr255 { UInt16 length; UniChar unicode[255]; } HFSUniStr255;
typedef struct UTCDateTime { UInt16 highSeconds; UInt32 lowSeconds; UInt16 fraction; } UTCDateTime;
typedef struct FSCatalogInfo {
	UInt16 nodeFlags; FSVolumeRefNum volume; UInt32 parentDirID, nodeID; UInt8 sharingFlags, userPrivileges, reserved1, reserved2;
	UTCDateTime createDate, contentModDate, attributeModDate, accessDate, backupDate;
	UInt32 permissions[4]; UInt8 finderInfo[16], extFinderInfo[16];
	UInt64 dataLogicalSize, dataPhysicalSize, rsrcLogicalSize, rsrcPhysicalSize; UInt32 valence; TextEncoding textEncodingHint;
} FSCatalogInfo;
typedef struct OpaqueFSIterator *FSIterator;
typedef UInt32 FSCatalogInfoBitmap, FSIteratorFlags; typedef UInt32 ItemCount;
enum { kFSCatInfoNone = 0, kFSCatInfoTextEncoding = 0x1, kFSCatInfoNodeFlags = 0x2, kFSCatInfoVolume = 0x4, kFSCatInfoParentDirID = 0x8, kFSCatInfoNodeID = 0x10, kFSCatInfoCreateDate = 0x20,
       kFSCatInfoContentMod = 0x40, kFSCatInfoAttrMod = 0x80, kFSCatInfoAccessDate = 0x100, kFSCatInfoBackupDate = 0x200, kFSCatInfoPermissions = 0x400, kFSCatInfoFinderInfo = 0x800,
       kFSCatInfoFinderXInfo = 0x1000, kFSCatInfoValence = 0x2000, kFSCatInfoDataSizes = 0x4000, kFSCatInfoRsrcSizes = 0x8000, kFSCatInfoSharingFlags = 0x10000, kFSCatInfoUserPrivs = 0x20000 };
enum { kFSNodeLockedMask = 0x1, kFSNodeResOpenMask = 0x4, kFSNodeDataOpenMask = 0x8, kFSNodeIsDirectoryMask = 0x10, kFSNodeCopyProtectMask = 0x40, kFSNodeForkOpenMask = 0x80, kFSNodeInSharedMask = 0x100, kFSNodeHardLinkMask = 0x200 };
enum { kFSIterateFlat = 0, kFSIterateSubtree = 1 };
enum { errFSNoMoreItems = -1417, errFSBadFSRef = -1401, nsvErr = -35, ioErr = -36, afpAccessDenied = -5000, dirNFErr = -120 };
OSStatus FSPathMakeRef(const UInt8 *path, FSRef *ref, Boolean *isDirectory);
OSStatus FSRefMakePath(const FSRef *ref, UInt8 *path, UInt32 maxPathSize);
OSStatus FSGetCatalogInfo(const FSRef *ref, FSCatalogInfoBitmap whichInfo, FSCatalogInfo *catalogInfo, HFSUniStr255 *outName, void *fsSpec, FSRef *parentRef);
OSStatus FSOpenIterator(const FSRef *container, FSIteratorFlags iteratorFlags, FSIterator *iterator);
OSStatus FSCloseIterator(FSIterator iterator);
OSStatus FSGetCatalogInfoBulk(FSIterator iterator, ItemCount maximumObjects, ItemCount *actualObjects, Boolean *containerChanged, FSCatalogInfoBitmap whichInfo, FSCatalogInfo *catalogInfos, FSRef *refs, void *specs, HFSUniStr255 *names);
OSStatus FSGetVolumeInfo(FSVolumeRefNum volume, ItemCount volumeIndex, FSVolumeRefNum *actualVolume, UInt32 whichInfo, void *info, HFSUniStr255 *volumeName, FSRef *rootDirectory);
#ifdef __cplusplus
}
#endif
#endif
#endif
