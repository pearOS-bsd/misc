/*
 * NSDocumentController.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSDocumentController : NSObject <NSCoding, …> {
 *       @"NSMutableArray" _documents;  @"NSArray" _cachedTypeDescriptions;
 *       @"_NSDocumentRecentItemsMenuController" _recentItemsController;
 *       d _autosavingDelay; …
 *   }
 *   +sharedDocumentController -documents -addDocument: -removeDocument:
 *   -documentForURL: -currentDocument -recentDocumentURLs
 *   -noteNewRecentDocumentURL: -maximumRecentDocumentCount
 *
 * The shared controller tracks open documents and the recent-documents list.
 * The core manages the document list, URL lookup and a capped recent-URL list.
 * currentDocument (the document of the key window), opening/creating documents
 * from disk, autosave and the recents menu/UI are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSDocument;

@interface NSDocumentController : NSObject

@property (class, readonly, strong) NSDocumentController *sharedDocumentController;

@property (readonly, copy) NSArray<NSDocument *> *documents;
@property (nullable, readonly, weak) NSDocument *currentDocument;

- (void)addDocument:(NSDocument *)document;
- (void)removeDocument:(NSDocument *)document;
- (nullable NSDocument *)documentForURL:(NSURL *)url;

@property (readonly, copy) NSArray<NSURL *> *recentDocumentURLs;
@property (readonly) NSUInteger maximumRecentDocumentCount;
- (void)noteNewRecentDocumentURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
