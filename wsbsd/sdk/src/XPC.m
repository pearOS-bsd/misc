/* NSXPCConnection / NSXPCListener / NSXPCInterface for FreeBSD. One unix socket per mach service name in WSBSD_XPC_DIR (default /var/run/xpc). Messages are length-prefixed NSKeyedArchiver
 * dictionaries. A call carries the selector, the archived arguments and, when the last argument is a block, the signature of that block: the server rebuilds a block of that signature (a libffi closure)
 * that sends the reply, the client invokes its own block with the decoded reply (ffi_call). The behaviour follows Apple's: interruption on a lost peer, error handlers of the proxies, currentConnection. */
#import <Foundation/Foundation.h>
#import <wsbsd/NSXPCConnection.h>
#import <Foundation/NSXPCConnection.h>
#import <objc/runtime.h>
#include <ffi.h>
#include <dispatch/dispatch.h>
#include <sys/socket.h>
#include <poll.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/ucred.h>
#include <pthread.h>
#include <unistd.h>
#include <errno.h>

/* ---- blocks: layout, signature, calling, building ---- */
struct WsBlock { void *isa; int flags; int reserved; void *invoke; struct WsBlockDesc *descriptor; };
struct WsBlockDesc { unsigned long reserved; unsigned long size; const char *signature; };
extern void *_NSConcreteGlobalBlock[32];
static const char *BlockSignature(id block)
{
	struct WsBlock *b = (__bridge struct WsBlock *)block; if (!(b->flags & (1 << 30))) return NULL;
	const char *p = (const char *)b->descriptor + 2 * sizeof(unsigned long); if (b->flags & (1 << 25)) p += 2 * sizeof(void *);
	return *(const char **)p;
}
/* blocking loops (read, accept) get their own thread: the worker pool of libdispatch is small and a loop that blocks in read(2) would starve the next one */
static void *ThreadMain(void *arg) { @autoreleasepool { void (^b)(void) = (__bridge_transfer void (^)(void))arg; b(); } return NULL; }
static void RunDetached(void (^block)(void)) { pthread_t t; pthread_attr_t a; pthread_attr_init(&a); pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED); pthread_create(&t, &a, ThreadMain, (__bridge_retained void *)[block copy]); pthread_attr_destroy(&a); }
static BOOL IsBlock(id o) { if (!o) return NO; const char *n = class_getName(object_getClass(o)); return strstr(n, "Block") != NULL; }
static ffi_type *FfiFor(const char *t)
{
	while (*t && strchr("rnNoORV", *t)) t++;
	switch (*t) {
	case 'c': return &ffi_type_schar; case 'C': case 'B': return &ffi_type_uchar; case 's': return &ffi_type_sshort; case 'S': return &ffi_type_ushort;
	case 'i': return &ffi_type_sint; case 'I': return &ffi_type_uint; case 'l': case 'q': return &ffi_type_sint64; case 'L': case 'Q': return &ffi_type_uint64;
	case 'f': return &ffi_type_float; case 'd': return &ffi_type_double; case 'v': return &ffi_type_void; default: return &ffi_type_pointer;
	}
}
static NSString *const kDomain = @"NSCocoaErrorDomain";
static NSError *XPCError(NSInteger code) { return [NSError errorWithDomain: kDomain code: code userInfo: nil]; }   /* 4097 interrupted, 4099 invalid, 4101 reply invalid */

