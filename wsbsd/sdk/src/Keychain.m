/* The keychain: generic and internet passwords in one encrypted file, public keys imported from PEM, RSA public-key operations.
 * Store: ~/Library/Keychains/login.keychain-wsbsd, a binary property list sealed with AES-256-GCM ("WSKC1", nonce, tag, ciphertext). The key is read from login.key next to it (mode 0600, created on first use) or from the file
 * named by WSBSD_KEYCHAIN_KEYFILE, which is where a hardware token (see the Pico 2 plan) hands the key over. Without a token the protection is the file permission, not an unlock password. */
#import <Foundation/Foundation.h>
#include <Security/Security.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>

static NSString *Dir(void) { const char *h = getenv("HOME"); NSString *d = [(h ? [NSString stringWithUTF8String: h] : NSHomeDirectory()) stringByAppendingPathComponent: @"Library/Keychains"];   /* HOME wins: NSHomeDirectory() is fixed at launch */ [[NSFileManager defaultManager] createDirectoryAtPath: d withIntermediateDirectories: YES attributes: @{ NSFilePosixPermissions: @0700 } error: NULL]; return d; }
static NSData *MasterKey(void)
{
	const char *env = getenv("WSBSD_KEYCHAIN_KEYFILE"); NSString *p = env ? [NSString stringWithUTF8String: env] : [Dir() stringByAppendingPathComponent: @"login.key"];
	NSData *k = [NSData dataWithContentsOfFile: p]; if ([k length] == 32) return k;
	unsigned char b[32]; if (RAND_bytes(b, 32) != 1) return nil; k = [NSData dataWithBytes: b length: 32];
	int fd = open([p fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, 0600); if (fd < 0) return [NSData dataWithContentsOfFile: p];
	write(fd, b, 32); close(fd); return k;
}
static NSData *Seal(NSData *plain, NSData *key)
{
	unsigned char nonce[12], tag[16]; RAND_bytes(nonce, 12); EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new(); NSMutableData *out = [NSMutableData dataWithBytes: "WSKC1" length: 5]; [out appendBytes: nonce length: 12]; [out increaseLengthBy: 16];
	NSMutableData *ct = [NSMutableData dataWithLength: [plain length] + 16]; int n = 0, m = 0;
	EVP_EncryptInit_ex(c, EVP_aes_256_gcm(), NULL, [key bytes], nonce); EVP_EncryptUpdate(c, [ct mutableBytes], &n, [plain bytes], (int)[plain length]); EVP_EncryptFinal_ex(c, (unsigned char *)[ct mutableBytes] + n, &m);
	EVP_CIPHER_CTX_ctrl(c, EVP_CTRL_GCM_GET_TAG, 16, tag); EVP_CIPHER_CTX_free(c); memcpy((unsigned char *)[out mutableBytes] + 17, tag, 16); [out appendBytes: [ct bytes] length: n + m]; return out;
}
static NSData *Open(NSData *file, NSData *key)
{
	if ([file length] < 33 || memcmp([file bytes], "WSKC1", 5)) return nil;
	const unsigned char *f = [file bytes]; NSMutableData *pt = [NSMutableData dataWithLength: [file length]]; int n = 0, m = 0; EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();
	EVP_DecryptInit_ex(c, EVP_aes_256_gcm(), NULL, [key bytes], f + 5); EVP_DecryptUpdate(c, [pt mutableBytes], &n, f + 33, (int)[file length] - 33);
	EVP_CIPHER_CTX_ctrl(c, EVP_CTRL_GCM_SET_TAG, 16, (void *)(f + 17)); int ok = EVP_DecryptFinal_ex(c, (unsigned char *)[pt mutableBytes] + n, &m); EVP_CIPHER_CTX_free(c);
	if (ok <= 0) return nil; [pt setLength: n + m]; return pt;
}

/* the store: a locked read-modify-write of the whole file */
static NSString *StorePath(void) { return [Dir() stringByAppendingPathComponent: @"login.keychain-wsbsd"]; }
static NSMutableArray *LoadItems(void)
{
	NSData *f = [NSData dataWithContentsOfFile: StorePath()]; NSData *key = MasterKey(); if (!f || !key) return [NSMutableArray array];
	NSData *pt = Open(f, key); if (!pt) return nil;                                                        /* a store that does not open is left alone, never overwritten */
	id o = [NSPropertyListSerialization propertyListWithData: pt options: NSPropertyListMutableContainers format: NULL error: NULL]; return [o isKindOfClass: [NSMutableArray class]] ? o : [NSMutableArray array];
}
static BOOL SaveItems(NSArray *items)
{
	NSData *key = MasterKey(); if (!key) return NO; NSData *pt = [NSPropertyListSerialization dataWithPropertyList: items format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL]; if (!pt) return NO;
	NSString *tmp = [StorePath() stringByAppendingString: @".tmp"]; int fd = open([tmp fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0600); if (fd < 0) return NO;
	NSData *sealed = Seal(pt, key); BOOL ok = write(fd, [sealed bytes], [sealed length]) == (ssize_t)[sealed length]; close(fd); return ok && rename([tmp fileSystemRepresentation], [StorePath() fileSystemRepresentation]) == 0;
}
static int LockFd = -1;
static OSStatus WithStore(BOOL write, OSStatus (^body)(NSMutableArray *items))
{
	@synchronized ([NSNull null]) {
		NSString *lock = [Dir() stringByAppendingPathComponent: @"login.lock"]; int fd = open([lock fileSystemRepresentation], O_RDWR | O_CREAT, 0600); if (fd < 0) return errSecNotAvailable; flock(fd, write ? LOCK_EX : LOCK_SH);
		NSMutableArray *items = LoadItems(); OSStatus st;
		if (!items) st = errSecDecode; else { st = body(items); if (write && st == errSecSuccess && !SaveItems(items)) st = errSecNotAvailable; }
		flock(fd, LOCK_UN); close(fd); (void)LockFd; return st;
	}
}

/* attribute keys that identify an item; the rest is data or search control */
static NSArray *IdentityKeys(void) { return @[ @"class", @"svce", @"acct", @"srvr", @"port", @"ptcl", @"path", @"sdmn", @"atyp" ]; }
static NSArray *AttrKeys(void) { return @[ @"class", @"svce", @"acct", @"srvr", @"port", @"ptcl", @"path", @"sdmn", @"atyp", @"desc", @"labl", @"icmt", @"gena", @"cdat", @"mdat", @"agrp", @"sync", @"pdmn" ]; }
static BOOL Matches(NSDictionary *item, NSDictionary *q, NSArray *keys)
{
	for (NSString *k in keys) { id want = q[k]; if (!want) continue; id have = item[k]; if (!have || ![have isEqual: want]) return NO; }
	return YES;
}
static BOOL B(id v) { if (!v) return NO; if (CFGetTypeID((__bridge CFTypeRef)v) == CFBooleanGetTypeID()) return CFBooleanGetValue((__bridge CFBooleanRef)v); return [v respondsToSelector: @selector(boolValue)] && [v boolValue]; }   /* kCFBooleanTrue is a CFBoolean, not always an NSNumber */
static NSDictionary *Query(CFDictionaryRef q) { return (__bridge NSDictionary *)q; }
static SecKeychainItemRef RefOf(NSDictionary *item) { return (SecKeychainItemRef)CFBridgingRetain([item copy]); }

OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result)
{
	NSDictionary *a = Query(attributes); if (![a[@"class"] length] || ![@[ @"genp", @"inet" ] containsObject: a[@"class"]]) return errSecParam;
	__block NSDictionary *added = nil;
	OSStatus st = WithStore(YES, ^OSStatus(NSMutableArray *items) {
		for (NSDictionary *it in items) if (Matches(it, a, IdentityKeys()) && Matches(a, it, IdentityKeys())) return errSecDuplicateItem;
		NSMutableDictionary *n = [NSMutableDictionary dictionary]; for (NSString *k in AttrKeys()) if (a[k]) n[k] = a[k];
		if (a[@"v_Data"]) n[@"v_Data"] = a[@"v_Data"]; n[@"cdat"] = n[@"mdat"] = [NSDate date]; [items addObject: n]; added = n; return errSecSuccess; });
	if (st == errSecSuccess && result) { *result = (B(a[@"r_Ref"])) ? (CFTypeRef)RefOf(added) : (B(a[@"r_Data"]) ? (CFTypeRef)CFBridgingRetain(added[@"v_Data"]) : NULL); }
	return st;
}
OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
{
	NSDictionary *q = Query(query); BOOL all = [q[@"m_Limit"] isEqual: @"m_LimitAll"], wData = B(q[@"r_Data"]), wRef = B(q[@"r_Ref"]), wAttr = B(q[@"r_Attributes"]);
	__block NSMutableArray *found = [NSMutableArray array];
	OSStatus st = WithStore(NO, ^OSStatus(NSMutableArray *items) { for (NSDictionary *it in items) if (Matches(it, q, AttrKeys())) { [found addObject: it]; if (!all) break; } return found.count ? errSecSuccess : errSecItemNotFound; });
	if (st != errSecSuccess) { if (result) *result = NULL; return st; }
	if (!result) return errSecSuccess;
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *it in found) {
		id one;
		if ((wData ? 1 : 0) + (wRef ? 1 : 0) + (wAttr ? 1 : 0) > 1 || (wAttr && !wData && !wRef) ) {
			NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSString *k in AttrKeys()) if (it[k]) d[k] = it[k];
			if (wData && it[@"v_Data"]) d[@"v_Data"] = it[@"v_Data"]; if (wRef) d[@"v_Ref"] = CFBridgingRelease(RefOf(it)); one = d;
		} else if (wRef) one = CFBridgingRelease(RefOf(it)); else if (wData) one = it[@"v_Data"] ?: [NSData data]; else one = @YES;
		[out addObject: one];
	}
	*result = CFBridgingRetain(all ? (id)out : out[0]); return errSecSuccess;
}
OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate)
{
	NSDictionary *q = Query(query), *u = Query(attributesToUpdate);
	return WithStore(YES, ^OSStatus(NSMutableArray *items) {
		int n = 0; for (NSUInteger i = 0; i < items.count; i++) if (Matches(items[i], q, AttrKeys())) { NSMutableDictionary *d = [items[i] mutableCopy]; for (NSString *k in u) d[k] = u[k]; d[@"mdat"] = [NSDate date]; items[i] = d; n++; }
		return n ? errSecSuccess : errSecItemNotFound; });
}
OSStatus SecItemDelete(CFDictionaryRef query)
{
	NSDictionary *q = Query(query);
	return WithStore(YES, ^OSStatus(NSMutableArray *items) { NSUInteger before = items.count; for (NSInteger i = (NSInteger)items.count - 1; i >= 0; i--) if (Matches(items[i], q, AttrKeys())) [items removeObjectAtIndex: i]; return items.count < before ? errSecSuccess : errSecItemNotFound; });
}

