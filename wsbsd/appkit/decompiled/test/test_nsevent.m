/* test_nsevent.m — NSEvent factory + accessors. */
#import "../src/NSEvent.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSEvent *m = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                        location:CGPointMake(30, 40)
                                   modifierFlags:NSEventModifierFlagShift
                                       timestamp:12.5
                                    windowNumber:7
                                         context:nil
                                     eventNumber:1
                                      clickCount:2
                                        pressure:1.0f];
        CHECK(m.type == NSEventTypeLeftMouseDown, "mouse type");
        CHECK(m.locationInWindow.x == 30 && m.locationInWindow.y == 40, "mouse location");
        CHECK(m.modifierFlags == NSEventModifierFlagShift, "modifier flags");
        CHECK(m.timestamp == 12.5, "timestamp");
        CHECK(m.windowNumber == 7, "window number");
        CHECK(m.clickCount == 2, "click count");
        CHECK(m.pressure == 1.0f, "pressure");
        CHECK(m.buttonNumber == 0, "left mouse -> button 0");

        NSEvent *r = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown
                                        location:CGPointZero modifierFlags:0 timestamp:0
                                    windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1];
        CHECK(r.buttonNumber == 1, "right mouse -> button 1");

        NSEvent *k = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                      location:CGPointZero
                                 modifierFlags:(NSEventModifierFlagCommand)
                                     timestamp:3.0
                                  windowNumber:1
                                       context:nil
                                    characters:@"a"
                   charactersIgnoringModifiers:@"a"
                                     isARepeat:NO
                                       keyCode:0];
        CHECK(k.type == NSEventTypeKeyDown, "key type");
        CHECK([k.characters isEqualToString:@"a"], "characters");
        CHECK([k.charactersIgnoringModifiers isEqualToString:@"a"], "charactersIgnoringModifiers");
        CHECK(!k.isARepeat, "not a repeat");
        CHECK(k.keyCode == 0, "keyCode");
        CHECK((k.modifierFlags & NSEventModifierFlagCommand) != 0, "command flag set");

        /* key repeat */
        NSEvent *rep = [NSEvent keyEventWithType:NSEventTypeKeyDown location:CGPointZero
                                   modifierFlags:0 timestamp:0 windowNumber:0 context:nil
                                      characters:@"b" charactersIgnoringModifiers:@"b"
                                       isARepeat:YES keyCode:11];
        CHECK(rep.isARepeat && rep.keyCode == 11, "repeat key with keyCode 11");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
