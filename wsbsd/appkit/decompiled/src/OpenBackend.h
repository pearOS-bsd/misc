/* OpenBackend: the part of this AppKit that talks to wsd (the "open" layer: Mach-O applications draw straight into the window server of pearOS).
 * The window server client is wsbsd's libwsclient (src/client.c, ipc.c, ...) compiled into this framework with -DWS_DARWIN_ON_BSD. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class NSWindow;
void OpenWindowOrderFront(NSWindow *w);
void OpenWindowOrderOut(NSWindow *w);
void OpenWindowDisplay(NSWindow *w);			/* draws the view tree into the buffer of the window and sends it to wsd */
void OpenRunLoop(void);				/* the event loop of NSApplication run */
NSWindow *OpenKeyWindow(void);
void OpenMenuBarShow(void);			/* the main menu of the application as a bar at the top of the screen */
void OpenMenuPublish(BOOL full);			/* the menus (or only the activation) of this program to the menu bar of the system */