/* value <-> archivable object, by type encoding */
static id Boxed(const char *t, const void *p)
{
	while (*t && strchr("rnNoORV", *t)) t++;
	switch (*t) {
	case '@': { id o = (__bridge id)*(void *const *)p; return o ?: [NSNull null]; }
	case '#': { Class c = *(Class const *)p; return c ? NSStringFromClass(c) : [NSNull null]; }
	case ':': { SEL s = *(SEL const *)p; return s ? NSStringFromSelector(s) : [NSNull null]; }
	case '*': { const char *c = *(const char *const *)p; return c ? @(c) : [NSNull null]; }
	case 'c': return @(*(const signed char *)p); case 'C': return @(*(const unsigned char *)p); case 'B': return @(*(const unsigned char *)p != 0);
	case 's': return @(*(const short *)p); case 'S': return @(*(const unsigned short *)p); case 'i': return @(*(const int *)p); case 'I': return @(*(const unsigned *)p);
	case 'l': return @(*(const long *)p); case 'L': return @(*(const unsigned long *)p); case 'q': return @(*(const long long *)p); case 'Q': return @(*(const unsigned long long *)p);
	case 'f': return @(*(const float *)p); case 'd': return @(*(const double *)p);
	}
	return [NSNull null];
}
static void Unbox(const char *t, id o, void *p, NSMutableArray *keep)
{
	while (*t && strchr("rnNoORV", *t)) t++;
	if (o == [NSNull null]) o = nil;
	switch (*t) {
	case '@': { if (o) [keep addObject: o]; *(void **)p = (__bridge void *)o; return; }
	case '#': *(Class *)p = o ? NSClassFromString(o) : Nil; return;
	case ':': *(SEL *)p = o ? NSSelectorFromString(o) : NULL; return;
	case '*': { NSData *d = o ? [[o dataUsingEncoding: NSUTF8StringEncoding] mutableCopy] : nil; if (d) { NSMutableData *m = [NSMutableData dataWithData: d]; [m appendBytes: "" length: 1]; [keep addObject: m]; *(const char **)p = [m bytes]; } else *(const char **)p = NULL; return; }
	case 'c': *(signed char *)p = [o charValue]; return; case 'C': *(unsigned char *)p = [o unsignedCharValue]; return; case 'B': *(unsigned char *)p = [o boolValue]; return;
	case 's': *(short *)p = [o shortValue]; return; case 'S': *(unsigned short *)p = [o unsignedShortValue]; return; case 'i': *(int *)p = [o intValue]; return; case 'I': *(unsigned *)p = [o unsignedIntValue]; return;
	case 'l': *(long *)p = [o longValue]; return; case 'L': *(unsigned long *)p = [o unsignedLongValue]; return; case 'q': *(long long *)p = [o longLongValue]; return; case 'Q': *(unsigned long long *)p = [o unsignedLongLongValue]; return;
	case 'f': *(float *)p = [o floatValue]; return; case 'd': *(double *)p = [o doubleValue]; return;
	}
}

/* ---- framing ---- */
static BOOL WriteAll(int fd, const void *b, size_t n) { const char *p = b; while (n) { ssize_t w = write(fd, p, n); if (w < 0) { if (errno == EINTR) continue; return NO; } p += w; n -= w; } return YES; }
static BOOL ReadAll(int fd, void *b, size_t n) { char *p = b; while (n) { ssize_t r = read(fd, p, n); if (r < 0 && errno == EINTR) continue; if (r <= 0) return NO; p += r; n -= r; } return YES; }
static NSString *XPCDir(void) { const char *e = getenv("WSBSD_XPC_DIR"); return e ? @(e) : @"/var/run/xpc"; }
static int ConnectPath(NSString *path)
{
	int fd = socket(AF_UNIX, SOCK_STREAM, 0); struct sockaddr_un a = { .sun_family = AF_UNIX }; strlcpy(a.sun_path, [path fileSystemRepresentation], sizeof a.sun_path);
	if (connect(fd, (struct sockaddr *)&a, sizeof a) != 0) { close(fd); return -1; } return fd;
}

/* ---- NSXPCInterface ---- */
@interface WsXPCInterface : NSObject
+ (WsXPCInterface *)interfaceWithProtocol:(Protocol *)p;
- (const char *)typesForSelector:(SEL)s;
@end
@implementation WsXPCInterface { NSMutableDictionary *_classes, *_ifaces; Protocol *_proto; }
+ (WsXPCInterface *)interfaceWithProtocol:(Protocol *)p { WsXPCInterface *i = [self new]; i->_proto = p; i->_classes = [NSMutableDictionary new]; i->_ifaces = [NSMutableDictionary new]; return i; }
- (Protocol *)protocol { return _proto; } - (void)setProtocol:(Protocol *)p { _proto = p; }
static NSString *Key(SEL s, NSUInteger a, BOOL r) { return [NSString stringWithFormat: @"%s/%lu/%d", sel_getName(s), (unsigned long)a, r]; }
- (void)setClasses:(NSSet *)c forSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { _classes[Key(s, a, r)] = c; }
- (NSSet *)classesForSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { return _classes[Key(s, a, r)]; }
- (void)setInterface:(id)i forSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { _ifaces[Key(s, a, r)] = i; }
- (id)interfaceForSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { return _ifaces[Key(s, a, r)]; }
static const char *FindTypes(Protocol *p, SEL s, int depth)
{
	for (int req = 1; req >= 0; req--) { struct objc_method_description d = protocol_getMethodDescription(p, s, req, YES); if (d.name) return d.types; }
	if (depth > 8) return NULL;
	unsigned n = 0; Protocol * __unsafe_unretained *adopted = protocol_copyProtocolList(p, &n); const char *r = NULL;
	for (unsigned i = 0; i < n && !r; i++) r = FindTypes(adopted[i], s, depth + 1);
	free(adopted); return r;
}
- (const char *)typesForSelector:(SEL)s { return FindTypes(_proto, s, 0); }
@end

@implementation NSXPCListenerEndpoint (Wsbsd)
static const char kEndpointPath;
- (NSString *)wsbsdPath { return objc_getAssociatedObject(self, &kEndpointPath); }
- (void)setWsbsdPath:(NSString *)p { objc_setAssociatedObject(self, &kEndpointPath, p, OBJC_ASSOCIATION_COPY); }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: [self wsbsdPath] forKey: @"path"]; }
- (instancetype)initWithCoder:(NSCoder *)c { if ((self = [super init])) [self setWsbsdPath: [c decodeObjectForKey: @"path"]]; return self; }
@end

