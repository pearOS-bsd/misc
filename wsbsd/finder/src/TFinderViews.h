/* The views of the Finder window, drawn after the real one (measured on a macOS 26 Finder window by the accessibility tree and a pixel capture, see docs/desktop/finder-window-ax-measurements.txt):
 * a window of 1022 x 552 with a toolbar 52 high, a floating sidebar 238 wide, an icon grid of 112 x 126 cells and a path bar 30 high. The controller (TBrowserWindowController) owns them. */
#import <Cocoa/Cocoa.h>

#define TF_ATTR __attribute__((unused))
@interface NSObject (TFAppearance) + (BOOL)isDark; @end
@interface NSColor (TFAccent) + (NSColor *)controlAccentColor; @end
TF_ATTR static NSColor *TFRGB(int r, int g, int b) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: 1]; }
TF_ATTR static NSColor *TFRGBA(int r, int g, int b, double a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }
TF_ATTR static BOOL TFDark(void) { Class k = NSClassFromString(@"WsdFinderSupport"); if (k && [k respondsToSelector: @selector(isDark)]) return [(id)k isDark]; const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }
#define TF_CONTENT  (TFDark() ? TFRGB(30, 30, 30) : TFRGB(255, 255, 255))
#define TF_SIDEBAR  (TFDark() ? TFRGB(38, 38, 38) : TFRGB(236, 236, 238))
#define TF_PILL     (TFDark() ? TFRGB(60, 60, 60) : TFRGB(240, 240, 242))
#define TF_PATHBAR  (TFDark() ? TFRGB(38, 38, 38) : TFRGB(246, 246, 246))
#define TF_LINE     (TFDark() ? TFRGBA(255, 255, 255, 0.10) : TFRGBA(0, 0, 0, 0.10))
#define TF_TEXT     (TFDark() ? TFRGBA(255, 255, 255, 0.85) : TFRGBA(0, 0, 0, 0.85))
#define TF_DIM      (TFDark() ? TFRGBA(255, 255, 255, 0.42) : TFRGBA(0, 0, 0, 0.45))
#define TF_ACCENT   ([NSColor controlAccentColor])
#define TF_BLUE     ([NSColor controlAccentColor])

@interface NSString (TFNameOrder) - (NSComparisonResult)tfNameCompare:(NSString *)other; @end
NSString *TFSizeString(unsigned long long bytes);
NSString *TFDateString(NSDate *d);
NSString *TFKindString(NSString *path, BOOL dir);
@interface NSObject (TFDropFiles) + (BOOL)dropFiles:(NSArray *)paths atScreenPoint:(NSPoint)p; @end
@interface NSObject (TFTags) + (NSArray *)tagsOfPath:(NSString *)p; + (void)setTags:(NSArray *)n ofPath:(NSString *)p; + (NSArray *)tagNames; + (NSColor *)colorOfTag:(NSString *)n; + (void)drawTagDots:(NSArray *)n rightEdge:(double)x centerY:(double)y; + (double)tagDotsWidth:(NSArray *)n; @end
NSArray *TFTagsOf(NSString *path);
void TFSetTags(NSArray *names, NSString *path);
NSArray *TFPathsTagged(NSString *tag);
NSArray *TFRecentPaths(void);
NSWindow *TFOpenInfoWindow(NSString *path);
void TFCopyItems(NSArray *srcs, NSString *destDir, BOOL move, void (^completion)(NSArray *ops));
NSWindow *TFOpenQuickLook(NSString *path);
void TFOpenSettings(void);
@class TIconView;
void TFOpenViewOptions(TIconView *view, NSString *folderName, void (^changed)(void));
void TFOpenDesktopViewOptions(TIconView *view, void (^changed)(void));
@interface NSObject (TFItemMenu) - (NSMenu *)itemContextMenu; @end
void TFOpenFolderViewOptions(NSInteger mode, NSString *folderName, NSDictionary *(^get)(void), void (^set)(NSString *, id));
id TFPref(NSString *key, id def);
BOOL TFPrefBool(NSString *key, BOOL def);
void TFSetPref(NSString *key, id value);
BOOL TFPreviewOpt(NSString *key);
BOOL TFPreviewOptionsVisible(void);
void TFTogglePreviewOptions(NSString *kindTitle, void (^changed)(void));
void TFDrawIcon(NSString *path, NSRect r);
@interface NSObject (TFRound) + (void)roundWindow:(NSWindow *)w radius:(int)r; @end
NSArray *TFVolumes(void);
NSString *TFKindCategory(NSString *path, BOOL dir);
BOOL TFIsPackage(NSString *path);
NSArray *TFAppsForFile(NSString *path);
void TFOpenPath(NSString *path);
void TFShowSharePopover(NSArray *paths, NSRect rect, NSView *view, id owner);
void TFShowTagsPopover(NSArray *paths, NSRect rect, NSView *view, id owner);
NSArray *TFBulkRenamedNames(NSArray *paths, NSDictionary *params);
void TFBulkRename(NSArray *paths, void (^done)(NSArray *changes));
void TFConnectToServer(NSString *last, void (^done)(NSString *address));
void TFAsk(NSString *title, NSString *message, NSArray *fields, NSString *okTitle, void (^done)(NSArray *values));
void TFSetOpenWith(NSString *path, NSString *app, BOOL all);
NSString *TFDisplayName(NSString *path);
NSString *TFShownName(NSString *name);
BOOL TFEject(NSString *mount);
void TFPopupMenu(NSView *view, NSPoint p, NSMenu *menu);
BOOL TFSymbol(NSString *name, NSRect cell, CGFloat pt, NSColor *tint);
BOOL TFSymbolW(NSString *name, NSRect cell, CGFloat pt, int weight, NSColor *tint);
NSImage *TFIcon(NSString *path);

