/* Code signing queries: no signature exists here, the calls report that (applications fall back to their unsigned behaviour). */
#include <Security/Security.h>
int32_t SecCodeCopySelf(SecCSFlags flags, SecCodeRef *self) { (void)flags; if (self) *self = NULL; return errSecNotAvailable; }
int32_t SecCodeCopySigningInformation(SecCodeRef code, SecCSFlags flags, CFDictionaryRef *information) { (void)code; (void)flags; if (information) *information = NULL; return errSecNotAvailable; }

/* Keychain, key import and signature transforms: none of them exists here */
OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) { (void)query; if (result) *result = NULL; return errSecItemNotFound; }
OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) { (void)attributes; if (result) *result = NULL; return errSecNotAvailable; }
OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) { (void)query; (void)attributesToUpdate; return errSecItemNotFound; }
OSStatus SecItemDelete(CFDictionaryRef query) { (void)query; return errSecItemNotFound; }
OSStatus SecKeychainItemCopyAttributesAndData(SecKeychainItemRef item, SecKeychainAttributeInfo *info, uint32_t *itemClass, SecKeychainAttributeList **attrList, uint32_t *length, void **outData)
{ (void)item; (void)info; (void)itemClass; if (attrList) *attrList = NULL; if (length) *length = 0; if (outData) *outData = NULL; return errSecItemNotFound; }
OSStatus SecKeychainItemFreeAttributesAndData(SecKeychainAttributeList *attrList, void *data) { (void)attrList; (void)data; return errSecSuccess; }
OSStatus SecItemImport(CFDataRef data, CFStringRef filename, SecExternalFormat *format, SecExternalItemType *type, SecItemImportExportFlags flags, const SecItemImportExportKeyParameters *keyParams, SecKeychainRef keychain, CFArrayRef *items)
{ (void)data; (void)filename; (void)format; (void)type; (void)flags; (void)keyParams; (void)keychain; if (items) *items = NULL; return errSecUnimplemented; }
CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved)
{
	(void)reserved;
	switch (status) {
	case errSecSuccess: return CFSTR("No error.");
	case errSecNotAvailable: return CFSTR("No keychain is available.");
	case errSecItemNotFound: return CFSTR("The specified item could not be found in the keychain.");
	case errSecParam: return CFSTR("One or more parameters passed to a function were not valid.");
	case errSecUnimplemented: return CFSTR("Function or operation not implemented.");
	case errSecAuthFailed: return CFSTR("The user name or passphrase you entered is not correct.");
	}
	return CFSTR("Unknown security error.");
}
SecTransformRef SecVerifyTransformCreate(SecKeyRef key, CFDataRef signature, CFErrorRef *error) { (void)key; (void)signature; if (error) *error = NULL; return NULL; }
Boolean SecTransformSetAttribute(SecTransformRef transform, CFStringRef key, CFTypeRef value, CFErrorRef *error) { (void)transform; (void)key; (void)value; if (error) *error = NULL; return false; }
CFTypeRef SecTransformExecute(SecTransformRef transform, CFErrorRef *error) { (void)transform; if (error) *error = NULL; return NULL; }