/* ---- proxy ---- */
@class WsXPCConnection;
@interface WsXPCProxy : NSProxy { @public __weak WsXPCConnection *_conn; void (^_errorHandler)(NSError *); BOOL _sync; } @end
@interface WsXPCConnection : NSObject
@property (strong) WsXPCInterface *exportedInterface, *remoteObjectInterface; @property (strong) id exportedObject; @property (copy) void (^interruptionHandler)(void), (^invalidationHandler)(void); @property (weak) NSXPCConnection *facade; @property (strong) id exportedIfaceFacade, remoteIfaceFacade;
- (instancetype)initWithPath:(NSString *)path name:(NSString *)name;
- (id)_initWithFD:(int)fd;
- (void)_sendInvocation:(NSInvocation *)inv proxy:(WsXPCProxy *)proxy;
- (NSString *)serviceName; - (NSString *)path; - (pid_t)processIdentifier; - (uid_t)effectiveUserIdentifier; - (gid_t)effectiveGroupIdentifier;
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *))h; - (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *))h;
- (void)resume; - (void)suspend; - (void)invalidate; - (void)scheduleSendBarrierBlock:(void (^)(void))b;
@end
@implementation WsXPCProxy
- (NSMethodSignature *)methodSignatureForSelector:(SEL)s
{
	WsXPCInterface *ifc = _conn.remoteObjectInterface; const char *t = ifc ? [ifc typesForSelector: s] : NULL;
	if (!t) { if ([NSObject instancesRespondToSelector: s]) return [NSObject instanceMethodSignatureForSelector: s]; return nil; }
	return [NSMethodSignature signatureWithObjCTypes: t];
}
- (void)forwardInvocation:(NSInvocation *)inv { [_conn _sendInvocation: inv proxy: self]; }             /* the arguments are archived before this returns: retainArguments would retain a stack block */
- (BOOL)respondsToSelector:(SEL)s { return [self methodSignatureForSelector: s] != nil; }
@end

/* ---- connection ---- */
@interface WsXPCPending : NSObject { @public id block; NSString *sig; void (^errorHandler)(NSError *); dispatch_semaphore_t sem; } @end
@implementation WsXPCPending @end
static const char kConnState, kListenerDelegate, kIfaceState;
static pthread_key_t gCurrentKey; static pthread_once_t gOnce = PTHREAD_ONCE_INIT;
static void MakeKey(void) { pthread_key_create(&gCurrentKey, NULL); }

@implementation WsXPCConnection {
	int _fd; NSString *_name, *_path; NSLock *_wlock; NSMutableDictionary *_pending; uint64_t _nextID; dispatch_queue_t _callQ, _replyQ; BOOL _resumed, _invalidated, _server, _eof;
	BOOL _reading; pid_t _pid; uid_t _uid; gid_t _gid; NSMutableArray *_blocks; NSMutableArray<NSData *> *_early;
}
@synthesize exportedInterface, exportedObject, remoteObjectInterface, interruptionHandler, invalidationHandler, facade, exportedIfaceFacade, remoteIfaceFacade;
- (NSString *)serviceName { return _name; } - (NSString *)path { return _path; }
- (void)_setup { pthread_once(&gOnce, MakeKey); _wlock = [NSLock new]; _pending = [NSMutableDictionary new]; _blocks = [NSMutableArray new]; _fd = -1;
	_callQ = dispatch_queue_create("wsbsd.xpc.call", DISPATCH_QUEUE_SERIAL); _replyQ = dispatch_queue_create("wsbsd.xpc.reply", DISPATCH_QUEUE_SERIAL); }
