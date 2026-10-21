/* Keychain (items, attributes, references, update, delete, persistence across a reload, a sealed file), PEM key import with the raw RSA operation, Authorization rights */
#import <Foundation/Foundation.h>
#include <Security/Security.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
static CFDictionaryRef D(CFTypeRef *k, CFTypeRef *v, int n) { return CFDictionaryCreate(NULL, (const void **)k, (const void **)v, n, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); }
int main(void)
{
	@autoreleasepool {
		char dir[] = "/tmp/wsbsd-sec-XXXXXX"; CHECK(mkdtemp(dir) != NULL); setenv("HOME", dir, 1); setenv("WSBSD_AUTH_DB", [[NSString stringWithFormat: @"%s/auth.plist", dir] UTF8String], 1);
		CFDataRef secret = (__bridge CFDataRef)[@"s3cret" dataUsingEncoding: NSUTF8StringEncoding];
		CFTypeRef ak[] = { kSecClass, kSecAttrService, kSecAttrAccount, kSecAttrLabel, kSecValueData }, av[] = { kSecClassGenericPassword, CFSTR("TextMate"), CFSTR("alice"), CFSTR("license"), secret };
		CFDictionaryRef add = D(ak, av, 5); CHECK(SecItemAdd(add, NULL) == errSecSuccess); CHECK(SecItemAdd(add, NULL) == errSecDuplicateItem);
		CFTypeRef qk[] = { kSecClass, kSecAttrService, kSecAttrAccount, kSecReturnData }, qv[] = { kSecClassGenericPassword, CFSTR("TextMate"), CFSTR("alice"), kCFBooleanTrue };
		CFDictionaryRef q = D(qk, qv, 4); CFTypeRef out = NULL; CHECK(SecItemCopyMatching(q, &out) == errSecSuccess && out && CFEqual(out, secret)); if (out) CFRelease(out);
		CFTypeRef nk[] = { kSecClass, kSecAttrService, kSecAttrAccount, kSecReturnData }, nv[] = { kSecClassGenericPassword, CFSTR("TextMate"), CFSTR("bob"), kCFBooleanTrue };
		CFDictionaryRef nq = D(nk, nv, 4); out = NULL; CHECK(SecItemCopyMatching(nq, &out) == errSecItemNotFound && out == NULL);
		/* second item, then all items as references and their attributes */
		CFTypeRef bk[] = { kSecClass, kSecAttrService, kSecAttrAccount, kSecValueData }, bv[] = { kSecClassGenericPassword, CFSTR("TextMate"), CFSTR("bob"), secret }; CFDictionaryRef add2 = D(bk, bv, 4); CHECK(SecItemAdd(add2, NULL) == errSecSuccess);
		CFTypeRef lk[] = { kSecMatchLimit, kSecReturnRef, kSecClass, kSecAttrService }, lv[] = { kSecMatchLimitAll, kCFBooleanTrue, kSecClassGenericPassword, CFSTR("TextMate") };
		CFDictionaryRef lq = D(lk, lv, 4); CFArrayRef all = NULL; CHECK(SecItemCopyMatching(lq, (CFTypeRef *)&all) == errSecSuccess && all && CFArrayGetCount(all) == 2);
		int names = 0; for (CFIndex i = 0; all && i < CFArrayGetCount(all); i++) {
			UInt32 tag = kSecAccountItemAttr, format = CSSM_DB_ATTRIBUTE_FORMAT_STRING; SecKeychainAttributeInfo info = { 1, &tag, &format }; SecKeychainAttributeList *l = NULL; UInt32 len = 0; void *data = NULL;
			CHECK(SecKeychainItemCopyAttributesAndData((SecKeychainItemRef)CFArrayGetValueAtIndex(all, i), &info, NULL, &l, &len, &data) == noErr && l && l->count == 1 && len == 6 && !memcmp(data, "s3cret", 6));
			if (l && l->attr->length == 5 && !memcmp(l->attr->data, "alice", 5)) names |= 1; if (l && l->attr->length == 3 && !memcmp(l->attr->data, "bob", 3)) names |= 2; SecKeychainItemFreeAttributesAndData(l, data); }
		CHECK(names == 3);
		/* update, delete, and the file is sealed (the secret is not in it) */
		CFTypeRef uk[] = { kSecValueData }, uv[] = { CFSTR("x") }; CFDataRef nd = (__bridge CFDataRef)[@"new-secret" dataUsingEncoding: NSUTF8StringEncoding]; uv[0] = nd; CFDictionaryRef up = D(uk, uv, 1);
		CHECK(SecItemUpdate(q, up) == errSecSuccess); CHECK(SecItemCopyMatching(q, &out) == errSecSuccess && out && CFEqual(out, nd)); if (out) CFRelease(out);
		NSData *file = [NSData dataWithContentsOfFile: [NSString stringWithFormat: @"%s/Library/Keychains/login.keychain-wsbsd", dir]]; CHECK([file length] > 33 && !memcmp([file bytes], "WSKC1", 5));
		CHECK([file rangeOfData: [@"new-secret" dataUsingEncoding: NSUTF8StringEncoding] options: 0 range: NSMakeRange(0, [file length])].location == NSNotFound);
		CHECK(SecItemDelete(q) == errSecSuccess); CHECK(SecItemCopyMatching(q, &out) == errSecItemNotFound);
		/* a store that was tampered with is not overwritten */
		NSMutableData *bad = [file mutableCopy]; ((unsigned char *)[bad mutableBytes])[40] ^= 1; [bad writeToFile: [NSString stringWithFormat: @"%s/Library/Keychains/login.keychain-wsbsd", dir] atomically: YES];
		CHECK(SecItemAdd(add, NULL) == errSecDecode);
		/* public key from PEM: raw RSA public operation recovers what the private key signed with no padding */
		EVP_PKEY *pk = EVP_RSA_gen(2048); CHECK(pk != NULL); if (!pk) return 1; BIO *mb = BIO_new(BIO_s_mem()); PEM_write_bio_PUBKEY(mb, pk); char *pem; long pl = BIO_get_mem_data(mb, &pem); CFDataRef pemd = CFDataCreate(NULL, (UInt8 *)pem, pl);
		SecExternalFormat fmt = kSecFormatPEMSequence; SecExternalItemType ty = kSecItemTypePublicKey; CFArrayRef items = NULL;
		CHECK(SecItemImport(pemd, CFSTR(".pem"), &fmt, &ty, 0, NULL, NULL, &items) == errSecSuccess && items && CFArrayGetCount(items) == 1);
		unsigned char msg[256] = { 0 }; memcpy(msg + 200, "hello", 5); unsigned char sig[256]; size_t sl = sizeof sig; EVP_PKEY_CTX *sc = EVP_PKEY_CTX_new(pk, NULL); EVP_PKEY_encrypt_init(sc); (void)sc; EVP_PKEY_CTX_free(sc);
		sc = EVP_PKEY_CTX_new(pk, NULL); EVP_PKEY_sign_init(sc); EVP_PKEY_CTX_set_rsa_padding(sc, RSA_NO_PADDING); CHECK(EVP_PKEY_sign(sc, sig, &sl, msg, 256) == 1); EVP_PKEY_CTX_free(sc);
		CFDataRef sigd = CFDataCreate(NULL, sig, sl); CFDataRef rec = SecKeyCreateDecryptedData((SecKeyRef)CFArrayGetValueAtIndex(items, 0), kSecKeyAlgorithmRSAEncryptionRaw, sigd, NULL);
		CHECK(rec && CFDataGetLength(rec) == 256 && !memcmp(CFDataGetBytePtr(rec) + 200, "hello", 5)); CHECK(SecKeyGetBlockSize((SecKeyRef)CFArrayGetValueAtIndex(items, 0)) == 256);
		/* Authorization: root edits the rights database; a right defined as "allow" is held, an undefined one is not (no interaction) */
		AuthorizationRef ar = NULL; CHECK(AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &ar) == errAuthorizationSuccess && ar);
		AuthorizationItem it = { "org.wsbsd.test.right", 0, NULL, 0 }; AuthorizationRights rights = { 1, &it }; AuthorizationRights *granted = NULL;
		if (geteuid() == 0) { CHECK(AuthorizationRightSet(ar, "org.wsbsd.test.right", CFSTR("deny"), NULL, NULL, NULL) == errAuthorizationSuccess); CFDictionaryRef def = NULL; CHECK(AuthorizationRightGet("org.wsbsd.test.right", &def) == errAuthorizationSuccess && def);
			CHECK(AuthorizationCopyRights(ar, &rights, NULL, kAuthorizationFlagExtendRights, &granted) == errAuthorizationSuccess && granted && granted->count == 1); AuthorizationFreeItemSet(granted);
			CHECK(AuthorizationRightRemove(ar, "org.wsbsd.test.right") == errAuthorizationSuccess); CHECK(AuthorizationRightGet("org.wsbsd.test.right", &def) == errAuthorizationDenied); }
		else { CHECK(AuthorizationCopyRights(ar, &rights, NULL, kAuthorizationFlagExtendRights, &granted) == errAuthorizationInteractionNotAllowed); }
		AuthorizationExternalForm ef; CHECK(AuthorizationMakeExternalForm(ar, &ef) == errAuthorizationSuccess); AuthorizationRef ar2 = NULL; CHECK(AuthorizationCreateFromExternalForm(&ef, &ar2) == errAuthorizationSuccess && ar2); if (ar2) AuthorizationFree(ar2, 0);
		AuthorizationFree(ar, 0);
	}
	printf(fails ? "sec_tests: %d failed\n" : "sec_tests: ok\n", fails); return fails != 0;
}
