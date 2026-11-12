/* test_nspersistentdocument.m */
#import "../src/NSPersistentDocument.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPersistentDocument *d = [[NSPersistentDocument alloc] init];
        CHECK([d isKindOfClass:[NSDocument class]], "is-a NSDocument");

        /* Core Data model is stage2 (nil in the AppKit-only core) */
        CHECK(d.managedObjectModel == nil, "managedObjectModel nil (Core Data = stage2)");

        /* managedObjectContext is settable and reads back */
        id ctx = [NSObject new];   /* stand-in NSManagedObjectContext */
        d.managedObjectContext = (id)ctx;
        CHECK((id)d.managedObjectContext == ctx, "managedObjectContext set + read back");

        /* a fresh document with no Core Data present: lazy getter yields nil, no crash */
        NSPersistentDocument *d2 = [[NSPersistentDocument alloc] init];
        id moc = d2.managedObjectContext;   /* NSManagedObjectContext likely absent in this test binary */
        CHECK(moc == nil || [moc isKindOfClass:NSClassFromString(@"NSManagedObjectContext")], "lazy context nil or a real MOC");

        /* configure store coordinator is a stage2 no-op returning NO + nil error */
        NSError *err = (NSError *)@"sentinel";
        BOOL ok = [d configurePersistentStoreCoordinatorForURL:[NSURL fileURLWithPath:@"/tmp/x"] ofType:@"type" error:&err];
        CHECK(!ok && err == nil, "configure store coordinator stage2 no-op");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
