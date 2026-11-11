/*
 * NSFilePromiseProvider.m — behavioral-1:1 core. See NSFilePromiseProvider.h.
 */

#import "NSFilePromiseProvider.h"

@implementation NSFilePromiseProvider {
    NSString *_fileType;
    NSArray<NSString *> *_alternateFileTypes;
    __weak id<NSFilePromiseProviderDelegate> _delegate;
    id _userInfo;
}

- (instancetype)initWithFileType:(NSString *)fileType delegate:(id<NSFilePromiseProviderDelegate>)delegate
{
    self = [super init];
    if (self) {
        _fileType = [fileType copy];
        _delegate = delegate;
    }
    return self;
}

- (NSString *)fileType { return _fileType; }
- (void)setFileType:(NSString *)t { _fileType = [t copy]; }
- (NSArray<NSString *> *)alternateFileTypes { return _alternateFileTypes; }
- (void)setAlternateFileTypes:(NSArray<NSString *> *)t { _alternateFileTypes = [t copy]; }
- (id<NSFilePromiseProviderDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSFilePromiseProviderDelegate>)d { _delegate = d; }
- (id)userInfo { return _userInfo; }
- (void)setUserInfo:(id)u { _userInfo = u; }

/* --- NSPasteboardWriting --- */

- (NSArray<NSString *> *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    /* measured fixed order */
    return @[
        @"com.apple.NSFilePromiseItemMetaData",
        @"com.apple.pasteboard.promised-file-name",
        @"com.apple.pasteboard.promised-suggested-file-name",
        @"com.apple.pasteboard.promised-file-content-type",
        @"com.apple.pasteboard.NSFilePromiseID",
    ];
}

- (NSUInteger)writingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard
{
    return 0; /* TODO(stage2): NSPasteboardWritingPromised for the content type */
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    /* TODO(stage2): vend the promise metadata / content-type / file name, and
     * drive the delegate's writePromiseToURL:completionHandler: on drop. */
    return nil;
}

@end
