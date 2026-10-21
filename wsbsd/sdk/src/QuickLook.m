/* QuickLook: generator bundles (.qlgenerator, loaded as CFPlugIns), the requests they fill in, built-in previews for images, text and RTF, and the preview panel.
 * Generators are looked up by content type in /usr/local/share/wsbsd/QuickLook, ~/Library/QuickLook, /Library/QuickLook and /System/Library/QuickLook; a generator's thumbnail context is a bitmap. */
#import <Quartz/Quartz.h>
#import <QuickLook/QuickLook.h>
#import <CoreServices/CoreServices.h>
#import <objc/runtime.h>

@interface WsbsdQLRequest : NSObject
{ @public CFBundleRef bundle; BOOL cancelled; NSURL *url; NSData *data; NSString *dataType; NSURL *dataURL; NSDictionary *props; CGImageRef image; CGContextRef ctx; }
@end
@implementation WsbsdQLRequest
- (void)dealloc { if (image) CGImageRelease(image); }
@end

/* ---------------- generator registry ---------------- */
@interface WsbsdQLGenerator : NSObject { @public NSString *path; NSArray *utis; CFPlugInRef plugIn; QLGeneratorInterfaceStruct *iface; void *instance; BOOL tried; } @end
@implementation WsbsdQLGenerator @end
static NSArray *gGenerators;
static NSArray *Generators(void)
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableArray *out = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager];
		NSString *env = [NSString stringWithUTF8String: getenv("WSBSD_QL_PATH") ?: ""];
		NSMutableArray *dirs = [NSMutableArray array]; for (NSString *d in [env componentsSeparatedByString: @":"]) if ([d length]) [dirs addObject: d];
		[dirs addObjectsFromArray: @[ @"/usr/local/share/wsbsd/QuickLook", [NSHomeDirectory() stringByAppendingPathComponent: @"Library/QuickLook"], @"/Library/QuickLook", @"/System/Library/QuickLook" ]];
		for (NSString *dir in dirs)
			for (NSString *f in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
				if (![f hasSuffix: @".qlgenerator"]) continue;
				NSString *p = [dir stringByAppendingPathComponent: f]; NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: [p stringByAppendingPathComponent: @"Contents/Info.plist"]] ?: [NSDictionary dictionaryWithContentsOfFile: [p stringByAppendingPathComponent: @"Info.plist"]]; NSMutableArray *utis = [NSMutableArray array];
				for (NSDictionary *t in info[@"CFBundleDocumentTypes"]) for (NSString *u in t[@"LSItemContentTypes"]) [utis addObject: u];
				WsbsdQLGenerator *g = [WsbsdQLGenerator new]; g->path = p; g->utis = utis; [out addObject: g];
			}
		gGenerators = out;
	});
	return gGenerators;
}
static BOOL Loaded(WsbsdQLGenerator *g)
{
	if (g->tried) return g->iface != NULL; g->tried = YES;
	CFURLRef u = (__bridge CFURLRef)[NSURL fileURLWithPath: g->path]; g->plugIn = CFPlugInCreate(NULL, u); if (!g->plugIn) return NO;
	CFArrayRef factories = CFPlugInFindFactoriesForPlugInTypeInPlugIn(kQLGeneratorTypeID, g->plugIn); if (!factories) return NO;
	for (CFIndex i = 0; i < CFArrayGetCount(factories) && !g->iface; i++) {
		void *inst = CFPlugInInstanceCreate(NULL, (CFUUIDRef)CFArrayGetValueAtIndex(factories, i), kQLGeneratorTypeID); if (!inst) continue;
		IUnknownVTbl **unk = (IUnknownVTbl **)inst; void *iface = NULL;
		if ((*unk)->QueryInterface(inst, CFUUIDGetUUIDBytes(kQLGeneratorCallbacksInterfaceID), &iface) == S_OK && iface) { g->iface = *(QLGeneratorInterfaceStruct **)iface; g->instance = iface; }
	}
	CFRelease(factories); return g->iface != NULL;
}
static WsbsdQLGenerator *GeneratorFor(NSString *uti)
{
	for (WsbsdQLGenerator *g in Generators()) for (NSString *u in g->utis) if (UTTypeEqual((__bridge CFStringRef)u, (__bridge CFStringRef)uti) || UTTypeConformsTo((__bridge CFStringRef)uti, (__bridge CFStringRef)u)) return g;
	return nil;
}
static NSString *UTIForURL(NSURL *url)
{
	BOOL dir = NO; [[NSFileManager defaultManager] fileExistsAtPath: [url path] isDirectory: &dir]; if (dir) return @"public.folder";
	NSString *ext = [url pathExtension]; CFStringRef u = [ext length] ? UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL) : NULL;
	NSString *r = u ? (NSString *)CFBridgingRelease(u) : nil;
	if (r && ![r hasPrefix: @"dyn."]) return r;
	static NSDictionary *tab; if (!tab) tab = @{ @"txt": @"public.plain-text", @"text": @"public.plain-text", @"md": @"public.plain-text", @"rtf": @"public.rtf", @"html": @"public.html", @"htm": @"public.html",
		@"png": @"public.png", @"jpg": @"public.jpeg", @"jpeg": @"public.jpeg", @"gif": @"com.compuserve.gif", @"tiff": @"public.tiff", @"tif": @"public.tiff", @"bmp": @"com.microsoft.bmp", @"c": @"public.c-source", @"h": @"public.c-header", @"m": @"public.objective-c-source" };
	NSString *m = tab[[ext lowercaseString]]; return m ?: (r ?: @"public.data");
}

