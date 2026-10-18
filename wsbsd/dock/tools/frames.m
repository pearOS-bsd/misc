#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
int main(int argc,char**argv){ @autoreleasepool {
 AVURLAsset *a=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:@(argv[1])] options:nil];
 NSLog(@"dur %f tracks %@", CMTimeGetSeconds(a.duration), [a tracksWithMediaType:AVMediaTypeVideo]);
 AVAssetImageGenerator *g=[AVAssetImageGenerator assetImageGeneratorWithAsset:a]; g.requestedTimeToleranceBefore=kCMTimeZero; g.requestedTimeToleranceAfter=kCMTimeZero; g.appliesPreferredTrackTransform=YES;
 double t0=atof(argv[2]), t1=atof(argv[3]), step=atof(argv[4]); int n=0;
 for(double t=t0;t<=t1;t+=step){ NSError *e=nil; CGImageRef im=[g copyCGImageAtTime:CMTimeMakeWithSeconds(t,600) actualTime:NULL error:&e]; if(!im){NSLog(@"fail %f %@",t,e);continue;}
  NSBitmapImageRep *r=[[NSBitmapImageRep alloc] initWithCGImage:im]; NSData *d=[r representationUsingType:NSBitmapImageFileTypePNG properties:@{}]; [d writeToFile:[NSString stringWithFormat:@"%s/f%03d.png",argv[5],n++] atomically:YES]; CGImageRelease(im);} }
 return 0; }
