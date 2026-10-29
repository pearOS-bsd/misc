/* Copying and moving items, with the Finder's progress window (it appears when the work takes longer than a moment and has a Stop button). The work runs on a thread of its own;
 * a move inside one volume is a rename, anything else is a copy of every byte (files in chunks of 1 MB so the progress is real), the source removed afterwards for a move. */
#import "TFinderViews.h"
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSObject (TPDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface TProgressView : NSView { @public NSString *title, *detail; double fraction; BOOL *stop; }
@end
@implementation TProgressView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; } - (BOOL)isDragPoint:(NSPoint)p { return p.y < 60 && p.x < 360; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; [TF_SIDEBAR setFill]; NSRectFill(b); NSDictionary *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: TF_TEXT }, *dim = @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: TF_DIM };
	[title ?: @"" drawInRect: NSMakeRect(24, 30, b.size.width - 90, 18) withAttributes: head]; NSRect bar = NSMakeRect(24, 62, b.size.width - 80, 6); [(TFDark() ? TFRGBA(255, 255, 255, 0.16) : TFRGBA(0, 0, 0, 0.12)) setFill]; [[NSBezierPath bezierPathWithRoundedRect: bar xRadius: 3 yRadius: 3] fill];
	NSRect f = bar; f.size.width = MAX(6, bar.size.width * MIN(1, fraction)); [TF_ACCENT setFill]; [[NSBezierPath bezierPathWithRoundedRect: f xRadius: 3 yRadius: 3] fill]; [detail ?: @"" drawAtPoint: NSMakePoint(24, 80) withAttributes: dim];
	NSRect x = NSMakeRect(b.size.width - 44, 53, 24, 24); [(TFDark() ? TFRGBA(255, 255, 255, 0.2) : TFRGBA(0, 0, 0, 0.15)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: x] fill]; TFSymbolW(@"xmark", x, 11, 6, TF_TEXT);
}
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; if (p.x > [self bounds].size.width - 50 && p.y > 48 && p.y < 82 && stop) { *stop = YES; } }
@end