/* ---------------- generator side API ---------------- */
CFBundleRef QLThumbnailRequestGetGeneratorBundle(QLThumbnailRequestRef r) { return ((__bridge WsbsdQLRequest *)r)->bundle; }
CFBundleRef QLPreviewRequestGetGeneratorBundle(QLPreviewRequestRef r) { return ((__bridge WsbsdQLRequest *)r)->bundle; }
Boolean QLThumbnailRequestIsCancelled(QLThumbnailRequestRef r) { return ((__bridge WsbsdQLRequest *)r)->cancelled; }
Boolean QLPreviewRequestIsCancelled(QLPreviewRequestRef r) { return ((__bridge WsbsdQLRequest *)r)->cancelled; }
static CGContextRef MakeContext(WsbsdQLRequest *q, CGSize size)
{
	size_t w = (size_t)MAX(1, ceil(size.width)), h = (size_t)MAX(1, ceil(size.height)); CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(cs); q->ctx = c; return c;
}
CGContextRef QLThumbnailRequestCreateContext(QLThumbnailRequestRef r, CGSize size, Boolean bitmap, CFDictionaryRef p) { (void)bitmap; (void)p; return MakeContext((__bridge WsbsdQLRequest *)r, size); }
CGContextRef QLPreviewRequestCreateContext(QLPreviewRequestRef r, CGSize size, Boolean bitmap, CFDictionaryRef p) { (void)bitmap; (void)p; return MakeContext((__bridge WsbsdQLRequest *)r, size); }
static void Flush(WsbsdQLRequest *q, CGContextRef c) { if (q->image) CGImageRelease(q->image); q->image = CGBitmapContextCreateImage(c); }
void QLThumbnailRequestFlushContext(QLThumbnailRequestRef r, CGContextRef c) { Flush((__bridge WsbsdQLRequest *)r, c); }
void QLPreviewRequestFlushContext(QLPreviewRequestRef r, CGContextRef c) { Flush((__bridge WsbsdQLRequest *)r, c); }
void QLThumbnailRequestSetImage(QLThumbnailRequestRef r, CGImageRef img, CFDictionaryRef p) { WsbsdQLRequest *q = (__bridge WsbsdQLRequest *)r; if (q->image) CGImageRelease(q->image); q->image = CGImageRetain(img); (void)p; }
void QLThumbnailRequestSetImageWithData(QLThumbnailRequestRef r, CFDataRef d, CFDictionaryRef p) { WsbsdQLRequest *q = (__bridge WsbsdQLRequest *)r; q->data = (__bridge NSData *)d; (void)p; }
void QLThumbnailRequestSetImageAtURL(QLThumbnailRequestRef r, CFURLRef u, CFDictionaryRef p) { WsbsdQLRequest *q = (__bridge WsbsdQLRequest *)r; q->dataURL = (__bridge NSURL *)u; (void)p; }
void QLPreviewRequestSetDataRepresentation(QLPreviewRequestRef r, CFDataRef d, CFStringRef t, CFDictionaryRef p) { WsbsdQLRequest *q = (__bridge WsbsdQLRequest *)r; q->data = [(__bridge NSData *)d copy]; q->dataType = [(__bridge NSString *)t copy]; q->props = [(__bridge NSDictionary *)p copy]; }
void QLPreviewRequestSetURLRepresentation(QLPreviewRequestRef r, CFURLRef u, CFStringRef t, CFDictionaryRef p) { WsbsdQLRequest *q = (__bridge WsbsdQLRequest *)r; q->dataURL = (__bridge NSURL *)u; q->dataType = [(__bridge NSString *)t copy]; q->props = [(__bridge NSDictionary *)p copy]; }

