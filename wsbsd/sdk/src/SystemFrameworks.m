/* Small system frameworks that the stack has no engine for: AddressBook (no contacts, "me" is nobody), ExceptionHandling (uncaught exceptions go to the delegate and the log), WebKit (the classes
 * exist; a WebView draws nothing and no page loads: the frame load delegate is told it failed). */
#import <AddressBook/AddressBook.h>
#import <ExceptionHandling/NSExceptionHandler.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

NSString *const kABEmailProperty = @"Email";
NSString *const kABFirstNameProperty = @"First";
NSString *const kABLastNameProperty = @"Last";
@implementation ABMultiValue
- (NSUInteger)count { return 0; }
- (id)valueAtIndex:(NSUInteger)index { return nil; }
- (NSString *)labelAtIndex:(NSUInteger)index { return nil; }
- (NSString *)primaryIdentifier { return nil; }
- (NSUInteger)indexForIdentifier:(NSString *)identifier { return NSNotFound; }
@end
@implementation ABMutableMultiValue @end
@implementation ABRecord
- (id)valueForProperty:(NSString *)property { return nil; }
@end
@implementation ABPerson @end
@implementation ABAddressBook
+ (ABAddressBook *)sharedAddressBook { static ABAddressBook *b; static dispatch_once_t once; dispatch_once(&once, ^{ b = [ABAddressBook new]; }); return b; }
- (ABPerson *)me { return nil; }
@end

NSString *const NSUncaughtSystemExceptionException = @"NSUncaughtSystemExceptionException";
NSString *const NSUncaughtRuntimeErrorException = @"NSUncaughtRuntimeErrorException";
NSString *const NSStackTraceKey = @"NSStackTraceKey";
@implementation NSObject (NSExceptionHandlerDelegate)
- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(NSUInteger)aMask { return YES; }
- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(NSUInteger)aMask { return NO; }
@end
static NSExceptionHandler *gHandler;
static void WsbsdUncaught(NSException *e)
{
	NSExceptionHandler *h = gHandler; id d = [h delegate]; NSUInteger m = [h exceptionHandlingMask];
	BOOL log = (m & NSLogUncaughtExceptionMask) != 0, handle = (m & NSHandleUncaughtExceptionMask) != 0;
	if (log && [d respondsToSelector: @selector(exceptionHandler:shouldLogException:mask:)]) log = [d exceptionHandler: h shouldLogException: e mask: NSLogUncaughtExceptionMask];
	if (log) NSLog(@"%@: %@", [e name], [e reason]);
	if (handle && [d respondsToSelector: @selector(exceptionHandler:shouldHandleException:mask:)]) [d exceptionHandler: h shouldHandleException: e mask: NSHandleUncaughtExceptionMask];
}
@implementation NSExceptionHandler
{ NSUInteger _mask, _hang; id _delegate; }
+ (NSExceptionHandler *)defaultExceptionHandler { static dispatch_once_t once; dispatch_once(&once, ^{ gHandler = [NSExceptionHandler new]; }); return gHandler; }
- (void)setExceptionHandlingMask:(NSUInteger)aMask { _mask = aMask; NSSetUncaughtExceptionHandler(aMask ? WsbsdUncaught : NULL); }
- (NSUInteger)exceptionHandlingMask { return _mask; }
- (void)setExceptionHangingMask:(NSUInteger)aMask { _hang = aMask; }
- (NSUInteger)exceptionHangingMask { return _hang; }
- (void)setDelegate:(id)delegate { _delegate = delegate; }
- (id)delegate { return _delegate; }
@end