@interface TCopyJob : NSObject { @public NSArray *srcs; NSString *dest; BOOL move; BOOL stop; unsigned long long total, done; NSString *current; NSMutableArray *ops; NSWindow *win; TProgressView *view; NSDate *t0; void (^completion)(NSArray *); BOOL finished, forceShow; } @end
@implementation TCopyJob
static unsigned long long SizeOf2(NSString *p);
static unsigned long long SizeOf(NSString *p) { struct stat sb; if (lstat([p fileSystemRepresentation], &sb)) return 0; if (!S_ISDIR(sb.st_mode)) return (unsigned long long)sb.st_size; unsigned long long t = 0; for (NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: p error: NULL]) t += SizeOf([p stringByAppendingPathComponent: n]); return t; }
- (BOOL)_copy:(NSString *)from to:(NSString *)to
{
	if (stop) return NO; struct stat sb; if (lstat([from fileSystemRepresentation], &sb)) return NO;
	if (S_ISDIR(sb.st_mode)) { mkdir([to fileSystemRepresentation], sb.st_mode & 07777); for (NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: from error: NULL]) if (![self _copy: [from stringByAppendingPathComponent: n] to: [to stringByAppendingPathComponent: n]]) return NO; return YES; }
	if (S_ISLNK(sb.st_mode)) { NSString *l = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: from error: NULL]; return l && symlink([l fileSystemRepresentation], [to fileSystemRepresentation]) == 0; }
	int in = open([from fileSystemRepresentation], O_RDONLY); if (in < 0) return NO; int out = open([to fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, sb.st_mode & 07777); if (out < 0) { close(in); return NO; }
	char *buf = (char *)malloc(1 << 20); ssize_t n; BOOL ok = YES; while (!stop && (n = read(in, buf, 1 << 20)) > 0) { if (write(out, buf, (size_t)n) != n) { ok = NO; break; } done += (unsigned long long)n; }
	free(buf); close(in); close(out); if (stop) { unlink([to fileSystemRepresentation]); return NO; } return ok && n >= 0;
}
- (void)_work
{
	@autoreleasepool {
		NSFileManager *fm = [NSFileManager defaultManager]; struct stat dsb; stat([dest fileSystemRepresentation], &dsb);
		for (NSString *p in srcs) { if (stop) break; current = [p lastPathComponent]; NSString *to = [dest stringByAppendingPathComponent: current];
			if ([fm fileExistsAtPath: to]) { BOOL sameDir = [[p stringByDeletingLastPathComponent] isEqual: dest]; NSString *stem = [current stringByDeletingPathExtension], *ext = [current pathExtension]; NSString *first = sameDir ? [stem stringByAppendingString: @" copy"] : [stem stringByAppendingString: @" 2"]; int i = 2; NSString *cand = first;
				while (YES) { to = [dest stringByAppendingPathComponent: [ext length] ? [cand stringByAppendingPathExtension: ext] : cand]; if (![fm fileExistsAtPath: to]) break; i++; cand = [NSString stringWithFormat: sameDir ? @"%@ copy %d" : @"%@ %d", stem, i]; if (!sameDir) cand = [NSString stringWithFormat: @"%@ %d", stem, i]; } }
			struct stat ssb; BOOL same = !lstat([p fileSystemRepresentation], &ssb) && ssb.st_dev == dsb.st_dev;
			if (move && same) { if (rename([p fileSystemRepresentation], [to fileSystemRepresentation]) == 0) [ops addObject: @{ @"t": @"move", @"a": p, @"b": to }]; continue; }
			if ([self _copy: p to: to]) { if (move) [fm removeItemAtPath: p error: NULL]; [ops addObject: @{ @"t": move ? @"move" : @"copy", @"a": p, @"b": to }]; } else if (stop) { [fm removeItemAtPath: to error: NULL]; }
		}
		finished = YES;
	}
}
- (void)_tick:(NSTimer *)t
{
	if (finished) { [t invalidate]; [win close]; win = nil; if (completion) completion(ops); return; }
	if (!win && (forceShow || [[NSDate date] timeIntervalSinceDate: t0] > 0.8)) { win = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(460, 420, 460, 112) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [win setReleasedWhenClosed: NO]; [win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]]; view = [[TProgressView alloc] initWithFrame: NSMakeRect(0, 0, 460, 112)]; view->stop = &stop; [win setContentView: view]; TWindowTrim *tr = [[TWindowTrim alloc] initWithFrame: [view bounds]]; [view addSubview: tr]; [win makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: win radius: 16]; }
	if (win) { view->title = [NSString stringWithFormat: @"%@ “%@”", move ? @"Moving" : @"Copying", current ?: @""]; view->fraction = total ? (double)done / total : 0; view->detail = [NSString stringWithFormat: @"%@ of %@", TFSizeString(done), TFSizeString(total)]; [view setNeedsDisplay: YES]; }
}
@end

static NSMutableArray *gCopyJobs;
/* Window > Show Progress Window: the windows of the copies that are running appear at once (they come after 0.8 s by themselves) */
void TFShowProgressWindows(void) { for (TCopyJob *j in gCopyJobs) if (!j->finished) j->forceShow = YES; }
void TFCopyItems(NSArray *srcs, NSString *destDir, BOOL move, void (^completion)(NSArray *ops))
{
	TCopyJob *j = [TCopyJob new]; j->srcs = srcs; j->dest = destDir; j->move = move; j->ops = [NSMutableArray array]; j->completion = completion; j->t0 = [NSDate date];
	if (!gCopyJobs) gCopyJobs = [NSMutableArray array]; [gCopyJobs addObject: j];
	NSThread *th = [[NSThread alloc] initWithBlock: ^{ for (NSString *p in srcs) j->total += SizeOf(p); [j _work]; }]; [th start];
	[NSTimer scheduledTimerWithTimeInterval: 0.1 target: j selector: @selector(_tick:) userInfo: nil repeats: YES];
}

