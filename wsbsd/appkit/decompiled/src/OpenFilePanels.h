#import "NSSavePanel.h"
#import "NSOpenPanel.h"
@interface NSSavePanel (OpenService)
+ (instancetype)savePanel;
- (NSInteger)runModal;
- (NSURL *)URL;
- (void)beginWithCompletionHandler:(void (^)(NSInteger))h;
- (void)beginSheetModalForWindow:(NSWindow *)w completionHandler:(void (^)(NSInteger))h;
- (void)setAllowedFileTypes:(NSArray *)t;
- (void)setPrompt:(NSString *)p;
- (void)setMessage:(NSString *)m;
@end
@interface NSOpenPanel (OpenService)
+ (instancetype)openPanel;
- (void)setCanChooseFiles:(BOOL)b;
- (void)setCanChooseDirectories:(BOOL)b;
- (void)setAllowsMultipleSelection:(BOOL)b;
- (NSArray *)URLs;
@end
