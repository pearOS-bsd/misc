/* NSURLSession over libcurl against a local HTTP server: data task with completion handler, delegate callbacks, upload, redirect, download, error and cancel */
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <sys/wait.h>
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface Del : NSObject <NSURLSessionDataDelegate> { @public NSMutableData *got; int responses, completes; NSError *err; BOOL cancelResponse; } @end
@implementation Del
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))h { responses++; h(cancelResponse ? NSURLSessionResponseCancel : NSURLSessionResponseAllow); }
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d { if (!got) got = [NSMutableData data]; [got appendData: d]; }
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e { completes++; err = e; }
@end
static void spin(BOOL (^done)(void)) { for (int i = 0; i < 200 && !done(); i++) [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]]; }
int main(void)
{
	@autoreleasepool {
		char dir[] = "/tmp/wsbsd-net-XXXXXX"; CHECK(mkdtemp(dir) != NULL); NSString *d = [NSString stringWithUTF8String: dir];
		[@"hello from the server" writeToFile: [d stringByAppendingPathComponent: @"hello.txt"] atomically: YES encoding: NSUTF8StringEncoding error: NULL];
		NSString *srv = [NSString stringWithFormat: @"cd %@ && python3 -m http.server 18765 --bind 127.0.0.1 >/dev/null 2>&1 & echo $! > %@/pid; sleep 1", d, d]; system([srv UTF8String]);
		NSURL *u = [NSURL URLWithString: @"http://127.0.0.1:18765/hello.txt"];
		NSURLSession *s = [NSURLSession sharedSession]; __block NSData *data = nil; __block NSURLResponse *resp = nil; __block NSError *err = nil; __block BOOL fin = NO;
		[[s dataTaskWithRequest: [NSURLRequest requestWithURL: u] completionHandler: ^(NSData *dt, NSURLResponse *r, NSError *e) { data = dt; resp = r; err = e; fin = YES; }] resume];
		spin(^BOOL{ return fin; }); CHECK(fin && !err && [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] isEqual: @"hello from the server"]);
		CHECK([resp isKindOfClass: [NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)resp statusCode] == 200 && [(NSHTTPURLResponse *)resp allHeaderFields][@"Content-Length"] != nil);
		/* 404 is a response, not an error */
		fin = NO; [[s dataTaskWithURL: [NSURL URLWithString: @"http://127.0.0.1:18765/nope"] completionHandler: ^(NSData *dt, NSURLResponse *r, NSError *e) { resp = r; err = e; fin = YES; }] resume];
		spin(^BOOL{ return fin; }); CHECK(!err && [(NSHTTPURLResponse *)resp statusCode] == 404);
		/* connection refused is an error */
		fin = NO; [[s dataTaskWithURL: [NSURL URLWithString: @"http://127.0.0.1:1/"] completionHandler: ^(NSData *dt, NSURLResponse *r, NSError *e) { err = e; fin = YES; }] resume];
		spin(^BOOL{ return fin; }); CHECK(err && [[err domain] isEqual: NSURLErrorDomain] && [err code] == NSURLErrorCannotConnectToHost);
		/* delegate: response, data, completion */
		Del *dl = [Del new]; NSURLSession *s2 = [NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration] delegate: dl delegateQueue: [NSOperationQueue mainQueue]];
		NSURLSessionDataTask *t = [s2 dataTaskWithURL: u]; [t resume]; spin(^BOOL{ return dl->completes > 0; });
		CHECK(dl->responses == 1 && dl->completes == 1 && !dl->err && [dl->got length] == 21 && [t state] == NSURLSessionTaskStateCompleted && [t countOfBytesReceived] == 21);
		/* delegate cancels the response */
		Del *dc = [Del new]; dc->cancelResponse = YES; NSURLSession *s3 = [NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration] delegate: dc delegateQueue: [NSOperationQueue mainQueue]];
		[[s3 dataTaskWithURL: u] resume]; spin(^BOOL{ return dc->completes > 0; }); CHECK(dc->err && [dc->err code] == NSURLErrorCancelled);
		/* upload (the python server answers POST with 501: the status is delivered) */
		NSMutableURLRequest *post = [NSMutableURLRequest requestWithURL: u]; [post setHTTPMethod: @"POST"]; fin = NO;
		[[s uploadTaskWithRequest: post fromData: [@"payload" dataUsingEncoding: NSUTF8StringEncoding] completionHandler: ^(NSData *dt, NSURLResponse *r, NSError *e) { resp = r; err = e; fin = YES; }] resume];
		spin(^BOOL{ return fin; }); CHECK(!err && [(NSHTTPURLResponse *)resp statusCode] == 501);
		/* download to a file */
		__block NSURL *loc = nil; fin = NO; [[s downloadTaskWithRequest: [NSURLRequest requestWithURL: u] completionHandler: ^(NSURL *l, NSURLResponse *r, NSError *e) { loc = l; err = e; fin = YES; }] resume];
		spin(^BOOL{ return fin; }); CHECK(!err && loc && [[NSString stringWithContentsOfURL: loc encoding: NSUTF8StringEncoding error: NULL] isEqual: @"hello from the server"]);
		/* redirect: a directory without a slash answers 301 to the slash form */
		[[NSFileManager defaultManager] createDirectoryAtPath: [d stringByAppendingPathComponent: @"sub"] withIntermediateDirectories: YES attributes: nil error: NULL]; [@"in sub" writeToFile: [d stringByAppendingPathComponent: @"sub/index.html"] atomically: YES encoding: NSUTF8StringEncoding error: NULL];
		fin = NO; [[s dataTaskWithURL: [NSURL URLWithString: @"http://127.0.0.1:18765/sub"] completionHandler: ^(NSData *dt, NSURLResponse *r, NSError *e) { data = dt; resp = r; err = e; fin = YES; }] resume];
		spin(^BOOL{ return fin; }); CHECK(!err && [(NSHTTPURLResponse *)resp statusCode] == 200 && [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] isEqual: @"in sub"]);
		/* cancel before the answer */
		NSURLSessionDataTask *ct = [s dataTaskWithURL: u completionHandler: ^(NSData *dt, NSURLResponse *r, NSError *e) { err = e; fin = YES; }]; fin = NO; err = nil; [ct resume]; [ct cancel]; spin(^BOOL{ return fin; }); CHECK(err && [err code] == NSURLErrorCancelled);
		system([[NSString stringWithFormat: @"kill $(cat %@/pid) 2>/dev/null", d] UTF8String]);
	}
	printf(fails ? "net_tests: %d failed\n" : "net_tests: ok\n", fails); return fails != 0;
}
