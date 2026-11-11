/*
 * NSFilePromiseProvider.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSFilePromiseProvider, the NSPasteboardWriting object that promises a file's
 * contents during a drag.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSFilePromiseProvider_interface.txt. Real ivars: _fileType,
 * _reservedA (alternate types), _delegate (weak), _userInfo, _destinationURL.
 *
 * Measured on this Mac: initWithFileType:delegate: stores the fileType + weak
 * delegate; userInfo is nil; writableTypesForPasteboard: returns a fixed 5-UTI
 * array (metadata / promised-file-name / promised-suggested-file-name /
 * promised-file-content-type / NSFilePromiseID).
 *
 * This core reproduces the identity + writable-types vending. The pasteboard
 * data provisioning (pasteboardPropertyListForType:) and the delegate-driven
 * file write (filePromiseProvider:writePromiseToURL:completionHandler:) are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSPasteboard;
@protocol NSFilePromiseProviderDelegate;

@interface NSFilePromiseProvider : NSObject

- (instancetype)initWithFileType:(NSString *)fileType delegate:(id<NSFilePromiseProviderDelegate>)delegate;

@property (copy) NSString *fileType;
@property (nullable, copy) NSArray<NSString *> *alternateFileTypes;
@property (nullable, weak) id<NSFilePromiseProviderDelegate> delegate;
@property (nullable, strong) id userInfo;

/* NSPasteboardWriting */
- (NSArray<NSString *> *)writableTypesForPasteboard:(NSPasteboard *)pasteboard;
- (NSUInteger)writingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard;
- (nullable id)pasteboardPropertyListForType:(NSString *)type;

@end

@protocol NSFilePromiseProviderDelegate <NSObject>
@required
- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider fileNameForType:(NSString *)fileType;
- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider writePromiseToURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))completionHandler;
@optional
- (id)operationQueueForFilePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider;
@end

NS_ASSUME_NONNULL_END
