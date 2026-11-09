/* test_nssharingservice.m — NSSharingService custom service. */
#import "../src/NSSharingService.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        __block int performed = 0;
        id img = [NSObject new];
        NSSharingService *svc = [[NSSharingService alloc] initWithTitle:@"Send to Device"
                                                                  image:img
                                                         alternateImage:nil
                                                                handler:^{ performed++; }];
        CHECK([svc.title isEqualToString:@"Send to Device"], "title stored");
        CHECK(svc.image == img, "image stored");
        CHECK([svc.menuItemTitle isEqualToString:@"Send to Device"], "menuItemTitle defaults to title");

        /* canPerformWithItems */
        CHECK(![svc canPerformWithItems:@[]], "cannot perform with no items");
        CHECK(![svc canPerformWithItems:nil], "cannot perform with nil items");
        CHECK([svc canPerformWithItems:@[@"file"]], "can perform with items");

        /* perform runs the handler only with items */
        [svc performWithItems:@[]];
        CHECK(performed == 0, "perform with no items does nothing");
        [svc performWithItems:@[@"file"]];
        CHECK(performed == 1, "perform with items runs the handler");

        /* editable fields */
        svc.recipients = @[@"a@b.com"];
        svc.subject = @"Hi";
        svc.menuItemTitle = @"Send…";
        CHECK(svc.recipients.count == 1, "recipients set");
        CHECK([svc.subject isEqualToString:@"Hi"], "subject set");
        CHECK([svc.menuItemTitle isEqualToString:@"Send…"], "menuItemTitle override");

        id del = [NSObject new];
        svc.delegate = del;
        CHECK(svc.delegate == del, "delegate set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
