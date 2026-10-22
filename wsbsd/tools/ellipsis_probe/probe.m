#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
int main(void){@autoreleasepool{
  CTFontRef f=CTFontCreateUIFontForLanguage(kCTFontUIFontSystem,12,NULL);
  NSDictionary *at=@{(id)kCTFontAttributeName:(__bridge id)f};
  CFAttributedStringRef ta=CFAttributedStringCreate(NULL,CFSTR("…"),(__bridge CFDictionaryRef)at); CTLineRef tok=CTLineCreateWithAttributedString(ta);
  printf("ELL %.4f\n", CTLineGetTypographicBounds(tok,0,0,0));
  NSArray *ss=@[@"iiiiiiiiiiiiiiiiWWWWWWWWWWWWWWWW",@"WWWWWWWWWWWWWWWWiiiiiiiiiiiiiiii",@"Creative-Ataraxia-room.zip",@"FileZilla_3.69.6_macos-arm64.tar.bz2",@"displacement-map-final-v2.psd",@"IMG_2849.JPG",@"Screenshot 2026-10-21 at 23.11.58.png",@"The quick brown fox jumps over the lazy dog.txt",@"mmmmmmmmmmmmmmmmmmmmmmmmmmlllllllllllllllllllllll",@"LiquidGlassGradientTutorial.zip",@"omnimart6.2.zip",@"BMW_F_Drift_Video_final_export.mov"];
  for (NSString *s in ss) {
    CFAttributedStringRef as=CFAttributedStringCreate(NULL,(__bridge CFStringRef)s,(__bridge CFDictionaryRef)at); CTLineRef line=CTLineCreateWithAttributedString(as);
    NSMutableString *ws=[NSMutableString string]; for (NSUInteger i=0;i<[s length];i++){ CTLineRef c=CTLineCreateWithAttributedString(CFAttributedStringCreate(NULL,(__bridge CFStringRef)[s substringWithRange:NSMakeRange(i,1)],(__bridge CFDictionaryRef)at)); [ws appendFormat:@"%.4f,",CTLineGetTypographicBounds(c,0,0,0)]; }
    NSMutableString *pw=[NSMutableString string], *sw=[NSMutableString string]; for (NSUInteger k=0;k<=[s length];k++){ CTLineRef a=CTLineCreateWithAttributedString(CFAttributedStringCreate(NULL,(__bridge CFStringRef)[s substringToIndex:k],(__bridge CFDictionaryRef)at)); [pw appendFormat:@"%.4f,",CTLineGetTypographicBounds(a,0,0,0)]; CTLineRef b2=CTLineCreateWithAttributedString(CFAttributedStringCreate(NULL,(__bridge CFStringRef)[s substringFromIndex:[s length]-k],(__bridge CFDictionaryRef)at)); [sw appendFormat:@"%.4f,",CTLineGetTypographicBounds(b2,0,0,0)]; }
    printf("S\t%s\t%s\t%s\t%s\n",[s UTF8String],[ws UTF8String],[pw UTF8String],[sw UTF8String]);
    for (double w=40; w<=CTLineGetTypographicBounds(line,0,0,0); w+=3.7) {
      CTLineRef t=CTLineCreateTruncatedLine(line,w,kCTLineTruncationMiddle,tok); if(!t){continue;}
      NSMutableString *out=[NSMutableString string]; for (id r in (__bridge NSArray*)CTLineGetGlyphRuns(t)){ CFIndex cnt=CTRunGetGlyphCount((CTRunRef)r); CFIndex idx[200]; CTRunGetStringIndices((CTRunRef)r,CFRangeMake(0,cnt),idx); for(CFIndex i=0;i<cnt;i++)[out appendFormat:@"%ld,",(long)idx[i]]; }
      printf("R\t%.2f\t%s\n",w,[out UTF8String]);
    }
  }
}}