- (instancetype)initWithPath:(NSString *)path name:(NSString *)n { if ((self = [super init])) { [self _setup]; _name = [n copy]; _path = [path copy]; } return self; }
- (id)_initWithFD:(int)fd
{
	if ((self = [super init])) { [self _setup]; _fd = fd; _server = YES;
#ifdef LOCAL_PEERCRED
		struct xucred cr; socklen_t l = sizeof cr; if (getsockopt(fd, 0, LOCAL_PEERCRED, &cr, &l) == 0) { _uid = cr.cr_uid; _gid = cr.cr_ngroups ? cr.cr_groups[0] : 0;
#ifdef __FreeBSD__
			_pid = cr.cr_pid;
#endif
		}
#endif
	}
	return self;
}
- (pid_t)processIdentifier { return _pid; } - (uid_t)effectiveUserIdentifier { return _uid; } - (gid_t)effectiveGroupIdentifier { return _gid; }
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *))h { WsXPCProxy *p = [WsXPCProxy alloc]; p->_conn = self; p->_errorHandler = [h copy]; return p; }
- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *))h { WsXPCProxy *p = [WsXPCProxy alloc]; p->_conn = self; p->_errorHandler = [h copy]; p->_sync = YES; return p; }
- (void)_startReading { @synchronized (self) { if (_reading || _fd < 0 || !_resumed) return; _reading = YES; } RunDetached(^{ [self _readLoop]; }); }
- (void)resume { _resumed = YES; [self _startReading]; }
- (void)suspend { }
- (void)scheduleSendBarrierBlock:(void (^)(void))b { dispatch_async(_callQ, b); }
- (BOOL)_connectIfNeeded { if (_fd >= 0) return YES; if (_server || !_path) return NO; _fd = ConnectPath(_path); [self _startReading]; return _fd >= 0; }
- (void)invalidate
{
	if (_invalidated) return; _invalidated = YES; if (_fd >= 0) { shutdown(_fd, SHUT_RDWR); close(_fd); _fd = -1; }
	NSArray *ps; @synchronized (self) { ps = [_pending allValues]; [_pending removeAllObjects]; }
	for (WsXPCPending *p in ps) { if (p->errorHandler) p->errorHandler(XPCError(4099)); if (p->sem) dispatch_semaphore_signal(p->sem); }
	void (^h)(void) = invalidationHandler; if (h) dispatch_async(_replyQ, h);
}
- (void)_send:(NSDictionary *)msg
{
	NSMutableData *d = [NSMutableData data]; NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initForWritingWithMutableData: d]; [a setRequiresSecureCoding: NO]; [a encodeObject: msg forKey: @"m"]; [a finishEncoding];
	uint32_t n = (uint32_t)[d length]; [_wlock lock]; BOOL ok = _fd >= 0 && WriteAll(_fd, &n, 4) && WriteAll(_fd, [d bytes], n); [_wlock unlock]; (void)ok;
}
- (void)_sendInvocation:(NSInvocation *)inv proxy:(WsXPCProxy *)proxy
{
	WsXPCInterface *ifc = remoteObjectInterface; NSMethodSignature *ms = [inv methodSignature]; NSUInteger n = [ms numberOfArguments];
	NSMutableArray *args = [NSMutableArray array]; id block = nil; const char *blockSig = NULL; int blockIndex = -1;
	for (NSUInteger i = 2; i < n; i++) {
		const char *t = [ms getArgumentTypeAtIndex: i]; char buf[64]; [inv getArgument: buf atIndex: i];
		if (t[0] == '@' && IsBlock((__bridge id)*(void **)buf)) { block = (__bridge id)*(void **)buf; blockSig = BlockSignature(block); blockIndex = (int)i; [args addObject: [NSNull null]]; continue; }
		[args addObject: Boxed(t, buf)];
	}
	(void)ifc;
	void (^fail)(NSInteger) = ^(NSInteger code) { if (getenv("WSBSD_XPC_DEBUG")) fprintf(stderr, "xpc client %s: failed %ld (path %s)\n", [NSStringFromSelector([inv selector]) UTF8String], (long)code, [_path UTF8String]); NSError *e = XPCError(code); if (proxy->_errorHandler) proxy->_errorHandler(e); };
	if (_invalidated) { fail(4099); return; }
	if (![self _connectIfNeeded]) { fail(4097); return; }
	uint64_t cid; WsXPCPending *p = nil;
	@synchronized (self) { cid = ++_nextID; if (block) { p = [WsXPCPending new]; p->block = [block copy]; p->sig = blockSig ? @(blockSig) : nil; p->errorHandler = proxy->_errorHandler; if (proxy->_sync) p->sem = dispatch_semaphore_create(0); _pending[@(cid)] = p; } }
	NSMutableDictionary *m = [@{ @"k": @"call", @"id": @(cid), @"sel": NSStringFromSelector([inv selector]), @"args": args } mutableCopy]; if (blockSig) { m[@"sig"] = @(blockSig); m[@"bi"] = @(blockIndex); }
	[self _send: m];
	if (p && p->sem) dispatch_semaphore_wait(p->sem, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
	else if (!block && proxy->_sync) { /* no reply: a barrier */ }
}
/* the block handed to the exported method: sends the reply */
struct ReplyCtx { void *conn; uint64_t cid; char *sig; };
static void ReplyThunk(ffi_cif *cif, void *ret, void **args, void *user)
{
	struct ReplyCtx *c = user; WsXPCConnection *conn = (__bridge WsXPCConnection *)c->conn; NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes: c->sig];
	NSMutableArray *vals = [NSMutableArray array]; for (NSUInteger i = 1; i < [ms numberOfArguments]; i++) [vals addObject: Boxed([ms getArgumentTypeAtIndex: i], args[i])];
	[conn _send: @{ @"k": @"reply", @"id": @(c->cid), @"args": vals }];
}
- (id)_makeReplyBlock:(uint64_t)cid sig:(NSString *)sig
{
	NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes: [sig UTF8String]]; NSUInteger n = [ms numberOfArguments];
	ffi_cif *cif = calloc(1, sizeof *cif); ffi_type **ats = calloc(n, sizeof(ffi_type *)); ats[0] = &ffi_type_pointer; for (NSUInteger i = 1; i < n; i++) ats[i] = FfiFor([ms getArgumentTypeAtIndex: i]);
	ffi_prep_cif(cif, FFI_DEFAULT_ABI, (unsigned)n, &ffi_type_void, ats);
	void *code; ffi_closure *cl = ffi_closure_alloc(sizeof(ffi_closure), &code); struct ReplyCtx *ctx = calloc(1, sizeof *ctx); ctx->conn = (__bridge void *)self; ctx->cid = cid; ctx->sig = strdup([sig UTF8String]);
	ffi_prep_closure_loc(cl, cif, ReplyThunk, ctx, code);
	struct WsBlockDesc *d = calloc(1, sizeof *d + 8); d->size = sizeof(struct WsBlock); char *dp = (char *)d; *(const char **)(dp + 2 * sizeof(unsigned long)) = ctx->sig;
	struct WsBlock *b = calloc(1, sizeof *b); b->isa = _NSConcreteGlobalBlock; b->flags = (1 << 28) | (1 << 30); b->invoke = code; b->descriptor = d;
	[_blocks addObject: [NSValue valueWithPointer: b]]; return (__bridge id)(void *)b;
}
- (void)_handleCall:(NSDictionary *)m
{
	SEL sel = NSSelectorFromString(m[@"sel"]); id target = exportedObject; WsXPCInterface *ifc = exportedInterface; uint64_t cid = [m[@"id"] unsignedLongLongValue];
	const char *t = ifc ? [ifc typesForSelector: sel] : NULL;
	if (getenv("WSBSD_XPC_DEBUG")) fprintf(stderr, "xpc call %s types=%s target=%s responds=%d\n", sel_getName(sel), t ?: "(none)", target ? class_getName(object_getClass(target)) : "nil", [target respondsToSelector: sel]);
	if (!t || ![target respondsToSelector: sel]) { if (m[@"sig"]) { /* answer nothing: the caller's error handler fires on invalidation only */ } return; }
	NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes: t]; NSInvocation *inv = [NSInvocation invocationWithMethodSignature: ms]; [inv setSelector: sel]; [inv setTarget: target];
	NSArray *args = m[@"args"]; NSMutableArray *keep = [NSMutableArray array];
	for (NSUInteger i = 2; i < [ms numberOfArguments]; i++) {
		const char *at = [ms getArgumentTypeAtIndex: i]; char buf[64] = { 0 };
		if (m[@"sig"] && (int)i == [m[@"bi"] intValue]) { id b = [self _makeReplyBlock: cid sig: m[@"sig"]]; *(void **)buf = (__bridge void *)b; }
		else Unbox(at, i - 2 < [args count] ? args[i - 2] : nil, buf, keep);
		[inv setArgument: buf atIndex: i];
	}
	pthread_setspecific(gCurrentKey, (__bridge void *)(self.facade ?: (NSXPCConnection *)nil)); [inv invoke]; pthread_setspecific(gCurrentKey, NULL);
}
- (void)_handleReply:(NSDictionary *)m
{
	WsXPCPending *p; @synchronized (self) { p = _pending[m[@"id"]]; [_pending removeObjectForKey: m[@"id"]]; } if (!p) return;
	if (p->sig && p->block) {
		NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes: [p->sig UTF8String]]; NSUInteger n = [ms numberOfArguments]; NSArray *vals = m[@"args"]; NSMutableArray *keep = [NSMutableArray array];
		ffi_type **ats = calloc(n, sizeof(ffi_type *)); void **av = calloc(n, sizeof(void *)); void *bp = (__bridge void *)p->block; ats[0] = &ffi_type_pointer; av[0] = &bp;
		for (NSUInteger i = 1; i < n; i++) { const char *at = [ms getArgumentTypeAtIndex: i]; NSUInteger sz, al; NSGetSizeAndAlignment(at, &sz, &al); void *buf = calloc(1, sz < 8 ? 8 : sz); Unbox(at, i - 1 < [vals count] ? vals[i - 1] : nil, buf, keep); av[i] = buf; ats[i] = FfiFor(at); }
		ffi_cif cif; if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned)n, &ffi_type_void, ats) == FFI_OK) ffi_call(&cif, FFI_FN(((struct WsBlock *)bp)->invoke), NULL, av);
		for (NSUInteger i = 1; i < n; i++) free(av[i]); free(av); free(ats);
	}
	if (p->sem) dispatch_semaphore_signal(p->sem);
}
- (void)_readLoop
{
	int fd = _fd;
	for (;;) {
		uint32_t n; if (!ReadAll(fd, &n, 4) || n > (64u << 20)) break; NSMutableData *d = [NSMutableData dataWithLength: n]; if (!ReadAll(fd, [d mutableBytes], n)) break;
		NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData: d]; [u setRequiresSecureCoding: NO]; NSDictionary *m = [u decodeObjectForKey: @"m"]; [u finishDecoding]; if (![m isKindOfClass: [NSDictionary class]]) continue;
		if (getenv("WSBSD_XPC_DEBUG")) fprintf(stderr, "xpc %s fd %d got %s %s\n", _server ? "server" : "client", fd, [[m[@"k"] description] UTF8String], [[m[@"sel"] description] UTF8String]);
		if ([m[@"k"] isEqual: @"call"]) dispatch_async(_callQ, ^{ [self _handleCall: m]; });
		else if ([m[@"k"] isEqual: @"reply"]) dispatch_async(_replyQ, ^{ [self _handleReply: m]; });
	}
	@synchronized (self) { _reading = NO; }
	if (_fd == fd && !_invalidated) {
		close(_fd); _fd = -1;
		NSArray *ps; @synchronized (self) { ps = [_pending allValues]; [_pending removeAllObjects]; }
		for (WsXPCPending *p in ps) { if (p->errorHandler) p->errorHandler(XPCError(4097)); if (p->sem) dispatch_semaphore_signal(p->sem); }
		void (^h)(void) = interruptionHandler; if (h) dispatch_async(_replyQ, h);
		if (_server) { void (^ih)(void) = invalidationHandler; if (ih) dispatch_async(_replyQ, ih); _invalidated = YES; }
	}
}
@end