/* .DS_Store of a folder */
@interface TDSStore : NSObject { @public NSString *_path; NSMutableArray *_records; }
+ (instancetype)storeForFolder:(NSString *)folder;
- (instancetype)initWithPath:(NSString *)path;
- (id)valueForName:(NSString *)name sid:(NSString *)sid;
- (void)setValue:(id)v type:(NSString *)t forName:(NSString *)name sid:(NSString *)sid;
- (void)removeName:(NSString *)name sid:(NSString *)sid;
- (BOOL)iconLocationOfName:(NSString *)name x:(int *)x y:(int *)y;
- (void)setIconLocation:(NSPoint)center ofName:(NSString *)name;
- (NSMutableDictionary *)plistForName:(NSString *)name sid:(NSString *)sid;
- (void)setPlist:(NSDictionary *)pl forName:(NSString *)name sid:(NSString *)sid;
- (BOOL)write;
@end

@protocol TIconViewDelegate <NSObject>
- (void)iconViewOpenItem:(NSString *)path;
- (void)iconViewSelectionChanged:(NSArray *)paths;
@optional
- (void)prepareContextMenu:(NSMenu *)menu;
- (void)finderExternalDropPaths:(NSArray *)paths atWindowPoint:(NSPoint)p;
- (NSMenu *)backgroundContextMenu;
- (void)iconViewRename:(NSString *)path to:(NSString *)name;
- (BOOL)iconViewDropPaths:(NSArray *)paths intoFolder:(NSString *)folder atWindowPoint:(NSPoint)p copy:(BOOL)copy;
@end
@protocol TSidebarDelegate <NSObject> - (void)sidebarGoTo:(NSString *)path; @end
@protocol TPathBarDelegate <NSObject> - (void)pathBarGoTo:(NSString *)path; @end

/* a view that scrolls its own content and draws the overlay scroller of the Finder (a thumb 10 wide at the right edge, no track) */
@interface TScrollBase : NSView { @public CGFloat off, topInset; BOOL dragging; CGFloat dragGrab; }
- (CGFloat)contentHeight;
- (void)drawContent:(NSRect)dirty;
- (void)contentMouseDown:(NSPoint)p event:(NSEvent *)e;
- (void)scrollTo:(CGFloat)y;
- (void)reveal:(NSRect)r;
@end

@interface TIconView : TScrollBase { @public BOOL _snap; __weak id<TIconViewDelegate> delegate; NSString *filter; NSMutableArray *_items; NSMutableIndexSet *_sel; NSInteger _anchor; NSString *_folder, *_arrange; NSRect _band; BOOL _dragging; NSInteger _dropTarget; double _animStart; NSTimer *_animTimer; CGFloat _isz, _grid, _textSize; BOOL _showInfo, _showPreview, _labelRight; NSString *emptyMessage; NSString *_group; NSArray *_gpos, *_heads; CGFloat _groupBottom; BOOL desktop; NSArray *_prefix; }
- (void)applyOptions;
- (void)setSnapToGrid:(BOOL)on;
- (void)setGroup:(NSString *)g;
- (void)reloadKeepingSelectionOrFolder:(NSString *)folder;
- (BOOL)beginRename:(NSString *)path;
- (void)setIconSize:(CGFloat)z;
- (CGFloat)iconSize;
- (void)arrangeBy:(NSString *)key;
- (void)cleanUp:(BOOL)selectionOnly;
- (void)setFolder:(NSString *)folder;
- (void)setPaths:(NSArray *)paths;
- (NSArray *)selectedPaths;
- (void)reloadKeepingSelection;
@end