static unsigned long long SizeOf2(NSString *p) { return SizeOf(p); }
/* ---------- archives: Compress and opening an archive, with the progress window ---------- */
@interface TJob : NSObject { @public NSString *title; double (^progress)(void); BOOL (^work)(BOOL *); void (^completion)(BOOL); BOOL stop, finished, ok; NSWindow *win; TProgressView *view; NSDate *t0; } @end
@implementation TJob
- (void)_tick:(NSTimer *)t
{
	if (finished) { [t invalidate]; [win close]; win = nil; if (completion) completion(ok); return; }
	if (!win && [[NSDate date] timeIntervalSinceDate: t0] > 0.8) { win = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(460, 420, 460, 112) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [win setReleasedWhenClosed: NO]; [win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]]; view = [[TProgressView alloc] initWithFrame: NSMakeRect(0, 0, 460, 112)]; view->stop = &stop; [win setContentView: view]; TWindowTrim *tr = [[TWindowTrim alloc] initWithFrame: [view bounds]]; [view addSubview: tr]; [win makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: win radius: 16]; }
	if (win) { view->title = title; view->fraction = progress ? progress() : 0; view->detail = [NSString stringWithFormat: @"%d%%", (int)(MIN(1, view->fraction) * 100)]; [view setNeedsDisplay: YES]; }
}
@end
static void TFRunJob(NSString *title, double (^progress)(void), BOOL (^work)(BOOL *), void (^completion)(BOOL))
{
	TJob *j = [TJob new]; j->title = title; j->progress = [progress copy]; j->work = [work copy]; j->completion = [completion copy]; j->t0 = [NSDate date];
	static NSMutableArray *jobs; if (!jobs) jobs = [NSMutableArray array]; [jobs addObject: j];
	[[[NSThread alloc] initWithBlock: ^{ @autoreleasepool { j->ok = j->work(&j->stop); j->finished = YES; } }] start];
	[NSTimer scheduledTimerWithTimeInterval: 0.1 target: j selector: @selector(_tick:) userInfo: nil repeats: YES];
}
static BOOL RunTar(NSArray *args, NSData **out)
{
	NSTask *tk = [[NSTask alloc] init]; [tk setLaunchPath: @"/usr/bin/tar"]; [tk setArguments: args]; NSPipe *pp = out ? [NSPipe pipe] : nil; if (pp) [tk setStandardOutput: pp]; else [tk setStandardOutput: [NSFileHandle fileHandleWithNullDevice]]; [tk setStandardError: [NSFileHandle fileHandleWithNullDevice]];
	@try { [tk launch]; if (out) *out = [[pp fileHandleForReading] readDataToEndOfFile]; [tk waitUntilExit]; } @catch (NSException *x) { return NO; } return [tk terminationStatus] == 0;
}
static NSString *UniqueIn(NSString *dir, NSString *name)       /* "name", "name 2", "name 3"... as Archive Utility numbers a result that exists */
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSString *stem = [name stringByDeletingPathExtension], *ext = [name pathExtension]; NSString *p = [dir stringByAppendingPathComponent: name]; int i = 2;
	while ([fm fileExistsAtPath: p]) { NSString *n = [NSString stringWithFormat: @"%@ %d", stem, i++]; if ([ext length]) n = [n stringByAppendingPathExtension: ext]; p = [dir stringByAppendingPathComponent: n]; }
	return p;
}
BOOL TFIsArchive(NSString *path)
{
	NSString *l = [[path lastPathComponent] lowercaseString]; BOOL d = NO; if (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d] || d) return NO;
	for (NSString *e in @[ @".zip", @".tar", @".tgz", @".tar.gz", @".tbz", @".tbz2", @".tar.bz2", @".txz", @".tar.xz" ]) if ([l hasSuffix: e]) return YES;
	return NO;
}
/* Archive Utility: an archive with one top-level item expands to that item, any other to a folder named after the archive; a name that exists gets " 2"; the result is next to the archive */
void TFExtractArchive(NSString *path, void (^done)(NSString *result))
{
	NSString *dir = [path stringByDeletingLastPathComponent]; NSString *stem = [path lastPathComponent]; for (NSString *e in @[ @".tar.gz", @".tar.bz2", @".tar.xz", @".zip", @".tar", @".tgz", @".tbz2", @".tbz", @".txz" ]) if ([[stem lowercaseString] hasSuffix: e]) { stem = [stem substringToIndex: [stem length] - [e length]]; break; }
	__block unsigned long long total = 0; NSString *stage = [dir stringByAppendingPathComponent: [NSString stringWithFormat: @".TemporaryItems-%d-%u", (int)getpid(), arc4random() % 100000]]; __block NSString *result = nil;
	TFRunJob([NSString stringWithFormat: @"Expanding “%@”", [path lastPathComponent]], ^double { if (!total) return 0; unsigned long long got = 0; NSDirectoryEnumerator *en = [[NSFileManager defaultManager] enumeratorAtPath: stage]; for (NSString *f in en) got += [[en fileAttributes][NSFileSize] unsignedLongLongValue]; return (double)got / total; },
		^BOOL(BOOL *stop) {
			NSData *lst = nil; if (!RunTar(@[ @"-tvf", path ], &lst)) return NO; NSString *ls = [[NSString alloc] initWithData: lst encoding: NSUTF8StringEncoding]; NSMutableSet *tops = [NSMutableSet set];
			for (NSString *ln in [ls componentsSeparatedByString: @"\n"]) { if (![ln length]) continue; NSArray *f = [ln componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]; NSMutableArray *ff = [NSMutableArray array]; for (NSString *x in f) if ([x length]) [ff addObject: x]; if ([ff count] > 4) total += strtoull([ff[4] UTF8String], NULL, 10); }
			NSData *names = nil; if (!RunTar(@[ @"-tf", path ], &names)) return NO; for (NSString *n in [[[NSString alloc] initWithData: names encoding: NSUTF8StringEncoding] componentsSeparatedByString: @"\n"]) { if (![n length] || [n hasPrefix: @"__MACOSX"]) continue; NSString *t = [[n pathComponents] firstObject]; if ([t length]) [tops addObject: t]; }
			NSFileManager *fm = [NSFileManager defaultManager]; [fm createDirectoryAtPath: stage withIntermediateDirectories: YES attributes: nil error: NULL];
			if ([tops count] > 1 || ![tops count]) { NSString *folder = [stage stringByAppendingPathComponent: stem]; [fm createDirectoryAtPath: folder withIntermediateDirectories: YES attributes: nil error: NULL]; if (!RunTar(@[ @"-xf", path, @"-C", folder ], NULL)) { [fm removeItemAtPath: stage error: NULL]; return NO; } NSString *to = UniqueIn(dir, stem); [fm moveItemAtPath: folder toPath: to error: NULL]; result = to; }
			else { if (!RunTar(@[ @"-xf", path, @"-C", stage ], NULL)) { [fm removeItemAtPath: stage error: NULL]; return NO; } NSString *top = [tops anyObject]; NSString *to = UniqueIn(dir, top); [fm moveItemAtPath: [stage stringByAppendingPathComponent: top] toPath: to error: NULL]; result = to; }
			[fm removeItemAtPath: stage error: NULL]; [fm removeItemAtPath: [dir stringByAppendingPathComponent: @"__MACOSX"] error: NULL]; return YES;
		}, ^(BOOL ok) { if (done) done(ok ? result : nil); });
}
/* Compress: a zip next to the items ("Archive.zip" for several), the progress from the size of the file as it grows against the size of the items */
void TFCompressItems(NSArray *items, NSString *destDir, void (^done)(NSString *zip))
{
	NSString *base = [items count] == 1 ? [items[0] lastPathComponent] : @"Archive"; NSString *zip = UniqueIn(destDir, [base stringByAppendingPathExtension: @"zip"]); __block unsigned long long total = 0;
	TFRunJob([items count] == 1 ? [NSString stringWithFormat: @"Compressing “%@”", [items[0] lastPathComponent]] : [NSString stringWithFormat: @"Compressing %lu items", (unsigned long)[items count]], ^double { if (!total) return 0; struct stat sb; if (stat([zip fileSystemRepresentation], &sb)) return 0; return MIN(0.95, (double)sb.st_size / (total * 0.6)); },
		^BOOL(BOOL *stop) { for (NSString *p in items) total += SizeOf2(p); NSMutableArray *args = [NSMutableArray arrayWithObjects: @"-a", @"-cf", zip, nil]; for (NSString *p in items) { [args addObject: @"-C"]; [args addObject: [p stringByDeletingLastPathComponent]]; [args addObject: [p lastPathComponent]]; } return RunTar(args, NULL); },
		^(BOOL ok) { if (done) done(ok ? zip : nil); });
}
