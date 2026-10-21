/* WebKit: there is no web engine. The classes exist so that applications that show HTML in a few places (command output, an about page) compile and run; a WebView draws nothing and loads nothing
 * (the frame load delegate is told the load failed). Implemented in sdk/src/SystemFrameworks.m */
#ifndef WSBSD_WEBKIT_H
#define WSBSD_WEBKIT_H
#import <Cocoa/Cocoa.h>
@class WebView, WebFrame, WebDataSource, WebPreferences, WebScriptObject, WebFrameView, WebHistoryItem, WebBackForwardList;
@protocol WebPolicyDecisionListener <NSObject>
- (void)use; - (void)download; - (void)ignore;
@end
@protocol WebFrameLoadDelegate <NSObject> @optional
- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame;
- (void)webView:(WebView *)webView windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject;
@end
@protocol WebPolicyDelegate <NSObject> @optional
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener;
- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener;
@end
@protocol WebUIDelegate <NSObject> @optional
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request;
@end
@protocol WebResourceLoadDelegate <NSObject> @end
extern NSString *const WebActionNavigationTypeKey;
extern NSString *const WebActionElementKey;
extern NSString *const WebActionOriginalURLKey;
extern NSString *const WebElementLinkURLKey;
typedef enum { WebNavigationTypeLinkClicked, WebNavigationTypeFormSubmitted, WebNavigationTypeBackForward, WebNavigationTypeReload, WebNavigationTypeFormResubmitted, WebNavigationTypeOther } WebNavigationType;
@interface WebScriptObject : NSObject
+ (BOOL)throwException:(NSString *)exceptionMessage;
- (id)evaluateWebScript:(NSString *)script;
- (id)callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments;
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;
@end
@interface WebPreferences : NSObject
+ (WebPreferences *)standardPreferences;
- (void)setStandardFontFamily:(NSString *)family; - (void)setFixedFontFamily:(NSString *)family;
- (void)setDefaultFontSize:(int)size; - (void)setDefaultFixedFontSize:(int)size;
- (void)setJavaScriptEnabled:(BOOL)flag; - (void)setPlugInsEnabled:(BOOL)flag;
- (void)setUserStyleSheetEnabled:(BOOL)flag; - (void)setUserStyleSheetLocation:(NSURL *)url;
@end
@interface WebDataSource : NSObject
- (NSURLRequest *)request; - (NSURLResponse *)response; - (NSData *)data; - (WebFrame *)webFrame;
@end
@interface WebFrameView : NSView
- (BOOL)allowsScrolling; - (void)setAllowsScrolling:(BOOL)flag;
- (NSView *)documentView;
@end
@interface WebFrame : NSObject
- (WebView *)webView; - (WebFrameView *)frameView; - (WebDataSource *)dataSource; - (WebDataSource *)provisionalDataSource;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)encodingName baseURL:(NSURL *)URL;
- (void)reload; - (void)stopLoading;
- (WebScriptObject *)windowObject;
@end
@interface WebBackForwardList : NSObject
- (id)itemAtIndex:(int)index;
@end
@interface WebView : NSView
- (id)initWithFrame:(NSRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName;
- (WebFrame *)mainFrame;
- (void)setFrameLoadDelegate:(id)delegate; - (id)frameLoadDelegate;
- (void)setPolicyDelegate:(id)delegate; - (id)policyDelegate;
- (void)setUIDelegate:(id)delegate; - (id)UIDelegate;
- (void)setResourceLoadDelegate:(id)delegate; - (id)resourceLoadDelegate;
- (void)setDownloadDelegate:(id)delegate;
- (WebPreferences *)preferences; - (void)setPreferences:(WebPreferences *)preferences;
- (void)setApplicationNameForUserAgent:(NSString *)name;
- (void)setDrawsBackground:(BOOL)flag; - (BOOL)drawsBackground;
- (void)setMaintainsBackForwardList:(BOOL)flag;
- (WebBackForwardList *)backForwardList;
- (NSString *)mainFrameURL; - (void)setMainFrameURL:(NSString *)URLString;
- (NSString *)mainFrameTitle;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (WebScriptObject *)windowScriptObject;
- (BOOL)canGoBack; - (BOOL)canGoForward; - (BOOL)goBack; - (BOOL)goForward;
- (IBAction)goBack:(id)sender; - (IBAction)goForward:(id)sender; - (IBAction)reload:(id)sender; - (IBAction)stopLoading:(id)sender;
- (BOOL)isLoading; - (double)estimatedProgress;
- (void)close;
@end

extern NSString *const WebViewProgressStartedNotification, *const WebViewProgressEstimateChangedNotification, *const WebViewProgressFinishedNotification;

/* WKWebView of the modern WebKit: the same, no engine; loads report failure to the navigation delegate and scripts evaluate to an error */
typedef NS_ENUM(NSInteger, WKNavigationActionPolicy) { WKNavigationActionPolicyCancel = 0, WKNavigationActionPolicyAllow = 1 };
typedef NS_ENUM(NSInteger, WKNavigationType) { WKNavigationTypeLinkActivated = 0, WKNavigationTypeFormSubmitted = 1, WKNavigationTypeBackForward = 2, WKNavigationTypeReload = 3, WKNavigationTypeFormResubmitted = 4, WKNavigationTypeOther = -1 };
@class WKWebView, WKNavigation, WKNavigationAction, WKScriptMessage, WKUserContentController, WKWebViewConfiguration;
@protocol WKNavigationDelegate <NSObject> @optional
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
@end
@protocol WKScriptMessageHandler <NSObject>
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;
@end
@protocol WKUIDelegate <NSObject> @end
@interface WKNavigation : NSObject @end
@interface WKNavigationAction : NSObject
@property (nonatomic, readonly, copy) NSURLRequest *request;
@property (nonatomic, readonly) WKNavigationType navigationType;
@end
@interface WKScriptMessage : NSObject
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) id body;
@end
@interface WKUserContentController : NSObject
- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)handler name:(NSString *)name;
- (void)removeScriptMessageHandlerForName:(NSString *)name;
- (void)removeAllUserScripts;
@end
@interface WKWebViewConfiguration : NSObject
@property (nonatomic, strong) WKUserContentController *userContentController;
@end
@interface WKWebView : NSView
- (instancetype)initWithFrame:(NSRect)frame configuration:(WKWebViewConfiguration *)configuration;
@property (nonatomic, weak) id<WKNavigationDelegate> navigationDelegate;
@property (nonatomic, weak) id<WKUIDelegate> UIDelegate;
@property (nonatomic, readonly, copy) WKWebViewConfiguration *configuration;
@property (nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic) BOOL allowsBackForwardNavigationGestures;
- (WKNavigation *)loadRequest:(NSURLRequest *)request;
- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler;
- (void)stopLoading;
- (WKNavigation *)reload;
@end
#endif
