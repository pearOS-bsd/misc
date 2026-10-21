/* AppleEvents: the types and constants applications name (descriptors, four-character codes); there is no event dispatch between processes, the descriptor calls fail with errAEEventNotHandled */
#ifndef WSBSD_APPLEEVENTS_H
#define WSBSD_APPLEEVENTS_H
#include <stdint.h>
#include <stddef.h>
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef uint32_t DescType;
typedef uint32_t AEKeyword;
typedef struct OpaqueAEDataStorage *AEDataStorage;
typedef struct AEDesc { DescType descriptorType; AEDataStorage dataHandle; } AEDesc;
typedef AEDesc AEAddressDesc, AEDescList, AERecord, AppleEvent;
typedef AppleEvent *AppleEventPtr;
enum { typeNull = 0x6e756c6c, typeChar = 0x54455854, typeUTF8Text = 0x75746638, typeUnicodeText = 0x75743136, typeSInt32 = 0x6c6f6e67, typeBoolean = 0x626f6f6c, typeAEList = 0x6c697374,
       typeAERecord = 0x7265636f, typeObjectSpecifier = 0x6f626a20, typeFileURL = 0x6675726c, typeProcessSerialNumber = 0x70736e20, typeApplicationBundleID = 0x62756e64 };
enum { kAEOpenApplication = 0x6f617070, kAEOpenDocuments = 0x6f646f63, kAEQuitApplication = 0x71756974, kAEReopenApplication = 0x72617070, kCoreEventClass = 0x61657674,
       kAEGetURL = 0x4755524c, kInternetEventClass = 0x4755524c, keyDirectObject = 0x2d2d2d2d, keyAEPropData = 0x70726f70 };
enum { errAEEventNotHandled = -1708, errAENoSuchObject = -1728 };
#ifdef __cplusplus
}
#endif
#endif
