/* test_nsobjectcontroller.m — behaviour checks for NSObjectController content core */
#import "../src/NSObjectController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSObjectController *c = [[NSObjectController alloc] init];
        CHECK([c isKindOfClass:[NSController class]], "is an NSController");

        /* measured defaults */
        CHECK(c.isEditable, "editable default YES");
        CHECK(!c.automaticallyPreparesContent, "automaticallyPreparesContent default NO");
        CHECK(c.objectClass == [NSMutableDictionary class], "objectClass default NSMutableDictionary");
        CHECK(c.content == nil, "content nil initially");
        CHECK(c.canAdd, "canAdd YES when editable");
        CHECK(!c.canRemove, "canRemove NO with no content");
        CHECK(c.selectedObjects.count == 0, "selectedObjects empty with no content");

        /* newObject uses objectClass */
        id obj = [c newObject];
        CHECK([obj isKindOfClass:[NSMutableDictionary class]], "newObject is objectClass instance");

        /* setContent -> canRemove + selectedObjects */
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:@"Ada" forKey:@"name"];
        c.content = d;
        CHECK(c.content == d, "content set");
        CHECK(c.canRemove, "canRemove YES with content");
        CHECK(c.selectedObjects.count == 1 && c.selectedObjects[0] == d, "selectedObjects is [content]");

        /* selection proxy reads/writes content via KVC */
        CHECK([[c.selection valueForKey:@"name"] isEqual:@"Ada"], "selection reads content value");
        [c.selection setValue:@"Grace" forKey:@"name"];
        CHECK([d[@"name"] isEqual:@"Grace"], "selection writes content value");

        /* initWithContent: */
        NSObjectController *c2 = [[NSObjectController alloc] initWithContent:[NSMutableString stringWithString:@"x"]];
        CHECK(c2.canRemove && c2.selectedObjects.count == 1, "initWithContent: canRemove + one selected object");

        /* add: creates a newObject as content (gated by canAdd) */
        NSObjectController *c3 = [[NSObjectController alloc] init];
        [c3 add:nil];
        CHECK([c3.content isKindOfClass:[NSMutableDictionary class]], "add: creates newObject content");

        /* editable NO blocks add/remove */
        NSObjectController *c4 = [[NSObjectController alloc] initWithContent:[NSMutableDictionary dictionary]];
        c4.editable = NO;
        CHECK(!c4.canAdd && !c4.canRemove, "non-editable blocks canAdd/canRemove");
        [c4 remove:nil];
        CHECK(c4.content != nil, "remove: no-op when not editable");

        /* remove: clears content */
        c4.editable = YES;
        [c4 remove:nil];
        CHECK(c4.content == nil, "remove: clears content");

        /* prepareContent installs a fresh object */
        NSObjectController *c5 = [[NSObjectController alloc] init];
        [c5 prepareContent];
        CHECK([c5.content isKindOfClass:[NSMutableDictionary class]], "prepareContent installs newObject");

        /* custom objectClass honoured by newObject */
        NSObjectController *c6 = [[NSObjectController alloc] init];
        c6.objectClass = [NSMutableArray class];
        CHECK([[c6 newObject] isKindOfClass:[NSMutableArray class]], "custom objectClass honoured");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