@interface TListView : TScrollBase { @public CGFloat _rowH, _listText; BOOL _bigIcons; @public __weak id<TIconViewDelegate> delegate; NSString *filter; NSMutableArray *_items; NSMutableIndexSet *_sel; NSString *_sortKey; BOOL _asc; NSInteger _anchor; NSMutableSet *_exp; NSMutableDictionary *_kids; NSMutableArray *_roots; NSMutableArray *_colDefs; NSString *_colKey, *_folder; NSInteger _dropRow; @public NSString *_group; }
- (void)setGroup:(NSString *)g;
- (void)setFolder:(NSString *)folder;
- (void)setPaths:(NSArray *)paths;
- (NSArray *)selectedPaths;
- (BOOL)beginRename:(NSString *)path;
- (void)sortByColumn:(NSString *)col;
- (void)loadOptions;
- (void)_saveColumns;
@end

/* the column view: one column per level, the last selected file shown as a preview */
@interface TColumnView : NSView { @public __weak id<TIconViewDelegate> delegate; NSString *filter; NSMutableArray *_cols; CGFloat _hoff; }
- (void)setFolder:(NSString *)folder;
- (NSArray *)selectedPaths;
@end

/* the gallery: the selected item large above a strip of thumbnails, its information to the right */
@interface TGalleryView : NSView { @public __weak id<TIconViewDelegate> delegate; NSString *filter; NSMutableArray *_paths; NSInteger _sel; CGFloat _hoff; BOOL _more; NSRect _moreRect; NSImage *_big; NSString *_bigPath; }
- (void)setFolder:(NSString *)folder;
- (void)setPaths:(NSArray *)paths;
- (NSArray *)selectedPaths;
@end

@interface TSidebarView : TScrollBase { @public NSString *current; __weak id<TSidebarDelegate> delegate; NSArray *_rows; NSString *_sig; NSInteger _hoverHead; }
- (NSString *)dropPathAtWindowPoint:(NSPoint)p;
@end

/* the tab bar of a window with several tabs */
@interface TTabBar : NSView { @public NSArray *titles; NSInteger selected; id target; }
@end

/* the bar under the toolbar while searching: where to look (This Mac or the folder) */
@interface TSearchBar : NSView { @public NSString *folderName; NSInteger scope; id target; NSString *info; NSString *kind; }
@end

/* the line under the items: how many, how many selected, how much room is left */
@interface TStatusBarView : NSView { @public NSString *text; BOOL showSlider; double value; id target; }
@end

@interface TPathBarView : NSView { @public NSString *path; __weak id<TPathBarDelegate> delegate; NSArray *_paths; NSMutableArray *_rects; }
- (void)setPath:(NSString *)p;
@end

@interface TToolbarView : NSView { @public NSString *title; BOOL canBack, canForward; id target; NSInteger mode; NSTextField *search; BOOL searching; NSInteger hot; NSRect _pressed; BOOL trashMode; NSSegmentedControl *modeSeg, *navSeg, *actSeg, *grpSeg, *srchSeg; }
- (void)setSearching:(BOOL)on;
- (NSRect)buttonRect:(int)i;
@end

/* the three window buttons, the 1 px rim and the rounded corners, on top of everything */
@interface TWindowTrim : NSView @end

/* the preview pane (View > Show Preview): the picture, name, kind, size and information of the selected file, or a count for several */
@interface TPreviewPane : NSView { @public NSArray *paths; NSString *folder; CGFloat _scroll, _content; BOOL _more; } - (void)_drawQuickBar:(BOOL)dir path:(NSString *)p; @end

/* the desktop picture */
NSString *TFWallpaperPath(void);
NSImage *TFWallpaperImage(void);
NSImage *TFWallpaperSource(void);
void TFWriteWallpaperGrid(NSSize screen);
@interface TWallpaperView : NSView @end

/* the root view of a Finder window: files dragged in from other programs */
@interface TFinderRoot : NSView @end

/* a borderless window the Finder moves and resizes itself */
@interface TFinderWindow : NSWindow { BOOL _zoomed, _mini; NSRect _savedFrame; } @end