/* items as references: attributes and data by four-character code */
static NSString *CodeString(uint32_t t) { char c[5] = { (char)(t >> 24), (char)(t >> 16), (char)(t >> 8), (char)t, 0 }; return [NSString stringWithUTF8String: c]; }
OSStatus SecKeychainItemCopyAttributesAndData(SecKeychainItemRef item, SecKeychainAttributeInfo *info, uint32_t *itemClass, SecKeychainAttributeList **attrList, uint32_t *length, void **outData)
{
	NSDictionary *it = (__bridge NSDictionary *)item; if (!it) return errSecParam;
	if (itemClass) *itemClass = [it[@"class"] isEqual: @"inet"] ? 'inet' : 'genp';
	if (attrList) {
		*attrList = NULL;
		if (info) {
			SecKeychainAttributeList *l = calloc(1, sizeof *l); l->attr = calloc(info->count ?: 1, sizeof *l->attr);
			for (uint32_t i = 0; i < info->count; i++) {
				id v = it[CodeString(info->tag[i])]; NSData *d = [v isKindOfClass: [NSString class]] ? [(NSString *)v dataUsingEncoding: NSUTF8StringEncoding] : [v isKindOfClass: [NSNumber class]] ? [[v stringValue] dataUsingEncoding: NSUTF8StringEncoding] : v;
				l->attr[l->count].tag = info->tag[i]; l->attr[l->count].length = (uint32_t)[d length]; l->attr[l->count].data = d ? memcpy(malloc([d length] ?: 1), [d bytes], [d length]) : NULL; l->count++;
			}
			*attrList = l;
		}
	}
	NSData *data = it[@"v_Data"]; if (length) *length = (uint32_t)[data length]; if (outData) *outData = data ? memcpy(malloc([data length] ?: 1), [data bytes], [data length]) : NULL; return errSecSuccess;
}
OSStatus SecKeychainItemFreeAttributesAndData(SecKeychainAttributeList *l, void *data)
{
	if (l) { for (uint32_t i = 0; i < l->count; i++) free(l->attr[i].data); free(l->attr); free(l); } free(data); return errSecSuccess;
}
OSStatus SecKeychainItemDelete(SecKeychainItemRef item)
{
	NSDictionary *it = (__bridge NSDictionary *)item; if (!it) return errSecParam;
	return WithStore(YES, ^OSStatus(NSMutableArray *items) { for (NSUInteger i = 0; i < items.count; i++) if (Matches(items[i], it, IdentityKeys())) { [items removeObjectAtIndex: i]; return errSecSuccess; } return errSecItemNotFound; });
}
OSStatus SecKeychainItemModifyAttributesAndData(SecKeychainItemRef item, const SecKeychainAttributeList *l, uint32_t length, const void *data)
{
	NSDictionary *it = (__bridge NSDictionary *)item; if (!it) return errSecParam;
	return WithStore(YES, ^OSStatus(NSMutableArray *items) {
		for (NSUInteger i = 0; i < items.count; i++) if (Matches(items[i], it, IdentityKeys())) {
			NSMutableDictionary *d = [items[i] mutableCopy];
			for (uint32_t j = 0; l && j < l->count; j++) d[CodeString(l->attr[j].tag)] = [[NSString alloc] initWithBytes: l->attr[j].data length: l->attr[j].length encoding: NSUTF8StringEncoding] ?: @"";
			if (data) d[@"v_Data"] = [NSData dataWithBytes: data length: length]; d[@"mdat"] = [NSDate date]; items[i] = d; return errSecSuccess; }
		return errSecItemNotFound; });
}