/* ---- listener ---- */
@interface WsXPCListener : NSObject { @public NSString *_name, *_path; int _fd; __weak NSXPCListener *facade; volatile int *_stop; }
- (void)resume; - (void)invalidate;
@end
@implementation WsXPCListener
- (void)resume
{
	if (_fd >= 0 && _fd != 0) return; [[NSFileManager defaultManager] createDirectoryAtPath: XPCDir() withIntermediateDirectories: YES attributes: @{ NSFilePosixPermissions: @0755 } error: nil];
	unlink([_path fileSystemRepresentation]); _fd = socket(AF_UNIX, SOCK_STREAM, 0); struct sockaddr_un a = { .sun_family = AF_UNIX }; strlcpy(a.sun_path, [_path fileSystemRepresentation], sizeof a.sun_path);
	if (bind(_fd, (struct sockaddr *)&a, sizeof a) != 0 || listen(_fd, 16) != 0) { close(_fd); _fd = -1; return; } chmod([_path fileSystemRepresentation], 0666);
	int lfd = _fd; NSXPCListener *f = facade; volatile int *stop = calloc(1, sizeof(int)); _stop = stop; RunDetached(^{      /* the flag, not the closed descriptor, ends the loop: the number is reused by the next socket */
		for (;;) { struct pollfd pf = { .fd = lfd, .events = POLLIN }; int pr = poll(&pf, 1, 100); if (*stop) break; if (pr <= 0) continue; int c = accept(lfd, NULL, NULL); if (c < 0) { if (errno == EINTR || errno == EAGAIN) continue; break; }
			NSXPCConnection *conn = [[NSXPCConnection alloc] init]; WsXPCConnection *st = [[WsXPCConnection alloc] _initWithFD: c]; st.facade = conn; objc_setAssociatedObject(conn, &kConnState, st, OBJC_ASSOCIATION_RETAIN);
			id<NSXPCListenerDelegate> d = [f delegate];
			if (getenv("WSBSD_XPC_DEBUG")) fprintf(stderr, "xpc accept on %s (fd %d) delegate=%s\n", [_path UTF8String], c, d ? class_getName(object_getClass(d)) : "nil");
			BOOL ok = [d respondsToSelector: @selector(listener:shouldAcceptNewConnection:)] ? [d listener: f shouldAcceptNewConnection: conn] : NO;
			if (getenv("WSBSD_XPC_DEBUG")) fprintf(stderr, "xpc accept: delegate says %d\n", ok);
			if (ok) { [st resume]; } else close(c); }
	});
}
- (void)invalidate { if (_fd > 0) { if (_stop) *_stop = 1; usleep(150000); close(_fd); _fd = -1; unlink([_path fileSystemRepresentation]); } }
@end

