/*
 * NSHelpManager.m — 1:1 (core). See NSHelpManager.h for the interface evidence.
 *
 * sharedHelpManager is the process singleton. Context help is stored in a
 * weak-key→strong-value map (_helpMapTable) so an object can carry help text
 * without being retained by the manager. contextHelpModeActive is a global flag.
 * The help window / help book presentation and the help-cursor event handling
 * are stage2.
 */
#import "NSHelpManager.h"

static BOOL sContextHelpModeActive = NO;

@implementation NSHelpManager {
    NSMapTable *_helpMapTable;   /* object (weak) -> NSAttributedString (strong) */
}

- (instancetype)init
{
    self = [super init];
    if (self) { _helpMapTable = [NSMapTable weakToStrongObjectsMapTable]; }
    return self;
}

+ (NSHelpManager *)sharedHelpManager
{
    static NSHelpManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[NSHelpManager alloc] init]; });
    return shared;
}

+ (BOOL)isContextHelpModeActive { return sContextHelpModeActive; }
+ (void)setContextHelpModeActive:(BOOL)active { sContextHelpModeActive = active; }

- (void)setContextHelp:(NSAttributedString *)helpString forObject:(id)object
{
    if (!object || !helpString) return;
    [_helpMapTable setObject:[helpString copy] forKey:object];
}

- (NSAttributedString *)contextHelpForObject:(id)object
{
    return object ? [_helpMapTable objectForKey:object] : nil;
}

- (void)removeContextHelpForObject:(id)object
{
    if (object) [_helpMapTable removeObjectForKey:object];
}

@end
