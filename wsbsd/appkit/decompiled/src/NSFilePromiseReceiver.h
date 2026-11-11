/*
 * NSFilePromiseReceiver.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSFilePromiseReceiver, the NSPasteboardReading object that accepts a dropped
 * file promise and fetches the promised files.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSFilePromiseReceiver_interface.txt. Real ivars: _pasteboard,
 * _pasteboardItem, _fileTypes, _fileNames, _fileURLs, _operationQueue, …
 *
 * Measured on this Mac: +readableDraggedTypes / +readableTypesForPasteboard:
 * return a fixed 3-UTI array (metadata / a dynamic promised-file-url UTI /
 * promised-file-content-type) and +readingOptionsForType:pasteboard: returns 2
 * (NSPasteboardReadingAsPropertyList).
 *
 * This core reproduces the readable-drag-type vending + reading options. Parsing
 * the dropped pasteboard item into fileTypes/fileNames and actually fetching the
 * promised files (receivePromisedFilesAtDestination:…reader:) are TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSPasteboard;

@interface NSFilePromiseReceiver : NSObject

+ (NSArray<NSString *> *)readableDraggedTypes;
+ (NSArray<NSString *> *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
+ (NSUInteger)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard;

- (nullable instancetype)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type;

@property (readonly, copy) NSArray<NSString *> *fileTypes;
@property (readonly, copy) NSArray<NSString *> *fileNames;
@property (readonly, copy) NSArray<NSString *> *alternateFileTypes;

- (void)receivePromisedFilesAtDestination:(NSURL *)destinationDir
                                  options:(NSDictionary *)options
                           operationQueue:(id)operationQueue
                                   reader:(void (^)(NSURL *fileURL, NSError * _Nullable error))reader;

@end

NS_ASSUME_NONNULL_END