/* ---- the classes of gnustep-base are stubs that raise "not implemented": their methods are replaced here, the state lives in the helper objects above ---- */
static WsXPCInterface *IS(NSXPCInterface *i);
static WsXPCConnection *CS(NSXPCConnection *c) { WsXPCConnection *s = objc_getAssociatedObject(c, &kConnState); return s; }
static void Attach(NSXPCConnection *c, WsXPCConnection *s) { s.facade = c; objc_setAssociatedObject(c, &kConnState, s, OBJC_ASSOCIATION_RETAIN); }
@implementation NSXPCConnection (WsbsdXPC)
- (instancetype)initWithServiceName:(NSString *)n { return [self initWithMachServiceName: n options: 0]; }
- (instancetype)initWithMachServiceName:(NSString *)n options:(NSXPCConnectionOptions)o { if ((self = [super init])) Attach(self, [[WsXPCConnection alloc] initWithPath: [XPCDir() stringByAppendingPathComponent: n] name: n]); return self; }
- (instancetype)initWithListenerEndpoint:(NSXPCListenerEndpoint *)e { if ((self = [super init])) Attach(self, [[WsXPCConnection alloc] initWithPath: [e wsbsdPath] name: nil]); return self; }
- (NSString *)serviceName { return [CS(self) serviceName]; }
- (NSXPCListenerEndpoint *)endpoint { NSXPCListenerEndpoint *e = [NSXPCListenerEndpoint new]; [e setWsbsdPath: [CS(self) path]]; return e; }
- (NSXPCInterface *)exportedInterface { return CS(self).exportedIfaceFacade; }
- (void)setExportedInterface:(NSXPCInterface *)i { CS(self).exportedIfaceFacade = i; CS(self).exportedInterface = IS(i); }
- (void)setExportInterface:(NSXPCInterface *)i { [self setExportedInterface: i]; }
- (id)exportedObject { return CS(self).exportedObject; }
- (void)setExportedObject:(id)o { CS(self).exportedObject = o; }
- (NSXPCInterface *)remoteObjectInterface { return CS(self).remoteIfaceFacade; }
- (void)setRemoteObjectInterface:(NSXPCInterface *)i { CS(self).remoteIfaceFacade = i; CS(self).remoteObjectInterface = IS(i); }
- (id)remoteObjectProxy { return [CS(self) remoteObjectProxyWithErrorHandler: nil]; }
- (id)remoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)h { return [CS(self) remoteObjectProxyWithErrorHandler: h]; }
- (id)synchronousRemoteObjectProxyWithErrorHandler:(GSXPCProxyErrorHandler)h { return [CS(self) synchronousRemoteObjectProxyWithErrorHandler: h]; }
- (GSXPCInterruptionHandler)interruptionHandler { return CS(self).interruptionHandler; }
- (void)setInterruptionHandler:(GSXPCInterruptionHandler)h { CS(self).interruptionHandler = h; }
- (GSXPCInvalidationHandler)invalidationHandler { return CS(self).invalidationHandler; }
- (void)setInvalidationHandler:(GSXPCInvalidationHandler)h { CS(self).invalidationHandler = h; }
- (void)resume { [CS(self) resume]; } - (void)suspend { [CS(self) suspend]; } - (void)invalidate { [CS(self) invalidate]; }
- (void)scheduleSendBarrierBlock:(void (^)(void))b { [CS(self) scheduleSendBarrierBlock: b]; }
- (NSUInteger)auditSessionIdentifier { return 0; }
- (pid_t)processIdentifier { return [CS(self) processIdentifier]; } - (uid_t)effectiveUserIdentifier { return [CS(self) effectiveUserIdentifier]; } - (gid_t)effectiveGroupIdentifier { return [CS(self) effectiveGroupIdentifier]; }
+ (NSXPCConnection *)currentConnection { pthread_once(&gOnce, MakeKey); return (__bridge NSXPCConnection *)pthread_getspecific(gCurrentKey); }
@end