/* ---------------- previews ---------------- */
@implementation WsbsdQLPreview
{ NSInteger _kind; NSAttributedString *_text; NSImage *_image; NSString *_type; }
- (NSInteger)kind { return _kind; } - (NSAttributedString *)text { return _text; } - (NSImage *)image { return _image; } - (NSString *)contentType { return _type; }
static NSAttributedString *PlainText(NSData *d)
{
	NSString *s = [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding]; if (!s) s = [[NSString alloc] initWithData: d encoding: NSISOLatin1StringEncoding]; if (!s) return nil;
	return [[NSAttributedString alloc] initWithString: s attributes: @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize: 12], NSForegroundColorAttributeName: [NSColor textColor] }];
}
- (instancetype)initWithData:(NSData *)d type:(NSString *)t
{
	if (!(self = [super init])) return nil; _type = t;
	if (UTTypeConformsTo((__bridge CFStringRef)t, CFSTR("public.rtf"))) { NSAttributedString *a = [[NSAttributedString alloc] initWithRTF: d documentAttributes: NULL]; if (a) { _kind = 1; _text = a; } }
	else if (UTTypeConformsTo((__bridge CFStringRef)t, CFSTR("public.image"))) { NSImage *i = [[NSImage alloc] initWithData: d]; if (i) { _kind = 2; _image = i; } }
	else if (UTTypeConformsTo((__bridge CFStringRef)t, CFSTR("public.text")) || UTTypeConformsTo((__bridge CFStringRef)t, CFSTR("public.html"))) { NSAttributedString *a = PlainText(d); if (a) { _kind = 1; _text = a; } }
	return self;
}
+ (WsbsdQLPreview *)previewForURL:(NSURL *)url
{
	NSString *uti = UTIForURL(url); WsbsdQLGenerator *g = GeneratorFor(uti);
	if (g && Loaded(g) && g->iface->GeneratePreviewForURL) {
		WsbsdQLRequest *q = [WsbsdQLRequest new]; q->bundle = g->plugIn; q->url = url;
		g->iface->GeneratePreviewForURL(g->instance, (__bridge QLPreviewRequestRef)q, (__bridge CFURLRef)url, (__bridge CFStringRef)uti, NULL);
		NSData *d = q->data ?: (q->dataURL ? [NSData dataWithContentsOfURL: q->dataURL] : nil);
		if (d && q->dataType) { WsbsdQLPreview *p = [[WsbsdQLPreview alloc] initWithData: d type: q->dataType]; if (p->_kind) return p; }
		if (q->image) { NSImage *i = [[NSImage alloc] initWithSize: NSMakeSize(CGImageGetWidth(q->image), CGImageGetHeight(q->image))]; [i lockFocus]; CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], CGRectMake(0, 0, CGImageGetWidth(q->image), CGImageGetHeight(q->image)), q->image); [i unlockFocus];
			WsbsdQLPreview *p = [WsbsdQLPreview new]; p->_kind = 2; p->_image = i; return p; }
	}
	WsbsdQLPreview *none = [WsbsdQLPreview new]; BOOL dir = NO; if (![[NSFileManager defaultManager] fileExistsAtPath: [url path] isDirectory: &dir] || dir) return none;
	NSData *d = [NSData dataWithContentsOfURL: url]; if (!d) return none;
	if (UTTypeConformsTo((__bridge CFStringRef)uti, CFSTR("public.image"))) { WsbsdQLPreview *p = [[WsbsdQLPreview alloc] initWithData: d type: @"public.image"]; if (p->_kind) return p; }
	if (UTTypeConformsTo((__bridge CFStringRef)uti, CFSTR("public.rtf"))) { WsbsdQLPreview *p = [[WsbsdQLPreview alloc] initWithData: d type: @"public.rtf"]; if (p->_kind) return p; }
	NSData *head = [d length] > 1048576 ? [d subdataWithRange: NSMakeRange(0, 1048576)] : d;                    /* text: valid UTF-8 without NUL bytes in the first megabyte */
	if (memchr([head bytes], 0, [head length]) == NULL) { WsbsdQLPreview *p = [[WsbsdQLPreview alloc] initWithData: head type: @"public.plain-text"]; if (p->_kind) return p; }
	return none;
}
@end

