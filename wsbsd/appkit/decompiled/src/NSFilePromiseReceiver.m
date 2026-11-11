/*
 * NSFilePromiseReceiver.m — behavioral-1:1 core. See NSFilePromiseReceiver.h.
 */

#import "NSFilePromiseReceiver.h"

static NSArray<NSString *> *NSFilePromiseReceiverReadableTypes(void)
{
    /* measured fixed order; the middle entry is the dynamic promised-file-url UTI */
    return @[
        @"com.apple.NSFilePromiseItemMetaData",
        @"dyn.ah62d4rv4gu8yc6durvwwa3xmrvw1gkdusm1044pxqyuha2pxsvw0e55bsmwca7d3sbwu",
        @"com.apple.pasteboard.promised-file-content-type",
    ];
}

@implementation NSFilePromiseReceiver {
    id _propertyList;
    NSString *_ofType;
}

+ (NSArray<NSString *> *)readableDraggedTypes { return NSFilePromiseReceiverReadableTypes(); }
+ (NSArray<NSString *> *)acceptableDragTypes { return NSFilePromiseReceiverReadableTypes(); }
+ (NSArray<NSString *> *)readableTypesForPasteboard:(NSPasteboard *)pasteboard { return NSFilePromiseReceiverReadableTypes(); }
+ (NSUInteger)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard { return 2; /* AsPropertyList */ }

- (instancetype)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
    self = [super init];
    if (self) {
        _propertyList = propertyList;
        _ofType = [type copy];
        /* TODO(stage2): decode the promise metadata into _fileTypes/_fileNames. */
    }
    return self;
}

- (NSArray<NSString *> *)fileTypes { return @[]; /* stage2: from the parsed item */ }
- (NSArray<NSString *> *)fileNames { return @[]; /* stage2 */ }
- (NSArray<NSString *> *)alternateFileTypes { return @[]; /* stage2 */ }

- (void)receivePromisedFilesAtDestination:(NSURL *)destinationDir
                                  options:(NSDictionary *)options
                           operationQueue:(id)operationQueue
                                   reader:(void (^)(NSURL *, NSError * _Nullable))reader
{
    /* TODO(stage2): ask the originating provider to write each promised file into
     * destinationDir (via NSFilePromiseProviderDelegate) and invoke reader per
     * delivered file URL. */
}

@end
