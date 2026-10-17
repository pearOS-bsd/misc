/* Smoke test of the engine of Hex Fiend built from its unmodified sources: a byte array of the real HexFiend framework, edited and read back. */
#import <Foundation/Foundation.h>
#import <HexFiend/HexFiend.h>

int main(void)
{
	@autoreleasepool {
		HFByteArray *a = [[HFBTreeByteArray alloc] init];
		NSData *d = [@"Hello, FreeBSD" dataUsingEncoding: NSUTF8StringEncoding];
		HFByteSlice *s = [[HFFullMemoryByteSlice alloc] initWithData: d];
		[a insertByteSlice: s inRange: HFRangeMake(0, 0)];
		NSData *x = [@" world" dataUsingEncoding: NSUTF8StringEncoding];
		[a insertByteSlice: [[HFFullMemoryByteSlice alloc] initWithData: x] inRange: HFRangeMake(5, 0)];          /* "Hello world, FreeBSD" */
		[a deleteBytesInRange: HFRangeMake(0, 1)];                                                                      /* "ello world, FreeBSD" */
		unsigned long long n = [a length];
		unsigned char buf[64] = { 0 };
		[a copyBytes: buf range: HFRangeMake(0, n)];
		printf("length %llu: %s\n", n, buf);
		return (n == 19 && !strcmp((char *)buf, "ello world, FreeBSD")) ? 0 : 1;
	}
}
