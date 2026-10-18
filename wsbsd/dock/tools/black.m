#import <Cocoa/Cocoa.h>
int main(int argc,char**argv){ @autoreleasepool { NSApplication *a=[NSApplication sharedApplication]; [a setActivationPolicy:NSApplicationActivationPolicyAccessory];
 NSRect r=[[NSScreen mainScreen] frame]; NSWindow *w=[[NSWindow alloc] initWithContentRect:r styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
 [w setBackgroundColor:[NSColor blackColor]]; [w setLevel:NSNormalWindowLevel+1]; [w setOpaque:YES]; [w makeKeyAndOrderFront:nil]; [a activateIgnoringOtherApps:YES];
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:atof(argv[1])]]; } return 0; }