NSString *const WebActionNavigationTypeKey = @"WebActionNavigationTypeKey";
NSString *const WebActionElementKey = @"WebActionElementKey";
NSString *const WebActionOriginalURLKey = @"WebActionOriginalURLKey";
NSString *const WebElementLinkURLKey = @"WebElementLinkURL";
@implementation WebScriptObject
+ (BOOL)throwException:(NSString *)exceptionMessage { return NO; }
- (id)evaluateWebScript:(NSString *)script { return nil; }
- (id)callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments { return nil; }
- (id)valueForKey:(NSString *)key { return nil; }
- (void)setValue:(id)value forKey:(NSString *)key { }
@end
@implementation WebPreferences
- (instancetype)initWithIdentifier:(NSString *)i { return [super init]; }
+ (WebPreferences *)standardPreferences { static WebPreferences *p; static dispatch_once_t once; dispatch_once(&once, ^{ p = [WebPreferences new]; }); return p; }
- (void)setStandardFontFamily:(NSString *)family { } - (void)setFixedFontFamily:(NSString *)family { }
- (void)setDefaultFontSize:(int)size { } - (void)setDefaultFixedFontSize:(int)size { }
- (void)setJavaScriptEnabled:(BOOL)flag { } - (void)setPlugInsEnabled:(BOOL)flag { }
- (void)setUserStyleSheetEnabled:(BOOL)flag { } - (void)setUserStyleSheetLocation:(NSURL *)url { }
- (void)setUsesPageCache:(BOOL)flag { } - (void)setCacheModel:(WebCacheModel)m { }
@end
@implementation WebUndefined
+ (WebUndefined *)undefined { static WebUndefined *u; static dispatch_once_t once; dispatch_once(&once, ^{ u = [WebUndefined new]; }); return u; }
@end
@implementation DOMObject @end
@implementation DOMNode - (NSString *)nodeValue { return nil; } - (NSString *)textContent { return nil; } @end
@implementation DOMDocumentFragment @end
@implementation DOMNodeIterator - (DOMNode *)nextNode { return nil; } @end
@implementation DOMDocument - (DOMNodeIterator *)createNodeIterator:(DOMNode *)root whatToShow:(unsigned)w filter:(id)f expandEntityReferences:(BOOL)e { return nil; } @end
@implementation DOMRange - (DOMDocumentFragment *)cloneContents { return nil; } - (NSString *)text { return @""; } @end
@implementation WebDataSource
- (NSString *)textEncodingName { return @"utf-8"; }
- (NSURLRequest *)initialRequest { return nil; } - (NSURLRequest *)request { return nil; } - (NSURLResponse *)response { return nil; } - (NSData *)data { return nil; } - (WebFrame *)webFrame { return nil; }
@end
@implementation WebFrameView
- (BOOL)allowsScrolling { return YES; } - (void)setAllowsScrolling:(BOOL)flag { }
@end
@implementation WebBackForwardList
- (id)itemAtIndex:(int)index { return nil; }
@end
@implementation WebFrame
{ __weak WebView *_view; WebFrameView *_frameView; }
- (id)initWithWebView:(WebView *)v { if ((self = [super init])) { _view = v; _frameView = [WebFrameView new]; } return self; }
- (WebView *)webView { return _view; } - (WebFrameView *)frameView { return _frameView; }
- (DOMDocument *)DOMDocument { return nil; }
- (WebDataSource *)dataSource { return nil; } - (WebDataSource *)provisionalDataSource { return nil; }
- (void)failLoad
{
	id d = [_view frameLoadDelegate]; NSError *e = [NSError errorWithDomain: @"WebKitErrorDomain" code: 102 userInfo: @{ NSLocalizedDescriptionKey: @"There is no web engine" }];
	if ([d respondsToSelector: @selector(webView:didFailProvisionalLoadWithError:forFrame:)]) [d webView: _view didFailProvisionalLoadWithError: e forFrame: self];
}
- (void)loadRequest:(NSURLRequest *)request { [self failLoad]; }
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL { [self failLoad]; }
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)encodingName baseURL:(NSURL *)URL { [self failLoad]; }
- (void)reload { } - (void)stopLoading { }
- (WebScriptObject *)windowObject { return [WebScriptObject new]; }
@end
@implementation WebView
{ WebFrame *_main; id _frameLoad, _policy, _ui, _resource; WebPreferences *_prefs; BOOL _draws; WebBackForwardList *_bfl; }
- (id)initWithFrame:(NSRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName { if ((self = [super initWithFrame: frame])) { _main = [[WebFrame alloc] initWithWebView: self]; _draws = YES; } return self; }
- (id)initWithFrame:(NSRect)frame { return [self initWithFrame: frame frameName: nil groupName: nil]; }
- (WebFrame *)mainFrame { return _main; }
- (void)setFrameLoadDelegate:(id)d { _frameLoad = d; } - (id)frameLoadDelegate { return _frameLoad; }
- (void)setPolicyDelegate:(id)d { _policy = d; } - (id)policyDelegate { return _policy; }
- (void)setUIDelegate:(id)d { _ui = d; } - (id)UIDelegate { return _ui; }
- (void)setResourceLoadDelegate:(id)d { _resource = d; } - (id)resourceLoadDelegate { return _resource; }
- (void)setDownloadDelegate:(id)d { }
- (WebPreferences *)preferences { return _prefs ?: [WebPreferences standardPreferences]; } - (void)setPreferences:(WebPreferences *)p { _prefs = p; }
- (void)setApplicationNameForUserAgent:(NSString *)name { }
- (void)setDrawsBackground:(BOOL)flag { _draws = flag; [self setNeedsDisplay: YES]; } - (BOOL)drawsBackground { return _draws; }
- (void)setMaintainsBackForwardList:(BOOL)flag { }
- (WebBackForwardList *)backForwardList { return _bfl ?: (_bfl = [WebBackForwardList new]); }
- (NSString *)mainFrameURL { return nil; } - (void)setMainFrameURL:(NSString *)u { [_main loadRequest: nil]; }
- (NSString *)mainFrameTitle { return nil; }
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script { return nil; }
- (WebScriptObject *)windowScriptObject { return [_main windowObject]; }
- (BOOL)canGoBack { return NO; } - (BOOL)canGoForward { return NO; } - (BOOL)goBack { return NO; } - (BOOL)goForward { return NO; }
- (IBAction)goBack:(id)sender { } - (IBAction)goForward:(id)sender { } - (IBAction)reload:(id)sender { } - (IBAction)stopLoading:(id)sender { }
- (BOOL)isLoading { return NO; } - (double)estimatedProgress { return 1; }
- (void)close { _frameLoad = _policy = _ui = _resource = nil; }
- (NSString *)preferencesIdentifier { return objc_getAssociatedObject(self, "wsbsd.prefid"); } - (void)setPreferencesIdentifier:(NSString *)i { objc_setAssociatedObject(self, "wsbsd.prefid", [i copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (DOMRange *)selectedDOMRange { return nil; } - (WebFrame *)selectedFrame { return _main; }
- (BOOL)searchFor:(NSString *)s direction:(BOOL)f caseSensitive:(BOOL)c wrap:(BOOL)w { return NO; }
+ (void)registerURLSchemeAsLocal:(NSString *)scheme { (void)scheme; }
- (void)drawRect:(NSRect)r { if (_draws) { [[NSColor whiteColor] set]; NSRectFill(r); } }
@end

NSString *const WebViewProgressStartedNotification = @"WebProgressStartedNotification";
NSString *const WebViewProgressEstimateChangedNotification = @"WebProgressEstimateChangedNotification";
NSString *const WebViewProgressFinishedNotification = @"WebProgressFinishedNotification";
@implementation WebFrameView (WsbsdDocument) - (NSView *)documentView { return nil; } @end

@implementation WKNavigation @end
@implementation WKNavigationAction { NSURLRequest *_req; WKNavigationType _type; } - (NSURLRequest *)request { return _req; } - (WKNavigationType)navigationType { return _type; } @end
@implementation WKScriptMessage { NSString *_name; id _body; } - (NSString *)name { return _name; } - (id)body { return _body; } @end
@implementation WKUserContentController
{ NSMutableDictionary *_handlers; }
- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)h name:(NSString *)name { if (!_handlers) _handlers = [NSMutableDictionary dictionary]; _handlers[name] = h; }
- (void)removeScriptMessageHandlerForName:(NSString *)name { [_handlers removeObjectForKey: name]; }
- (void)removeAllUserScripts { }
- (void)addUserScript:(WKUserScript *)s { (void)s; }                                                          /* there is no page to run it in */
@end
@implementation WKUserScript { NSString *_src; WKUserScriptInjectionTime _t; BOOL _main; }
- (instancetype)initWithSource:(NSString *)s injectionTime:(WKUserScriptInjectionTime)t forMainFrameOnly:(BOOL)m { if ((self = [super init])) { _src = [s copy]; _t = t; _main = m; } return self; }
- (NSString *)source { return _src; } - (WKUserScriptInjectionTime)injectionTime { return _t; } - (BOOL)isForMainFrameOnly { return _main; }
@end
@implementation WKWebViewConfiguration
{ WKUserContentController *_ucc; }
- (WKUserContentController *)userContentController { return _ucc ?: (_ucc = [WKUserContentController new]); }
- (void)setUserContentController:(WKUserContentController *)c { _ucc = c; }
@end
@implementation WKWebView
{ WKWebViewConfiguration *_cfg; __weak id<WKNavigationDelegate> _nav; __weak id<WKUIDelegate> _ui; BOOL _gestures; }
- (instancetype)initWithFrame:(NSRect)frame configuration:(WKWebViewConfiguration *)c { if ((self = [super initWithFrame: frame])) _cfg = c ?: [WKWebViewConfiguration new]; return self; }
- (instancetype)initWithFrame:(NSRect)frame { return [self initWithFrame: frame configuration: nil]; }
- (id<WKNavigationDelegate>)navigationDelegate { return _nav; } - (void)setNavigationDelegate:(id<WKNavigationDelegate>)d { _nav = d; }
- (id<WKUIDelegate>)UIDelegate { return _ui; } - (void)setUIDelegate:(id<WKUIDelegate>)d { _ui = d; }
- (WKWebViewConfiguration *)configuration { return _cfg; }
- (NSURL *)URL { return nil; } - (NSString *)title { return nil; } - (BOOL)isLoading { return NO; }
- (BOOL)allowsBackForwardNavigationGestures { return _gestures; } - (void)setAllowsBackForwardNavigationGestures:(BOOL)b { _gestures = b; }
- (WKNavigation *)fail
{
	WKNavigation *n = [WKNavigation new]; NSError *e = [NSError errorWithDomain: @"WKErrorDomain" code: 1 userInfo: @{ NSLocalizedDescriptionKey: @"There is no web engine" }];
	if ([_nav respondsToSelector: @selector(webView:didFailProvisionalNavigation:withError:)]) [_nav webView: self didFailProvisionalNavigation: n withError: e];
	return n;
}
- (WKNavigation *)loadRequest:(NSURLRequest *)r { return [self fail]; }
- (WKNavigation *)loadHTMLString:(NSString *)s baseURL:(NSURL *)b { return [self fail]; }
- (WKNavigation *)loadFileURL:(NSURL *)u allowingReadAccessToURL:(NSURL *)r { return [self fail]; }
- (void)evaluateJavaScript:(NSString *)js completionHandler:(void (^)(id, NSError *))h { if (h) h(nil, [NSError errorWithDomain: @"WKErrorDomain" code: 4 userInfo: @{ NSLocalizedDescriptionKey: @"There is no web engine" }]); }
- (void)stopLoading { } - (WKNavigation *)reload { return [self fail]; }
- (void)drawRect:(NSRect)r { [[NSColor whiteColor] set]; NSRectFill(r); }
@end

#import <OSAKit/OSAKit.h>
@implementation OSAScript { NSString *_src; }
- (instancetype)initWithSource:(NSString *)s { if ((self = [super init])) _src = [s copy]; return self; }
- (instancetype)initWithSource:(NSString *)s language:(id)l { return [self initWithSource: s]; }
- (NSString *)source { return _src; }
- (BOOL)compileAndReturnError:(NSDictionary **)e { if (e) *e = @{ @"OSAScriptErrorMessage": @"There is no scripting engine" }; return NO; }
- (NSAppleEventDescriptor *)executeAndReturnError:(NSDictionary **)e { if (e) *e = @{ @"OSAScriptErrorMessage": @"There is no scripting engine" }; return nil; }
@end
