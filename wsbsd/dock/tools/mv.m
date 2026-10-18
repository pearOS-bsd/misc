#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
int main(int argc,char**argv){ double x=atof(argv[1]), y=atof(argv[2]); CGEventRef e=CGEventCreateMouseEvent(NULL,kCGEventMouseMoved,CGPointMake(x,y),0); CGEventPost(kCGHIDEventTap,e); CFRelease(e); return 0; }