/* keys: a SecKeyRef is a retained EVP_PKEY inside an NSValue-like holder */
@interface WsbsdSecKey : NSObject { @public EVP_PKEY *pkey; } @end
@implementation WsbsdSecKey - (void)dealloc { EVP_PKEY_free(pkey); } @end
CFTypeID SecKeyGetTypeID(void) { return (CFTypeID)[WsbsdSecKey class]; }
OSStatus SecItemImport(CFDataRef data, CFStringRef filename, SecExternalFormat *format, SecExternalItemType *type, SecItemImportExportFlags flags, const SecItemImportExportKeyParameters *keyParams, SecKeychainRef keychain, CFArrayRef *items)
{
	(void)filename; (void)flags; (void)keyParams; (void)keychain; if (items) *items = NULL; if (!data) return errSecParam;
	NSData *d = (__bridge NSData *)data; BIO *bio = BIO_new_mem_buf([d bytes], (int)[d length]); EVP_PKEY *pk = PEM_read_bio_PUBKEY(bio, NULL, NULL, NULL); BOOL priv = NO;
	if (!pk) { BIO_free(bio); bio = BIO_new_mem_buf([d bytes], (int)[d length]); pk = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL); priv = pk != NULL; }
	BIO_free(bio); if (!pk) return errSecDecode;
	WsbsdSecKey *k = [WsbsdSecKey new]; k->pkey = pk; if (type) *type = priv ? kSecItemTypePrivateKey : kSecItemTypePublicKey; if (format) *format = kSecFormatOpenSSL;
	if (items) *items = (CFArrayRef)CFBridgingRetain(@[ k ]); return errSecSuccess;
}
size_t SecKeyGetBlockSize(SecKeyRef key) { WsbsdSecKey *k = (__bridge WsbsdSecKey *)key; return k ? (size_t)EVP_PKEY_size(k->pkey) : 0; }
static CFDataRef RSARaw(SecKeyRef key, CFDataRef in, BOOL decrypt, CFErrorRef *error)
{
	WsbsdSecKey *k = (__bridge WsbsdSecKey *)key; NSData *d = (__bridge NSData *)in; if (error) *error = NULL; if (!k || !d) return NULL;
	EVP_PKEY_CTX *c = EVP_PKEY_CTX_new(k->pkey, NULL); size_t n = 0; int ok;
	if (decrypt) ok = EVP_PKEY_verify_recover_init(c); else ok = EVP_PKEY_encrypt_init(c);
	if (ok <= 0 || EVP_PKEY_CTX_set_rsa_padding(c, RSA_NO_PADDING) <= 0) { EVP_PKEY_CTX_free(c); return NULL; }
	ok = decrypt ? EVP_PKEY_verify_recover(c, NULL, &n, [d bytes], [d length]) : EVP_PKEY_encrypt(c, NULL, &n, [d bytes], [d length]); if (ok <= 0) { EVP_PKEY_CTX_free(c); return NULL; }
	NSMutableData *o = [NSMutableData dataWithLength: n];
	ok = decrypt ? EVP_PKEY_verify_recover(c, [o mutableBytes], &n, [d bytes], [d length]) : EVP_PKEY_encrypt(c, [o mutableBytes], &n, [d bytes], [d length]); EVP_PKEY_CTX_free(c); if (ok <= 0) return NULL;
	[o setLength: n]; return (CFDataRef)CFBridgingRetain(o);
}
CFDataRef SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error) { (void)algorithm; return RSARaw(key, ciphertext, YES, error); }
CFDataRef SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error) { (void)algorithm; return RSARaw(key, plaintext, NO, error); }
