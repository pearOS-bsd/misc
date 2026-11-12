/*
 * NSPersistentDocument.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPersistentDocument, the NSDocument subclass backed by a Core Data stack.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPersistentDocument_interface.txt.
 *
 * NSPersistentDocument is an NSDocument (measured). The real class lazily builds
 * a main-queue managedObjectContext and a merged managedObjectModel from the
 * process's Core Data models. Core Data is a separate framework, so this
 * AppKit-only core keeps managedObjectContext settable/stored and leaves the
 * lazy Core Data construction + persistent-store coordinator wiring
 * (configurePersistentStoreCoordinatorForURL:…) as TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSDocument.h"

NS_ASSUME_NONNULL_BEGIN

@class NSManagedObjectContext, NSManagedObjectModel;

@interface NSPersistentDocument : NSDocument

@property (nullable, strong) NSManagedObjectContext *managedObjectContext;
@property (readonly, nullable, strong) NSManagedObjectModel *managedObjectModel;

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url
                                            ofType:(NSString *)fileType
                                             error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
