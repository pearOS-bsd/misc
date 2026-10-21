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
enum { typeWildCard = 0x2a2a2a2a, kAutoGenerateReturnID = -1, kAnyTransactionID = 0 };
typedef int16_t OSErr_ae;
typedef uint32_t AEEventClass, AEEventID;
typedef int16_t AEReturnID; typedef int32_t AETransactionID; typedef int32_t AESendMode; typedef long AESize;
enum { keyEventClassAttr = 0x6576636c, keyEventIDAttr = 0x65766964, kAENoReply = 1, kAEWaitReply = 3, kAEDefaultTimeout = -1, kAEDoNotRecord = 0x1000, errAEDescNotFound = -1701, errAECoercionFail = -1700 };
enum { errAEEventNotHandled = -1708, errAENoSuchObject = -1728 };

/* in-memory descriptors (sdk/src/AppleEvents.m): typed data, lists and records; there is no inter-process delivery, AESendMessage reports that the target is not there */
int16_t AECreateDesc(DescType typeCode, const void *dataPtr, long dataSize, AEDesc *result);
int16_t AEDisposeDesc(AEDesc *theAEDesc);
int16_t AEDuplicateDesc(const AEDesc *theAEDesc, AEDesc *result);
long AEGetDescDataSize(const AEDesc *theAEDesc);
int16_t AEGetDescData(const AEDesc *theAEDesc, void *dataPtr, long maximumSize);
int16_t AECreateList(const void *factoringPtr, long factoredSize, Boolean isRecord, AEDescList *resultList);
int16_t AECountItems(const AEDescList *theAEDescList, long *theCount);
int16_t AEPutParamPtr(AppleEvent *theAppleEvent, AEKeyword theAEKeyword, DescType typeCode, const void *dataPtr, long dataSize);
int16_t AEPutParamDesc(AppleEvent *theAppleEvent, AEKeyword theAEKeyword, const AEDesc *theAEDesc);
int16_t AEGetParamDesc(const AppleEvent *theAppleEvent, AEKeyword theAEKeyword, DescType desiredType, AEDesc *result);
int16_t AEGetNthDesc(const AEDescList *theAEDescList, long index, DescType desiredType, AEKeyword *theAEKeyword, AEDesc *result);
int16_t AECoerceDesc(const AEDesc *theAEDesc, DescType toType, AEDesc *result);
int16_t AECreateAppleEvent(AEEventClass theAEEventClass, AEEventID theAEEventID, const AEAddressDesc *target, AEReturnID returnID, AETransactionID transactionID, AppleEvent *result);
int16_t AEGetAttributePtr(const AppleEvent *theAppleEvent, AEKeyword theAEKeyword, DescType desiredType, DescType *typeCode, void *dataPtr, long maximumSize, long *actualSize);
int16_t AESendMessage(const AppleEvent *event, AppleEvent *reply, AESendMode sendMode, long timeOutInTicks);
#ifdef __cplusplus
}
#endif
#endif
