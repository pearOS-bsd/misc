/* Code signing queries: no signature exists here, the calls report that (applications fall back to their unsigned behaviour). */
#include <Security/Security.h>
int32_t SecCodeCopySelf(SecCSFlags flags, SecCodeRef *self) { (void)flags; if (self) *self = NULL; return errSecNotAvailable; }
int32_t SecCodeCopySigningInformation(SecCodeRef code, SecCSFlags flags, CFDictionaryRef *information) { (void)code; (void)flags; if (information) *information = NULL; return errSecNotAvailable; }

/* the keychain itself is in Keychain.m; signature transforms do not exist here */
CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved)
{
	(void)reserved;
	switch (status) {
	case errSecSuccess: return CFSTR("No error.");
	case errSecNotAvailable: return CFSTR("No keychain is available.");
	case errSecItemNotFound: return CFSTR("The specified item could not be found in the keychain.");
	case errSecParam: return CFSTR("One or more parameters passed to a function were not valid.");
	case errSecUnimplemented: return CFSTR("Function or operation not implemented.");
	case errSecDuplicateItem: return CFSTR("The specified item already exists in the keychain.");
	case errSecDecode: return CFSTR("Unable to decode the provided data.");
	case errSecAuthFailed: return CFSTR("The user name or passphrase you entered is not correct.");
	}
	return CFSTR("Unknown security error.");
}
SecTransformRef SecVerifyTransformCreate(SecKeyRef key, CFDataRef signature, CFErrorRef *error) { (void)key; (void)signature; if (error) *error = NULL; return NULL; }
Boolean SecTransformSetAttribute(SecTransformRef transform, CFStringRef key, CFTypeRef value, CFErrorRef *error) { (void)transform; (void)key; (void)value; if (error) *error = NULL; return false; }
CFTypeRef SecTransformExecute(SecTransformRef transform, CFErrorRef *error) { (void)transform; if (error) *error = NULL; return NULL; }
