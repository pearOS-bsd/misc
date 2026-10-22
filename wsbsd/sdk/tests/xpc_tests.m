/* NSXPCConnection over a unix socket: a listener and a client in one process (two threads), reply blocks of several signatures, error handler on a missing service, synchronous proxy. */
#import <Foundation/Foundation.h>
#include <stdio.h>
static int failures; static void Check(int ok, const char *what, int line) { if (!ok) { printf("FAIL %s:%d %s\n", __FILE__, line, what); failures++; } }
#define CHECK(c) Check((c), #c, __LINE__)
@protocol Echo
- (void)echo:(NSString *)s reply:(void (^)(NSString *))reply;
- (void)sum:(NSInteger)a with:(NSInteger)b reply:(void (^)(NSInteger, double, BOOL))reply;
- (void)noReply:(NSString *)s;
@end
@interface Service : NSObject <Echo, NSXPCListenerDelegate> { @public NSString *last; } @end
@implementation Service
- (void)echo:(NSString *)s reply:(void (^)(NSString *))reply { reply([s uppercaseString]); }
- (void)sum:(NSInteger)a with:(NSInteger)b reply:(void (^)(NSInteger, double, BOOL))reply { reply(a + b, (double)(a + b) / 2, a > b); }
- (void)noReply:(NSString *)s { last = s; }
- (BOOL)listener:(NSXPCListener *)l shouldAcceptNewConnection:(NSXPCConnection *)c { [c setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(Echo)]]; [c setExportedObject: self]; return YES; }
@end
int main(void)
{
	@autoreleasepool {
		setenv("WSBSD_XPC_DIR", "/tmp/wsbsd-xpc-test", 1);
		Service *svc = [Service new]; NSXPCListener *l = [[NSXPCListener alloc] initWithMachServiceName: @"org.wsbsd.test.echo"]; [l setDelegate: svc]; [l resume];
		NSXPCConnection *c = [[NSXPCConnection alloc] initWithMachServiceName: @"org.wsbsd.test.echo" options: 0]; [c setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(Echo)]]; [c resume];
		__block NSString *got = nil; dispatch_semaphore_t s = dispatch_semaphore_create(0);
		[[c remoteObjectProxy] echo: @"hello" reply: ^(NSString *r) { got = r; dispatch_semaphore_signal(s); }];
		CHECK(dispatch_semaphore_wait(s, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0); CHECK([got isEqualToString: @"HELLO"]);
		__block NSInteger sum = 0; __block double avg = 0; __block BOOL gt = NO;
		[[c synchronousRemoteObjectProxyWithErrorHandler: ^(NSError *e) { printf("error %s\n", [[e description] UTF8String]); }] sum: 7 with: 3 reply: ^(NSInteger x, double y, BOOL z) { sum = x; avg = y; gt = z; }];
		CHECK(sum == 10); CHECK(avg == 5.0); CHECK(gt == YES);
		[[c remoteObjectProxy] noReply: @"ping"]; for (int i = 0; i < 50 && !svc->last; i++) usleep(20000); CHECK([svc->last isEqualToString: @"ping"]);
		NSXPCConnection *bad = [[NSXPCConnection alloc] initWithMachServiceName: @"org.wsbsd.test.missing" options: 0]; [bad setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(Echo)]]; [bad resume];
		__block NSInteger code = 0; [[bad synchronousRemoteObjectProxyWithErrorHandler: ^(NSError *e) { code = [e code]; }] echo: @"x" reply: ^(NSString *r) { }]; CHECK(code == 4097);
		[c invalidate]; [l invalidate];
	}
	printf(failures ? "xpc_tests: %d failures\n" : "xpc_tests: ok\n", failures); return failures != 0;
}
