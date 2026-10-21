/* CommonCrypto's digests over the libcrypto of the base system (link with -lcrypto) */
#ifndef WSBSD_COMMONDIGEST_H
#define WSBSD_COMMONDIGEST_H
#include <stdint.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
typedef uint32_t CC_LONG;
#define CC_MD5_DIGEST_LENGTH 16
#define CC_SHA1_DIGEST_LENGTH 20
#define CC_SHA256_DIGEST_LENGTH 32
#define CC_SHA384_DIGEST_LENGTH 48
#define CC_SHA512_DIGEST_LENGTH 64
typedef MD5_CTX CC_MD5_CTX;
typedef SHA_CTX CC_SHA1_CTX;
typedef SHA256_CTX CC_SHA256_CTX;
typedef SHA512_CTX CC_SHA512_CTX;
static inline int CC_MD5_Init(CC_MD5_CTX *c) { return MD5_Init(c); }
static inline int CC_MD5_Update(CC_MD5_CTX *c, const void *d, CC_LONG n) { return MD5_Update(c, d, n); }
static inline int CC_MD5_Final(unsigned char *md, CC_MD5_CTX *c) { return MD5_Final(md, c); }
static inline unsigned char *CC_MD5(const void *d, CC_LONG n, unsigned char *md) { return MD5((const unsigned char *)d, n, md); }
static inline int CC_SHA1_Init(CC_SHA1_CTX *c) { return SHA1_Init(c); }
static inline int CC_SHA1_Update(CC_SHA1_CTX *c, const void *d, CC_LONG n) { return SHA1_Update(c, d, n); }
static inline int CC_SHA1_Final(unsigned char *md, CC_SHA1_CTX *c) { return SHA1_Final(md, c); }
static inline unsigned char *CC_SHA1(const void *d, CC_LONG n, unsigned char *md) { return SHA1((const unsigned char *)d, n, md); }
static inline int CC_SHA256_Init(CC_SHA256_CTX *c) { return SHA256_Init(c); }
static inline int CC_SHA256_Update(CC_SHA256_CTX *c, const void *d, CC_LONG n) { return SHA256_Update(c, d, n); }
static inline int CC_SHA256_Final(unsigned char *md, CC_SHA256_CTX *c) { return SHA256_Final(md, c); }
static inline unsigned char *CC_SHA256(const void *d, CC_LONG n, unsigned char *md) { return SHA256((const unsigned char *)d, n, md); }
static inline unsigned char *CC_SHA512(const void *d, CC_LONG n, unsigned char *md) { return SHA512((const unsigned char *)d, n, md); }
#endif
