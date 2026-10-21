#ifndef WSBSD_SECURITY_H
#define WSBSD_SECURITY_H
#if defined(__APPLE__)
#include_next <Security/Security.h>
#else
#include <Security/Authorization.h>
#include <CoreFoundation/CoreFoundation.h>
/* code signing and keychain results: there is no code signature on this system, every request answers "not available" */
#ifdef __cplusplus
extern "C" {
#endif
typedef int32_t OSStatus_wsbsd_compat;
typedef struct __SecCode *SecCodeRef;
typedef struct __SecStaticCode *SecStaticCodeRef;
typedef uint32_t SecCSFlags;
enum { errSecSuccess = 0, errSecNotAvailable = -25291, errSecItemNotFound = -25300, errSecParam = -50, errSecUnimplemented = -4, errSecAuthFailed = -25293 };
enum { kSecCSDefaultFlags = 0, kSecCSDynamicInformation = 1 << 3, kSecCSSigningInformation = 1 << 1, kSecCSRequirementInformation = 1 << 2 };
extern const CFStringRef kSecCodeInfoEntitlementsDict, kSecCodeInfoEntitlements, kSecCodeInfoIdentifier;

/* Keychain and keys: there is no keychain here; the queries answer errSecNotAvailable / errSecItemNotFound (an application then behaves as for a user without stored items). Implemented in sdk/src/Security.c */
typedef const struct __SecKey *SecKeyRef;
typedef const struct __SecKeychainItem *SecKeychainItemRef;
typedef const struct __SecKeychain *SecKeychainRef;
typedef uint32_t SecKeychainAttrType;
typedef struct { SecKeychainAttrType tag; uint32_t length; void *data; } SecKeychainAttribute;
typedef struct { uint32_t count; SecKeychainAttribute *attr; } SecKeychainAttributeList;
typedef struct { uint32_t count; SecKeychainAttrType *tag; uint32_t *format; } SecKeychainAttributeInfo;
enum { kSecAccountItemAttr = 0x61636374 };
typedef uint32_t SecExternalFormat, SecExternalItemType, SecItemImportExportFlags;
typedef struct { uint32_t version; SecItemImportExportFlags flags; CFTypeRef passphrase; CFStringRef alertTitle, alertPrompt; void *accessRef; CFArrayRef keyUsage, keyAttributes; } SecItemImportExportKeyParameters;
enum { kSecFormatUnknown = 0, kSecFormatPEMSequence = 10 };
enum { kSecItemTypeUnknown = 0, kSecItemTypePrivateKey = 1, kSecItemTypePublicKey = 2 };
typedef const void *SecTransformRef;
extern const CFStringRef kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrDescription, kSecAttrAccount, kSecAttrLabel, kSecAttrComment, kSecValueData, kSecValueRef,
	kSecReturnData, kSecReturnRef, kSecReturnAttributes, kSecMatchLimit, kSecMatchLimitAll, kSecMatchLimitOne, kSecTransformInputAttributeName;
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
#ifdef __cplusplus
}
#endif
#endif
#endif
