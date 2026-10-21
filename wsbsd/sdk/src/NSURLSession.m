/* NSURLSession over libcurl: see wsbsd/NSURLSession.h. One curl easy handle per task, run on a background queue; callbacks go to the delegate queue. */
#import <Foundation/Foundation.h>
#if !GS_HAVE_NSURLSESSION
#include <curl/curl.h>
#include <dispatch/dispatch.h>

const int64_t NSURLSessionTransferSizeUnknown = -1;

/* ---- configuration ---- */
@implementation NSURLSessionConfiguration
@synthesize timeoutIntervalForRequest, timeoutIntervalForResource, HTTPAdditionalHeaders, requestCachePolicy, HTTPMaximumConnectionsPerHost, allowsCellularAccess, HTTPShouldSetCookies, waitsForConnectivity, identifier;
+ (NSURLSessionConfiguration *)defaultSessionConfiguration { NSURLSessionConfiguration *c = [self new]; c.timeoutIntervalForRequest = 60; c.timeoutIntervalForResource = 7 * 24 * 3600; c.HTTPMaximumConnectionsPerHost = 6; c.allowsCellularAccess = YES; c.HTTPShouldSetCookies = YES; return c; }
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration { return [self defaultSessionConfiguration]; }
- (id)copyWithZone:(NSZone *)z
{
	NSURLSessionConfiguration *c = [[NSURLSessionConfiguration allocWithZone: z] init]; c.timeoutIntervalForRequest = timeoutIntervalForRequest; c.timeoutIntervalForResource = timeoutIntervalForResource; c.HTTPAdditionalHeaders = HTTPAdditionalHeaders;
	c.requestCachePolicy = requestCachePolicy; c.HTTPMaximumConnectionsPerHost = HTTPMaximumConnectionsPerHost; c.allowsCellularAccess = allowsCellularAccess; c.HTTPShouldSetCookies = HTTPShouldSetCookies; return c;
}
@end

/* ---- tasks ---- */
typedef void (^DataHandler)(NSData *, NSURLResponse *, NSError *);
typedef void (^DownloadHandler)(NSURL *, NSURLResponse *, NSError *);
@interface NSURLSession () { @public NSURLSessionConfiguration *_cfg; NSOperationQueue *_queue; id<NSURLSessionDelegate> _delegate; NSMutableArray *_tasks; BOOL _invalid; NSUInteger _next; } @end
@interface NSURLSessionTask () { @public
	__unsafe_unretained NSURLSession *_session; int _kind; NSData *_body; NSUInteger _id; NSURLRequest *_orig, *_cur; NSURLResponse *_resp; NSError *_err; volatile int _state; volatile int _cancel;
	int64_t _recv, _sent, _expRecv, _expSent; DataHandler _dh; DownloadHandler _dlh; NSString *_desc; float _prio; }
- (void)start;
- (void)transfer;
- (void)finishWithError:(NSError *)e data:(NSData *)d location:(NSURL *)loc;
@end
@implementation NSURLSessionTask
@synthesize taskDescription = _desc, priority = _prio;
- (NSUInteger)taskIdentifier { return _id; } - (NSURLRequest *)originalRequest { return _orig; } - (NSURLRequest *)currentRequest { return _cur; } - (NSURLResponse *)response { return _resp; } - (NSError *)error { return _err; }
- (NSURLSessionTaskState)state { return (NSURLSessionTaskState)_state; }
- (int64_t)countOfBytesReceived { return _recv; } - (int64_t)countOfBytesSent { return _sent; } - (int64_t)countOfBytesExpectedToReceive { return _expRecv; } - (int64_t)countOfBytesExpectedToSend { return _expSent; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)resume { @synchronized (self) { if (_state != NSURLSessionTaskStateSuspended) return; _state = NSURLSessionTaskStateRunning; } [self start]; }
- (void)suspend {}
- (void)cancel { _cancel = 1; @synchronized (self) { if (_state == NSURLSessionTaskStateSuspended) { _state = NSURLSessionTaskStateCanceling; [self finishWithError: [NSError errorWithDomain: NSURLErrorDomain code: NSURLErrorCancelled userInfo: nil] data: nil location: nil]; } else if (_state == NSURLSessionTaskStateRunning) _state = NSURLSessionTaskStateCanceling; } }
@end
@implementation NSURLSessionDataTask @end
@implementation NSURLSessionUploadTask @end
@implementation NSURLSessionDownloadTask @end

