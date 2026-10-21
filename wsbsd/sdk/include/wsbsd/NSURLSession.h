/* NSURLSession over libcurl for a GNUstep base without it. Tasks run on background threads; delegate callbacks and completion handlers run on the session's delegate queue (a private serial queue
 * when there is none). Redirects are followed, and offered to willPerformHTTPRedirection when the delegate implements it. No cookies, no cache, no background sessions, no authentication challenges. */
#ifndef WSBSD_NSURLSESSION_H
#define WSBSD_NSURLSESSION_H
#import <Foundation/Foundation.h>
#if !GS_HAVE_NSURLSESSION
@class NSURLSession, NSURLSessionTask, NSURLSessionDataTask, NSURLSessionUploadTask, NSURLSessionDownloadTask, NSURLSessionConfiguration;
typedef NS_ENUM(NSInteger, NSURLSessionTaskState) { NSURLSessionTaskStateRunning = 0, NSURLSessionTaskStateSuspended = 1, NSURLSessionTaskStateCanceling = 2, NSURLSessionTaskStateCompleted = 3 };
typedef NS_ENUM(NSInteger, NSURLSessionResponseDisposition) { NSURLSessionResponseCancel = 0, NSURLSessionResponseAllow = 1, NSURLSessionResponseBecomeDownload = 2 };
typedef NS_ENUM(NSInteger, NSURLSessionAuthChallengeDisposition) { NSURLSessionAuthChallengeUseCredential = 0, NSURLSessionAuthChallengePerformDefaultHandling = 1, NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2, NSURLSessionAuthChallengeRejectProtectionSpace = 3 };
extern const int64_t NSURLSessionTransferSizeUnknown;
@protocol NSURLSessionDelegate <NSObject>
@optional
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error;
@end
@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@optional
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;
@end
@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>
@optional
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data;
@end
@protocol NSURLSessionDownloadDelegate <NSURLSessionTaskDelegate>
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;
@optional
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;
@end

@interface NSURLSessionConfiguration : NSObject <NSCopying>
@property (nonatomic) NSTimeInterval timeoutIntervalForRequest, timeoutIntervalForResource;
@property (nonatomic, copy) NSDictionary *HTTPAdditionalHeaders;
@property (nonatomic) NSURLRequestCachePolicy requestCachePolicy;
@property (nonatomic) NSInteger HTTPMaximumConnectionsPerHost;
@property (nonatomic) BOOL allowsCellularAccess, HTTPShouldSetCookies, waitsForConnectivity;
@property (nonatomic, copy, readonly) NSString *identifier;
+ (NSURLSessionConfiguration *)defaultSessionConfiguration;
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration;
@end

@interface NSURLSessionTask : NSObject <NSCopying>
@property (readonly) NSUInteger taskIdentifier;
@property (readonly, copy) NSURLRequest *originalRequest, *currentRequest;
@property (readonly, copy) NSURLResponse *response;
@property (readonly, copy) NSError *error;
@property (readonly) NSURLSessionTaskState state;
@property (readonly) int64_t countOfBytesReceived, countOfBytesSent, countOfBytesExpectedToReceive, countOfBytesExpectedToSend;
@property (copy) NSString *taskDescription;
@property float priority;
- (void)resume;
- (void)suspend;
- (void)cancel;
@end
@interface NSURLSessionDataTask : NSURLSessionTask
@end
@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end
@interface NSURLSessionDownloadTask : NSURLSessionTask
@end

@interface NSURLSession : NSObject
@property (readonly, copy) NSURLSessionConfiguration *configuration;
@property (readonly, retain) NSOperationQueue *delegateQueue;
@property (readonly, assign) id<NSURLSessionDelegate> delegate;
@property (copy) NSString *sessionDescription;
+ (NSURLSession *)sharedSession;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url;
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;
- (void)finishTasksAndInvalidate;
- (void)invalidateAndCancel;
- (void)getTasksWithCompletionHandler:(void (^)(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks))completionHandler;
@end
#endif
#endif