/* thumbnails: a generator's bitmap, else the file's own image scaled down, else a text excerpt drawn by AppKit */
CGImageRef QLThumbnailImageCreate(CFAllocatorRef a, CFURLRef u, CGSize maxSize, CFDictionaryRef o)
{
	(void)a; (void)o; NSURL *url = (__bridge NSURL *)u; NSString *uti = UTIForURL(url); WsbsdQLGenerator *g = GeneratorFor(uti);
	if (g && Loaded(g) && g->iface->GenerateThumbnailForURL) {
		WsbsdQLRequest *q = [WsbsdQLRequest new]; q->bundle = g->plugIn; q->url = url;
		g->iface->GenerateThumbnailForURL(g->instance, (__bridge QLThumbnailRequestRef)q, u, (__bridge CFStringRef)uti, NULL, maxSize);
		if (q->image) return CGImageRetain(q->image);
	}
	WsbsdQLPreview *p = [WsbsdQLPreview previewForURL: url]; if (!p.kind) return NULL;
	size_t w = (size_t)MAX(1, maxSize.width), h = (size_t)MAX(1, maxSize.height); CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(cs); if (!c) return NULL;
	NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort: c flipped: NO]; [NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext: gc];
	if (p.kind == 2) { NSSize s = [p.image size]; CGFloat k = MIN(1.0, MIN(maxSize.width / s.width, maxSize.height / s.height)); [p.image drawInRect: NSMakeRect(0, 0, s.width * k, s.height * k) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
	else { [[NSColor whiteColor] set]; NSRectFill(NSMakeRect(0, 0, w, h)); [[p.text attributedSubstringFromRange: NSMakeRange(0, MIN([p.text length], 600))] drawInRect: NSMakeRect(4, 4, w - 8, h - 8)]; }
	[NSGraphicsContext restoreGraphicsState]; CGImageRef img = CGBitmapContextCreateImage(c); CGContextRelease(c); return img;
}

/* ---------------- the panel ---------------- */
@implementation QLPreviewPanel
{ NSScrollView *_scroll; NSTextView *_textView; NSImageView *_imageView; NSTextField *_message; id _controller; id<QLPreviewItem> _item; }
@synthesize dataSource, delegate, currentPreviewItemIndex;
static QLPreviewPanel *sShared;
+ (QLPreviewPanel *)sharedPreviewPanel { if (!sShared) sShared = [[QLPreviewPanel alloc] init]; return sShared; }
+ (BOOL)sharedPreviewPanelExists { return sShared != nil; }
- (instancetype)init
{
	if (!(self = [super initWithContentRect: NSMakeRect(0, 0, 640, 480) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask backing: NSBackingStoreBuffered defer: YES])) return nil;
	[self setReleasedWhenClosed: NO]; [self setHidesOnDeactivate: NO]; [self setLevel: NSFloatingWindowLevel]; [self setTitle: @"Quick Look"]; [self setMinSize: NSMakeSize(200, 120)];
	NSView *cv = [self contentView]; NSRect b = [cv bounds];
	_scroll = [[NSScrollView alloc] initWithFrame: b]; [_scroll setHasVerticalScroller: YES]; [_scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [_scroll setBorderType: NSNoBorder];
	_textView = [[NSTextView alloc] initWithFrame: b]; [_textView setEditable: NO]; [_textView setSelectable: YES]; [_textView setAutoresizingMask: NSViewWidthSizable]; [_textView setMinSize: NSMakeSize(0, b.size.height)]; [_textView setMaxSize: NSMakeSize(1e7, 1e7)];
	[_textView setVerticallyResizable: YES]; [[_textView textContainer] setWidthTracksTextView: YES]; [_scroll setDocumentView: _textView];
	_imageView = [[NSImageView alloc] initWithFrame: b]; [_imageView setImageScaling: NSImageScaleProportionallyUpOrDown]; [_imageView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	_message = [NSTextField labelWithString: @""]; [_message setAlignment: NSTextAlignmentCenter]; [_message setFrame: NSMakeRect(0, b.size.height / 2 - 12, b.size.width, 24)]; [_message setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin];
	return self;
}
- (id<QLPreviewItem>)currentPreviewItem { return _item; }
- (id)currentController { return _controller; }
- (void)updateController                                                                                      /* the first object of the key window's responder chain that accepts control */
{
	id found = nil; NSWindow *w = [NSApp keyWindow]; if (w == self) w = [NSApp mainWindow];
	for (NSResponder *r = [w firstResponder]; r && !found; r = [r nextResponder]) if ([r respondsToSelector: @selector(acceptsPreviewPanelControl:)] && [(id)r acceptsPreviewPanelControl: self]) found = r;
	if (!found && [w respondsToSelector: @selector(acceptsPreviewPanelControl:)] && [(id)w acceptsPreviewPanelControl: self]) found = w;
	if (!found && [[w delegate] respondsToSelector: @selector(acceptsPreviewPanelControl:)] && [(id)[w delegate] acceptsPreviewPanelControl: self]) found = [w delegate];
	if (found == _controller) return;
	if ([_controller respondsToSelector: @selector(endPreviewPanelControl:)]) [_controller endPreviewPanelControl: self];
	_controller = found; if ([_controller respondsToSelector: @selector(beginPreviewPanelControl:)]) [_controller beginPreviewPanelControl: self];
}
- (void)reloadData
{
	NSInteger n = dataSource ? [dataSource numberOfPreviewItemsInPreviewPanel: self] : 0;
	if (currentPreviewItemIndex >= n) currentPreviewItemIndex = n - 1; if (currentPreviewItemIndex < 0) currentPreviewItemIndex = 0;
	[self refreshCurrentPreviewItem];
}
- (void)refreshCurrentPreviewItem
{
	NSInteger n = dataSource ? [dataSource numberOfPreviewItemsInPreviewPanel: self] : 0;
	_item = (n > 0 && currentPreviewItemIndex < n) ? [dataSource previewPanel: self previewItemAtIndex: currentPreviewItemIndex] : nil;
	NSURL *url = [_item previewItemURL]; NSString *title = [_item respondsToSelector: @selector(previewItemTitle)] ? [_item previewItemTitle] : nil;
	[self setTitle: title ?: ([url lastPathComponent] ?: @"Quick Look")];
	[[self contentView] setSubviews: @[]];
	if (!url) { [_message setStringValue: @"No Preview"]; [[self contentView] addSubview: _message]; return; }
	WsbsdQLPreview *p = [WsbsdQLPreview previewForURL: url];
	if (p.kind == 1) { [[_textView textStorage] setAttributedString: p.text]; [_scroll setFrame: [[self contentView] bounds]]; [[self contentView] addSubview: _scroll]; }
	else if (p.kind == 2) { [_imageView setImage: p.image]; [_imageView setFrame: [[self contentView] bounds]]; [[self contentView] addSubview: _imageView]; }
	else { [_message setStringValue: [NSString stringWithFormat: @"%@\nNo Preview Available", [url lastPathComponent]]]; [_message setFrame: NSMakeRect(0, [[self contentView] bounds].size.height / 2 - 20, [[self contentView] bounds].size.width, 40)]; [[self contentView] addSubview: _message]; }
}
- (void)makeKeyAndOrderFront:(id)sender { [self updateController]; [self reloadData]; [super makeKeyAndOrderFront: sender]; }
- (void)orderFront:(id)sender { [self updateController]; [self reloadData]; [super orderFront: sender]; }
- (void)close
{
	if ([_controller respondsToSelector: @selector(endPreviewPanelControl:)]) [_controller endPreviewPanelControl: self]; _controller = nil; [super close];
}
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)keyDown:(NSEvent *)e
{
	if ([delegate respondsToSelector: @selector(previewPanel:handleEvent:)] && [delegate previewPanel: self handleEvent: e]) return;
	NSString *c = [e charactersIgnoringModifiers]; if (![c length]) { [super keyDown: e]; return; }
	unichar k = [c characterAtIndex: 0]; NSInteger n = dataSource ? [dataSource numberOfPreviewItemsInPreviewPanel: self] : 0;
	if (k == ' ' || k == 27) [self close];
	else if ((k == NSLeftArrowFunctionKey || k == NSUpArrowFunctionKey) && currentPreviewItemIndex > 0) { currentPreviewItemIndex--; [self refreshCurrentPreviewItem]; }
	else if ((k == NSRightArrowFunctionKey || k == NSDownArrowFunctionKey) && currentPreviewItemIndex + 1 < n) { currentPreviewItemIndex++; [self refreshCurrentPreviewItem]; }
	else [super keyDown: e];
}
@end