static const char kListenerState;
static WsXPCListener *LS(NSXPCListener *l) { return objc_getAssociatedObject(l, &kListenerState); }
@implementation NSXPCListener (WsbsdXPC)
+ (NSXPCListener *)serviceListener { return [[self alloc] initWithMachServiceName: [NSString stringWithFormat: @"service.%@", [[NSProcessInfo processInfo] processName]]]; }
+ (NSXPCListener *)anonymousListener { return [[self alloc] initWithMachServiceName: [@"anonymous." stringByAppendingString: [[NSUUID UUID] UUIDString]]]; }
- (instancetype)initWithMachServiceName:(NSString *)n { if ((self = [super init])) { WsXPCListener *l = [WsXPCListener new]; l->_name = [n copy]; l->_path = [XPCDir() stringByAppendingPathComponent: n]; l->_fd = -1; l->facade = self; objc_setAssociatedObject(self, &kListenerState, l, OBJC_ASSOCIATION_RETAIN); } return self; }
- (id<NSXPCListenerDelegate>)delegate { return objc_getAssociatedObject(self, &kListenerDelegate); }
- (void)setDelegate:(id<NSXPCListenerDelegate>)d { objc_setAssociatedObject(self, &kListenerDelegate, d, OBJC_ASSOCIATION_ASSIGN); }
- (NSXPCListenerEndpoint *)endpoint { NSXPCListenerEndpoint *e = [NSXPCListenerEndpoint new]; [e setWsbsdPath: LS(self)->_path]; return e; }
- (void)resume { [LS(self) resume]; } - (void)suspend { } - (void)invalidate { [LS(self) invalidate]; }
@end

