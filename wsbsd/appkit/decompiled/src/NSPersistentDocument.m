/*
 * NSPersistentDocument.m — behavioral-1:1 core. See the header.
 */

#import "NSPersistentDocument.h"

@implementation NSPersistentDocument {
    NSManagedObjectContext *_managedObjectContext;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        /* The real class lazily creates a main-queue NSManagedObjectContext and
           attaches a persistent store coordinator built from the merged model.
           That needs Core Data (a separate framework) = stage2; create one only
           if the class is actually present in this process. */
        Class ctxClass = NSClassFromString(@"NSManagedObjectContext");
        if (ctxClass) _managedObjectContext = [[ctxClass alloc] init];
    }
    return _managedObjectContext;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)ctx { _managedObjectContext = ctx; }

- (NSManagedObjectModel *)managedObjectModel
{
    /* TODO(stage2): +[NSManagedObjectModel mergedModelFromBundles:] over the
       app's .momd resources. */
    return nil;
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url
                                            ofType:(NSString *)fileType
                                             error:(NSError **)error
{
    /* TODO(stage2): add an NSPersistentStore of the right type at url to the
       context's coordinator. */
    if (error) *error = nil;
    return NO;
}

@end
