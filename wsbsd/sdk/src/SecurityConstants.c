/* The string constants of the keychain query dictionaries: CFSTR of this CoreFoundation is not a constant expression, so they are set when the library loads (the header declares them const). */
#include <CoreFoundation/CoreFoundation.h>
CFStringRef kSecClass;
CFStringRef kSecClassGenericPassword;
CFStringRef kSecAttrService;
CFStringRef kSecAttrDescription;
CFStringRef kSecAttrAccount;
CFStringRef kSecAttrLabel;
CFStringRef kSecAttrComment;
CFStringRef kSecValueData;
CFStringRef kSecValueRef;
CFStringRef kSecReturnData;
CFStringRef kSecReturnRef;
CFStringRef kSecReturnAttributes;
CFStringRef kSecMatchLimit;
CFStringRef kSecMatchLimitAll;
CFStringRef kSecMatchLimitOne;
CFStringRef kSecTransformInputAttributeName;
__attribute__((constructor)) static void wsbsd_security_constants(void)
{
	kSecClass = CFSTR("class");
	kSecClassGenericPassword = CFSTR("genp");
	kSecAttrService = CFSTR("svce");
	kSecAttrDescription = CFSTR("desc");
	kSecAttrAccount = CFSTR("acct");
	kSecAttrLabel = CFSTR("labl");
	kSecAttrComment = CFSTR("icmt");
	kSecValueData = CFSTR("v_Data");
	kSecValueRef = CFSTR("v_Ref");
	kSecReturnData = CFSTR("r_Data");
	kSecReturnRef = CFSTR("r_Ref");
	kSecReturnAttributes = CFSTR("r_Attributes");
	kSecMatchLimit = CFSTR("m_Limit");
	kSecMatchLimitAll = CFSTR("m_LimitAll");
	kSecMatchLimitOne = CFSTR("m_LimitOne");
	kSecTransformInputAttributeName = CFSTR("INPUT");
}
