/* CFNetwork's proxy support: the proxy settings are the http_proxy / https_proxy / ftp_proxy / all_proxy / no_proxy variables of the environment (SCDynamicStoreCopyProxies reads them), CFNetworkCopyProxiesForURL
 * answers with the one that applies to the URL or "no proxy"; proxy auto configuration scripts are not run. Implemented in sdk/src/AppKitCompat2.m */
#ifndef WSBSD_CFNETWORK_H
#define WSBSD_CFNETWORK_H
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
extern const CFStringRef kCFProxyTypeKey, kCFProxyTypeNone, kCFProxyTypeHTTP, kCFProxyTypeHTTPS, kCFProxyTypeSOCKS, kCFProxyTypeFTP, kCFProxyTypeAutoConfigurationURL, kCFProxyTypeAutoConfigurationJavaScript,
	kCFProxyHostNameKey, kCFProxyPortNumberKey, kCFProxyAutoConfigurationURLKey, kCFProxyAutoConfigurationJavaScriptKey, kCFProxyUsernameKey, kCFProxyPasswordKey;
extern const CFStringRef kCFNetworkProxiesHTTPEnable, kCFNetworkProxiesHTTPProxy, kCFNetworkProxiesHTTPPort, kCFNetworkProxiesHTTPSEnable, kCFNetworkProxiesHTTPSProxy, kCFNetworkProxiesHTTPSPort,
	kCFNetworkProxiesProxyAutoConfigEnable, kCFNetworkProxiesProxyAutoConfigURLString, kCFNetworkProxiesExceptionsList;
typedef void (*CFProxyAutoConfigurationResultCallback)(void *client, CFArrayRef proxyList, CFErrorRef error);
CFDictionaryRef CFNetworkCopySystemProxySettings(void);
CFArrayRef CFNetworkCopyProxiesForURL(CFURLRef url, CFDictionaryRef proxySettings);
CFRunLoopSourceRef CFNetworkExecuteProxyAutoConfigurationURL(CFURLRef proxyAutoConfigURL, CFURLRef targetURL, CFProxyAutoConfigurationResultCallback cb, CFStreamClientContext *clientContext);
#ifdef __cplusplus
}
#endif
#endif