/* ---- the transfer ---- */
typedef struct { __unsafe_unretained NSURLSessionTask *task; __unsafe_unretained NSMutableData *buf; FILE *dl; __unsafe_unretained NSMutableDictionary *headers; int status; char version[16]; int headersDone; int delivered; int aborted;
	__unsafe_unretained NSURL *url; } Xfer;

static NSURLSessionTask *Make(NSURLSession *s, int kind, NSURLRequest *r, NSData *body)
{
	NSURLSessionTask *t = [kind == 0 ? [NSURLSessionDataTask alloc] : kind == 1 ? [NSURLSessionUploadTask alloc] : [NSURLSessionDownloadTask alloc] init];
	t->_session = s; t->_kind = kind; t->_orig = [r copy]; t->_cur = t->_orig; t->_body = body ?: [r HTTPBody]; t->_state = NSURLSessionTaskStateSuspended; t->_expRecv = t->_expSent = NSURLSessionTransferSizeUnknown; if (t->_body) t->_expSent = (int64_t)[t->_body length];
	@synchronized (s) { t->_id = ++s->_next; [s->_tasks addObject: t]; } return t;
}
static NSError *CurlError(CURLcode rc, NSURL *url, const char *msg)
{
	NSInteger code = NSURLErrorUnknown;
	switch (rc) { case CURLE_COULDNT_RESOLVE_HOST: case CURLE_COULDNT_RESOLVE_PROXY: code = NSURLErrorCannotFindHost; break; case CURLE_COULDNT_CONNECT: code = NSURLErrorCannotConnectToHost; break; case CURLE_OPERATION_TIMEDOUT: code = NSURLErrorTimedOut; break;
		case CURLE_SSL_CONNECT_ERROR: case CURLE_PEER_FAILED_VERIFICATION: case CURLE_SSL_CERTPROBLEM: case CURLE_SSL_CACERT_BADFILE: code = NSURLErrorSecureConnectionFailed; break; case CURLE_UNSUPPORTED_PROTOCOL: case CURLE_URL_MALFORMAT: code = NSURLErrorUnsupportedURL; break;
		case CURLE_TOO_MANY_REDIRECTS: code = NSURLErrorHTTPTooManyRedirects; break; case CURLE_ABORTED_BY_CALLBACK: case CURLE_WRITE_ERROR: code = NSURLErrorCancelled; break; case CURLE_RECV_ERROR: case CURLE_GOT_NOTHING: code = NSURLErrorNetworkConnectionLost; break; default: break; }
	NSMutableDictionary *u = [NSMutableDictionary dictionary]; u[NSLocalizedDescriptionKey] = [NSString stringWithUTF8String: msg && *msg ? msg : curl_easy_strerror(rc)]; if (url) { u[NSURLErrorFailingURLErrorKey] = url; u[@"NSErrorFailingURLStringKey"] = [url absoluteString]; }
	return [NSError errorWithDomain: NSURLErrorDomain code: code userInfo: u];
}
static NSOperationQueue *Q(NSURLSessionTask *t) { return t->_session->_queue; }
static NSURLResponse *MakeResponse(Xfer *x, double len)
{
	NSHTTPURLResponse *r = [[NSHTTPURLResponse alloc] initWithURL: x->url statusCode: x->status HTTPVersion: [NSString stringWithUTF8String: x->version] headerFields: x->headers];
	x->task->_expRecv = len >= 0 ? (int64_t)len : NSURLSessionTransferSizeUnknown; return r;
}
static size_t HeaderCb(char *p, size_t sz, size_t n, void *ud)
{
	Xfer *x = ud; size_t len = sz * n; NSString *line = [[NSString alloc] initWithBytes: p length: len encoding: NSISOLatin1StringEncoding]; if (!line) return len;
	if ([line hasPrefix: @"HTTP/"]) { [x->headers removeAllObjects]; x->headersDone = 0; NSArray *f = [[line stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString: @" "];
		strlcpy(x->version, [[f[0] substringFromIndex: 5] UTF8String], sizeof x->version); x->status = f.count > 1 ? [f[1] intValue] : 0; return len; }
	NSString *t = [line stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (![t length]) { x->headersDone = 1; return len; }
	NSRange c = [t rangeOfString: @":"]; if (c.location != NSNotFound) { NSString *k = [t substringToIndex: c.location], *v = [[t substringFromIndex: c.location + 1] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
		NSString *old = x->headers[k]; x->headers[k] = old ? [NSString stringWithFormat: @"%@, %@", old, v] : v; }
	return len;
}
/* the response reaches the data delegate once, before the first byte; it may answer with Cancel */
static int Deliver(Xfer *x, CURL *c)
{
	if (x->delivered) return 1; x->delivered = 1; double len = -1; curl_easy_getinfo(c, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &len);
	NSURLSessionTask *t = x->task; t->_resp = MakeResponse(x, len); id d = t->_session->_delegate;
	if (t->_kind != 2 && !t->_dh && [d respondsToSelector: @selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
		__block NSURLSessionResponseDisposition disp = NSURLSessionResponseAllow; dispatch_semaphore_t sem = dispatch_semaphore_create(0); NSURLSession *s = t->_session; NSURLResponse *r = t->_resp;
		[Q(t) addOperationWithBlock: ^{ [(id<NSURLSessionDataDelegate>)d URLSession: s dataTask: (NSURLSessionDataTask *)t didReceiveResponse: r completionHandler: ^(NSURLSessionResponseDisposition v) { disp = v; dispatch_semaphore_signal(sem); }]; }];
		dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); if (disp == NSURLSessionResponseCancel) { x->aborted = 1; return 0; }
	}
	return 1;
}
static size_t WriteCb(char *p, size_t sz, size_t n, void *ud)
{
	Xfer *x = ud; size_t len = sz * n; NSURLSessionTask *t = x->task; CURL *c = NULL; (void)c;
	if (t->_cancel) return 0;
	if (x->status >= 300 && x->status < 400 && [x->headers[@"Location"] length] && [t->_session->_delegate respondsToSelector: @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) return len;       /* a redirect the delegate decides on: its body is dropped */
	t->_recv += (int64_t)len;
	if (t->_kind == 2) { if (x->dl && fwrite(p, 1, len, x->dl) != len) return 0; return len; }
	if (t->_dh) { [x->buf appendBytes: p length: len]; return len; }
	id d = t->_session->_delegate; if ([d respondsToSelector: @selector(URLSession:dataTask:didReceiveData:)]) { NSData *chunk = [NSData dataWithBytes: p length: len]; NSURLSession *s = t->_session;
		[Q(t) addOperationWithBlock: ^{ [(id<NSURLSessionDataDelegate>)d URLSession: s dataTask: (NSURLSessionDataTask *)t didReceiveData: chunk]; }]; }
	return len;
}
static int ProgressCb(void *ud, curl_off_t dt, curl_off_t dn, curl_off_t ut, curl_off_t un) { Xfer *x = ud; x->task->_sent = (int64_t)un; return x->task->_cancel ? 1 : 0; }
static size_t FirstByteCb(char *p, size_t sz, size_t n, void *ud);

@implementation NSURLSessionTask (Run)
- (void)finishWithError:(NSError *)e data:(NSData *)d location:(NSURL *)loc
{
	NSURLSession *s = _session; _err = e; _state = NSURLSessionTaskStateCompleted; NSURLResponse *r = _resp; id del = s->_delegate;
	void (^done)(void) = ^{ @synchronized (s) { [s->_tasks removeObject: self]; BOOL last = s->_invalid && s->_tasks.count == 0; if (last && [del respondsToSelector: @selector(URLSession:didBecomeInvalidWithError:)]) [del URLSession: s didBecomeInvalidWithError: nil]; } };
	if (_dh) { DataHandler h = _dh; [Q(self) addOperationWithBlock: ^{ h(e ? nil : d, r, e); done(); }]; return; }
	if (_dlh) { DownloadHandler h = _dlh; [Q(self) addOperationWithBlock: ^{ h(e ? nil : loc, r, e); done(); }]; return; }
	[Q(self) addOperationWithBlock: ^{
		if (!e && loc && [del respondsToSelector: @selector(URLSession:downloadTask:didFinishDownloadingToURL:)]) [(id<NSURLSessionDownloadDelegate>)del URLSession: s downloadTask: (NSURLSessionDownloadTask *)self didFinishDownloadingToURL: loc];
		if ([del respondsToSelector: @selector(URLSession:task:didCompleteWithError:)]) [(id<NSURLSessionTaskDelegate>)del URLSession: s task: self didCompleteWithError: e];
		done(); }];
}
- (void)start { dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self transfer]; }); }
- (void)transfer
{
	NSURLRequest *req = _orig; NSURLSessionConfiguration *cfg = _session->_cfg; NSData *body = _body; NSString *method = [req HTTPMethod] ?: @"GET"; int hops = 0; NSData *result = nil; NSURL *loc = nil; NSError *err = nil;
	CURL *c = curl_easy_init(); id d = _session->_delegate; BOOL askRedirect = [d respondsToSelector: @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)];
	char ebuf[CURL_ERROR_SIZE] = ""; NSMutableData *buf = [NSMutableData data]; NSString *tmp = nil;
	for (;;) {
		NSMutableDictionary *hd = [NSMutableDictionary dictionary]; Xfer x = { 0 }; x.task = self; x.buf = buf; x.headers = hd; x.url = [req URL]; strlcpy(x.version, "1.1", sizeof x.version);
		if (_kind == 2) { tmp = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"CFNetworkDownload_%u.tmp", arc4random()]]; x.dl = fopen([tmp fileSystemRepresentation], "wb"); }
		curl_easy_reset(c); curl_easy_setopt(c, CURLOPT_URL, [[[req URL] absoluteString] UTF8String]); curl_easy_setopt(c, CURLOPT_ERRORBUFFER, ebuf); curl_easy_setopt(c, CURLOPT_NOSIGNAL, 1L);
		curl_easy_setopt(c, CURLOPT_FOLLOWLOCATION, askRedirect ? 0L : 1L); curl_easy_setopt(c, CURLOPT_MAXREDIRS, 20L); curl_easy_setopt(c, CURLOPT_ACCEPT_ENCODING, "");
		curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT_MS, (long)(([req timeoutInterval] > 0 ? [req timeoutInterval] : cfg.timeoutIntervalForRequest) * 1000)); curl_easy_setopt(c, CURLOPT_LOW_SPEED_LIMIT, 1L); curl_easy_setopt(c, CURLOPT_LOW_SPEED_TIME, (long)(cfg.timeoutIntervalForRequest ?: 60));
		curl_easy_setopt(c, CURLOPT_TIMEOUT_MS, (long)(cfg.timeoutIntervalForResource * 1000));
		curl_easy_setopt(c, CURLOPT_HEADERFUNCTION, HeaderCb); curl_easy_setopt(c, CURLOPT_HEADERDATA, &x); curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, WriteCb); curl_easy_setopt(c, CURLOPT_WRITEDATA, &x);
		curl_easy_setopt(c, CURLOPT_XFERINFOFUNCTION, ProgressCb); curl_easy_setopt(c, CURLOPT_XFERINFODATA, &x); curl_easy_setopt(c, CURLOPT_NOPROGRESS, 0L);
		struct curl_slist *hl = NULL; NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary: cfg.HTTPAdditionalHeaders ?: @{}]; [h addEntriesFromDictionary: [req allHTTPHeaderFields] ?: @{}];
		BOOL ua = NO; for (NSString *k in h) { if ([[k lowercaseString] isEqual: @"user-agent"]) ua = YES; hl = curl_slist_append(hl, [[NSString stringWithFormat: @"%@: %@", k, h[k]] UTF8String]); }
		if (!ua) curl_easy_setopt(c, CURLOPT_USERAGENT, "wsbsd-urlsession"); if (hl) curl_easy_setopt(c, CURLOPT_HTTPHEADER, hl);
		if ([method isEqual: @"HEAD"]) curl_easy_setopt(c, CURLOPT_NOBODY, 1L);
		else if (body && [body length]) { curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, [method UTF8String]); curl_easy_setopt(c, CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)[body length]); curl_easy_setopt(c, CURLOPT_COPYPOSTFIELDS, [body bytes]); }
		else if (![method isEqual: @"GET"]) curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, [method UTF8String]);
		_cur = req; CURLcode rc = curl_easy_perform(c); if (hl) curl_slist_free_all(hl); if (x.dl) { fclose(x.dl); x.dl = NULL; }
		long code = 0; curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, &code); x.status = (int)code;
		if (rc == CURLE_OK || (rc == CURLE_WRITE_ERROR && !x.aborted && !_cancel)) { if (!x.delivered && !Deliver(&x, c)) rc = CURLE_ABORTED_BY_CALLBACK; }
		if (rc == CURLE_OK && askRedirect && code >= 300 && code < 400 && x.headers[@"Location"] && hops++ < 20) {
			NSURL *next = [NSURL URLWithString: x.headers[@"Location"] relativeToURL: [req URL]]; NSMutableURLRequest *nr = [req mutableCopy]; [nr setURL: [next absoluteURL]];
			if (code == 303 || ((code == 301 || code == 302) && ![method isEqual: @"GET"] && ![method isEqual: @"HEAD"])) { [nr setHTTPMethod: @"GET"]; [nr setHTTPBody: nil]; body = nil; method = @"GET"; }
			NSHTTPURLResponse *rr = (NSHTTPURLResponse *)MakeResponse(&x, -1); __block NSURLRequest *answer = nil; dispatch_semaphore_t sem = dispatch_semaphore_create(0); NSURLSession *s = _session;
			[Q(self) addOperationWithBlock: ^{ [(id<NSURLSessionTaskDelegate>)d URLSession: s task: self willPerformHTTPRedirection: rr newRequest: nr completionHandler: ^(NSURLRequest *n) { answer = n; dispatch_semaphore_signal(sem); }]; }];
			dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); if (tmp) [[NSFileManager defaultManager] removeItemAtPath: tmp error: NULL];
			if (answer) { req = answer; [buf setLength: 0]; _recv = 0; continue; }                                       /* nil: the redirect is not followed, its response is the result */
			_resp = rr; if (_kind != 2) result = [buf copy];
			break;
		}
		if (rc != CURLE_OK) err = CurlError(_cancel || x.aborted ? CURLE_ABORTED_BY_CALLBACK : rc, [req URL], ebuf);
		else { if (!_resp) _resp = MakeResponse(&x, -1); if (_kind == 2) loc = [NSURL fileURLWithPath: tmp]; else result = [buf copy]; }
		if (err && tmp) [[NSFileManager defaultManager] removeItemAtPath: tmp error: NULL];
		break;
	}
	curl_easy_cleanup(c); [self finishWithError: err data: result location: loc];
}
@end