static WsXPCInterface *IS(NSXPCInterface *i) { return objc_getAssociatedObject(i, &kIfaceState); }
@implementation NSXPCInterface (WsbsdXPC)
+ (NSXPCInterface *)interfaceWithProtocol:(Protocol *)p { NSXPCInterface *i = [self new]; objc_setAssociatedObject(i, &kIfaceState, [WsXPCInterface interfaceWithProtocol: p], OBJC_ASSOCIATION_RETAIN); return i; }
- (Protocol *)protocol { return [IS(self) protocol]; } - (void)setProtocol:(Protocol *)p { [IS(self) setProtocol: p]; }
- (void)setClasses:(NSSet *)c forSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { [IS(self) setClasses: c forSelector: s argumentIndex: a ofReply: r]; }
- (NSSet *)classesForSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { return [IS(self) classesForSelector: s argumentIndex: a ofReply: r]; }
- (void)setInterface:(NSXPCInterface *)i forSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { [IS(self) setInterface: i forSelector: s argumentIndex: a ofReply: r]; }
- (NSXPCInterface *)interfaceForSelector:(SEL)s argumentIndex:(NSUInteger)a ofReply:(BOOL)r { return [IS(self) interfaceForSelector: s argumentIndex: a ofReply: r]; }
@end


/* ---- default replies: the methods of a protocol a service does not implement answer with a zeroed reply, so that a client never waits for them ---- */
static void CallBlockZeros(id block)
{
	const char *sig = BlockSignature(block); if (!sig) return; NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes: sig]; NSUInteger n = [ms numberOfArguments];
	ffi_type **ats = calloc(n, sizeof(ffi_type *)); void **av = calloc(n, sizeof(void *)); void *bp = (__bridge void *)block; ats[0] = &ffi_type_pointer; av[0] = &bp;
	for (NSUInteger i = 1; i < n; i++) { const char *at = [ms getArgumentTypeAtIndex: i]; NSUInteger sz, al; NSGetSizeAndAlignment(at, &sz, &al); av[i] = calloc(1, sz < 8 ? 8 : sz); ats[i] = FfiFor(at); }
	ffi_cif cif; if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned)n, &ffi_type_void, ats) == FFI_OK) ffi_call(&cif, FFI_FN(((struct WsBlock *)bp)->invoke), NULL, av);
	for (NSUInteger i = 1; i < n; i++) free(av[i]); free(av); free(ats);
}
struct DefaultCtx { int blockIndex; };
static void DefaultThunk(ffi_cif *cif, void *ret, void **args, void *user)
{
	struct DefaultCtx *c = user; if (c->blockIndex >= 0) { void *b = *(void **)args[c->blockIndex]; if (b) CallBlockZeros((__bridge id)b); }
}
static void InstallFor(Class cls, Protocol *p, int depth)
{
	for (int req = 1; req >= 0; req--) { unsigned n = 0; struct objc_method_description *d = protocol_copyMethodDescriptionList(p, req, YES, &n);
		for (unsigned i = 0; i < n; i++) { if (class_respondsToSelector(cls, d[i].name)) continue; NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes: d[i].types]; NSUInteger na = [ms numberOfArguments];
			ffi_cif *cif = calloc(1, sizeof *cif); ffi_type **ats = calloc(na, sizeof(ffi_type *)); struct DefaultCtx *ctx = calloc(1, sizeof *ctx); ctx->blockIndex = -1;
			for (NSUInteger k = 0; k < na; k++) { const char *at = [ms getArgumentTypeAtIndex: k]; ats[k] = FfiFor(at); if (strncmp(at, "@?", 2) == 0) ctx->blockIndex = (int)k; }
			if (ffi_prep_cif(cif, FFI_DEFAULT_ABI, (unsigned)na, &ffi_type_void, ats) != FFI_OK) continue;
			void *code; ffi_closure *cl = ffi_closure_alloc(sizeof(ffi_closure), &code); ffi_prep_closure_loc(cl, cif, DefaultThunk, ctx, code); class_addMethod(cls, d[i].name, (IMP)code, d[i].types); }
		free(d); }
	if (depth > 8) return; unsigned n = 0; Protocol * __unsafe_unretained *adopted = protocol_copyProtocolList(p, &n); for (unsigned i = 0; i < n; i++) InstallFor(cls, adopted[i], depth + 1); free(adopted);
}
void WsbsdXPCInstallDefaultReplies(Class cls, Protocol *proto) { InstallFor(cls, proto, 0); }
