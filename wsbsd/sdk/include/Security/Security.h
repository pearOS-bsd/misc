#ifndef WSBSD_SECURITY_H
#define WSBSD_SECURITY_H
#if defined(__APPLE__)
#include_next <Security/Security.h>
#else
#include <Security/Authorization.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>                      /* noErr and the other classic result codes, as Apple's Security.h brings in MacTypes.h */
/* code signing and keychain results: there is no code signature on this system, every request answers "not available" */
#ifdef __cplusplus
extern "C" {
#endif
typedef int32_t OSStatus_wsbsd_compat;
typedef struct __SecCode *SecCodeRef;
typedef struct __SecStaticCode *SecStaticCodeRef;
typedef uint32_t SecCSFlags;
enum { errSecSuccess = 0, errSecNotAvailable = -25291, errSecItemNotFound = -25300, errSecParam = -50, errSecUnimplemented = -4, errSecAuthFailed = -25293, errSecDuplicateItem = -25299, errSecDecode = -26275, errSecInteractionNotAllowed = -25308,
       errKCDuplicateItem = -25299, errKCItemNotFound = -25300, errKCNoSuchKeychain = -25294 };
enum { kSecCSDefaultFlags = 0, kSecCSDynamicInformation = 1 << 3, kSecCSSigningInformation = 1 << 1, kSecCSRequirementInformation = 1 << 2 };
extern const CFStringRef kSecCodeInfoEntitlementsDict, kSecCodeInfoEntitlements, kSecCodeInfoIdentifier;

#pragma clang arc_cf_code_audited begin
/* Keychain and keys: there is no keychain here; the queries answer errSecNotAvailable / errSecItemNotFound (an application then behaves as for a user without stored items). Implemented in sdk/src/Security.c */
typedef const struct __SecKey *SecKeyRef;
typedef const struct __SecKeychainItem *SecKeychainItemRef;
typedef const struct __SecKeychain *SecKeychainRef;
typedef uint32_t SecKeychainAttrType;
typedef struct { SecKeychainAttrType tag; uint32_t length; void *data; } SecKeychainAttribute;
typedef struct { uint32_t count; SecKeychainAttribute *attr; } SecKeychainAttributeList;
typedef struct { uint32_t count; SecKeychainAttrType *tag; uint32_t *format; } SecKeychainAttributeInfo;
enum { kSecAccountItemAttr = 0x61636374, kSecServiceItemAttr = 0x73766365, kSecServerItemAttr = 0x73727672, kSecLabelItemAttr = 0x6c61626c, kSecCommentItemAttr = 0x69636d74, kSecDescriptionItemAttr = 0x64657363, kSecPortItemAttr = 0x706f7274, kSecProtocolItemAttr = 0x70746c20 };
enum { CSSM_DB_ATTRIBUTE_FORMAT_STRING = 0, CSSM_DB_ATTRIBUTE_FORMAT_SINT32 = 1, CSSM_DB_ATTRIBUTE_FORMAT_UINT32 = 2, CSSM_DB_ATTRIBUTE_FORMAT_BLOB = 6 };
typedef uint32_t SecExternalFormat, SecExternalItemType, SecItemImportExportFlags;
typedef struct { uint32_t version; SecItemImportExportFlags flags; CFTypeRef passphrase; CFStringRef alertTitle, alertPrompt; void *accessRef; CFArrayRef keyUsage, keyAttributes; } SecItemImportExportKeyParameters;
enum { kSecFormatUnknown = 0, kSecFormatOpenSSL = 1, kSecFormatPEMSequence = 10 };
enum { kSecItemTypeUnknown = 0, kSecItemTypePrivateKey = 1, kSecItemTypePublicKey = 2 };
typedef const void *SecTransformRef;
extern const CFStringRef kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrDescription, kSecAttrAccount, kSecAttrLabel, kSecAttrComment, kSecValueData, kSecValueRef,
	kSecReturnData, kSecReturnRef, kSecReturnAttributes, kSecMatchLimit, kSecMatchLimitAll, kSecMatchLimitOne, kSecTransformInputAttributeName,
	kSecClassInternetPassword, kSecAttrServer, kSecAttrPort, kSecAttrProtocol, kSecAttrPath, kSecAttrSecurityDomain, kSecAttrAuthenticationType, kSecAttrGeneric, kSecAttrCreationDate, kSecAttrModificationDate,
	kSecAttrAccessGroup, kSecAttrSynchronizable, kSecAttrAccessible, kSecAttrAccessibleWhenUnlocked, kSecAttrAccessibleAfterFirstUnlock, kSecAttrProtocolHTTP, kSecAttrProtocolHTTPS, kSecAttrProtocolHTTPProxy, kSecAttrProtocolHTTPSProxy,
	kSecAttrProtocolFTP, kSecAttrProtocolSOCKS, kSecMatchSearchList, kSecMatchItemList;
typedef CFStringRef SecKeyAlgorithm;
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionRaw, kSecKeyAlgorithmRSASignatureRaw;
CFDataRef SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error);
CFDataRef SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error);
size_t SecKeyGetBlockSize(SecKeyRef key);
OSStatus SecKeychainItemDelete(SecKeychainItemRef item);
OSStatus SecKeychainItemModifyAttributesAndData(SecKeychainItemRef item, const SecKeychainAttributeList *attrList, uint32_t length, const void *data);
CFTypeID SecKeyGetTypeID(void);
OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result);
OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
OSStatus SecItemDelete(CFDictionaryRef query);
OSStatus SecKeychainItemCopyAttributesAndData(SecKeychainItemRef item, SecKeychainAttributeInfo *info, uint32_t *itemClass, SecKeychainAttributeList **attrList, uint32_t *length, void **outData);
OSStatus SecKeychainItemFreeAttributesAndData(SecKeychainAttributeList *attrList, void *data);
OSStatus SecItemImport(CFDataRef data, CFStringRef filename, SecExternalFormat *format, SecExternalItemType *type, SecItemImportExportFlags flags, const SecItemImportExportKeyParameters *keyParams, SecKeychainRef keychain, CFArrayRef *items);
CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved);
SecTransformRef SecVerifyTransformCreate(SecKeyRef key, CFDataRef signature, CFErrorRef *error);
Boolean SecTransformSetAttribute(SecTransformRef transform, CFStringRef key, CFTypeRef value, CFErrorRef *error);
CFTypeRef SecTransformExecute(SecTransformRef transform, CFErrorRef *error);
int32_t SecCodeCopySelf(SecCSFlags flags, SecCodeRef *self);
int32_t SecCodeCopySigningInformation(SecCodeRef code, SecCSFlags flags, CFDictionaryRef *information);
#pragma clang arc_cf_code_audited end
#ifdef __cplusplus
}
#endif
#endif
#endif
