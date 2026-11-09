/*
 * NSDocumentController.m — 1:1 (core). See NSDocumentController.h for evidence.
 *
 * sharedDocumentController is the process-wide singleton. addDocument:/
 * removeDocument: maintain the open-document list; documentForURL: matches by
 * fileURL. noteNewRecentDocumentURL: prepends to the recent list, de-duplicates
 * and caps at maximumRecentDocumentCount (default 10), most-recent first.
 * currentDocument tracks the most recently added document as a stand-in for the
 * key-window document (the real key-window lookup is stage2).
 */
#import "NSDocumentController.h"
#import "NSDocument.h"

@implementation NSDocumentController {
    NSMutableArray<NSDocument *> *_documents;
    NSMutableArray<NSURL *> *_recentURLs;
    __weak NSDocument *_currentDocument;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _documents = [NSMutableArray array];
        _recentURLs = [NSMutableArray array];
    }
    return self;
}

+ (NSDocumentController *)sharedDocumentController
{
    static NSDocumentController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[NSDocumentController alloc] init]; });
    return shared;
}

- (NSArray<NSDocument *> *)documents { return [_documents copy]; }
- (NSDocument *)currentDocument { return _currentDocument; }

- (void)addDocument:(NSDocument *)document
{
    if (!document || [_documents containsObject:document]) return;
    [_documents addObject:document];
    _currentDocument = document;
}

- (void)removeDocument:(NSDocument *)document
{
    [_documents removeObjectIdenticalTo:document];
    if (_currentDocument == document) _currentDocument = _documents.lastObject;
}

- (NSDocument *)documentForURL:(NSURL *)url
{
    for (NSDocument *d in _documents)
        if (d.fileURL && [d.fileURL isEqual:url]) return d;
    return nil;
}

- (NSUInteger)maximumRecentDocumentCount { return 10; }

- (void)noteNewRecentDocumentURL:(NSURL *)url
{
    if (!url) return;
    [_recentURLs removeObject:url];           /* de-dup; moves it to front */
    [_recentURLs insertObject:url atIndex:0]; /* most-recent first */
    while (_recentURLs.count > self.maximumRecentDocumentCount)
        [_recentURLs removeLastObject];
}

- (NSArray<NSURL *> *)recentDocumentURLs { return [_recentURLs copy]; }

@end
