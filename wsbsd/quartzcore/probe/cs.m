#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
int main(void){ @autoreleasepool {
  CGColorRef red=CGColorCreateGenericRGB(1,0,0,1), blue=CGColorCreateGenericRGB(0,0,1,1);
  CFStringRef names[]={kCGColorSpaceSRGB,kCGColorSpaceExtendedSRGB,kCGColorSpaceLinearSRGB,kCGColorSpaceExtendedLinearSRGB,kCGColorSpaceDisplayP3,kCGColorSpaceExtendedDisplayP3,kCGColorSpaceGenericRGB,kCGColorSpaceExtendedLinearDisplayP3};
  for(int i=0;i<8;i++){ CGColorSpaceRef cs=CGColorSpaceCreateWithName(names[i]); if(!cs) continue;
    CGColorRef r=CGColorCreateCopyByMatchingToColorSpace(cs,kCGRenderingIntentDefault,red,NULL), b=CGColorCreateCopyByMatchingToColorSpace(cs,kCGRenderingIntentDefault,blue,NULL);
    const CGFloat*p=CGColorGetComponents(r),*q=CGColorGetComponents(b);
    printf("%-40s red=(%.4f %.4f %.4f) blue=(%.4f %.4f %.4f)\n",[(__bridge NSString*)names[i] UTF8String],p[0],p[1],p[2],q[0],q[1],q[2]);}
}return 0;}