/* ---- session ---- */
@implementation NSURLSession
@synthesize sessionDescription;
+ (NSURLSession *)sharedSession { static NSURLSession *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [self sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration] delegate: nil delegateQueue: nil]; }); return s; }
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)c { return [self sessionWithConfiguration: c delegate: nil delegateQueue: nil]; }
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)c delegate:(id<NSURLSessionDelegate>)d delegateQueue:(NSOperationQueue *)q
{
	NSURLSession *s = [self new]; s->_cfg = [c copy]; s->_delegate = d; s->_tasks = [NSMutableArray array];
	if (q) s->_queue = q; else { s->_queue = [NSOperationQueue new]; s->_queue.maxConcurrentOperationCount = 1; } curl_global_init(CURL_GLOBAL_DEFAULT); return s;
}
- (NSURLSessionConfiguration *)configuration { return [_cfg copy]; } - (NSOperationQueue *)delegateQueue { return _queue; } - (id<NSURLSessionDelegate>)delegate { return _delegate; }
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)r { return (NSURLSessionDataTask *)Make(self, 0, r, nil); }
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)u { return [self dataTaskWithRequest: [NSURLRequest requestWithURL: u]]; }
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)r completionHandler:(DataHandler)h { NSURLSessionTask *t = Make(self, 0, r, nil); t->_dh = [h copy]; return (NSURLSessionDataTask *)t; }
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)u completionHandler:(DataHandler)h { return [self dataTaskWithRequest: [NSURLRequest requestWithURL: u] completionHandler: h]; }
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)r fromData:(NSData *)b { return (NSURLSessionUploadTask *)Make(self, 1, r, b); }
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)r fromData:(NSData *)b completionHandler:(DataHandler)h { NSURLSessionTask *t = Make(self, 1, r, b); t->_dh = [h copy]; return (NSURLSessionUploadTask *)t; }
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)r fromFile:(NSURL *)f completionHandler:(DataHandler)h { return [self uploadTaskWithRequest: r fromData: [NSData dataWithContentsOfURL: f] ?: [NSData data] completionHandler: h]; }
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)r { return (NSURLSessionDownloadTask *)Make(self, 2, r, nil); }
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)u { return [self downloadTaskWithRequest: [NSURLRequest requestWithURL: u]]; }
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)r completionHandler:(DownloadHandler)h { NSURLSessionTask *t = Make(self, 2, r, nil); t->_dlh = [h copy]; return (NSURLSessionDownloadTask *)t; }
- (void)finishTasksAndInvalidate { @synchronized (self) { _invalid = YES; if (!_tasks.count && [_delegate respondsToSelector: @selector(URLSession:didBecomeInvalidWithError:)]) { id d = _delegate; [_queue addOperationWithBlock: ^{ [d URLSession: self didBecomeInvalidWithError: nil]; }]; } } }
- (void)invalidateAndCancel { NSArray *a; @synchronized (self) { _invalid = YES; a = [_tasks copy]; } for (NSURLSessionTask *t in a) [t cancel]; }
- (void)getTasksWithCompletionHandler:(void (^)(NSArray *, NSArray *, NSArray *))h
{
	NSMutableArray *d = [NSMutableArray array], *u = [NSMutableArray array], *l = [NSMutableArray array]; @synchronized (self) { for (NSURLSessionTask *t in _tasks) [(t->_kind == 0 ? d : t->_kind == 1 ? u : l) addObject: t]; } h(d, u, l);
}
@end
#endif
