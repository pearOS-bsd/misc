/*
 * NSSpellChecker.m — behavioral-1:1 core.
 * See NSSpellChecker.h (NSSpellServer checking engine + system lists are stage2).
 */

#import "NSSpellChecker.h"

static NSSpellChecker *gShared = nil;
static NSInteger gTagCounter = 0;

@implementation NSSpellChecker {
    BOOL _automaticallyIdentifiesLanguages;
    NSView *_accessoryView;
    NSViewController *_substitutionsPanelAccessoryViewController;
    NSString *_language;
    NSMutableSet<NSString *> *_learnedWords;
    NSMutableDictionary<NSNumber *, NSMutableSet<NSString *> *> *_ignoredByTag;
}

+ (NSSpellChecker *)sharedSpellChecker
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gShared = [[NSSpellChecker alloc] _init]; });
    return gShared;
}

+ (BOOL)sharedSpellCheckerExists { return gShared != nil; }

+ (NSInteger)uniqueSpellDocumentTag { return ++gTagCounter; }   /* monotonic from 1 */

- (instancetype)_init
{
    self = [super init];
    if (self) {
        _automaticallyIdentifiesLanguages = YES;   /* measured */
        _language = @"en";
        _learnedWords = [NSMutableSet set];
        _ignoredByTag = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)automaticallyIdentifiesLanguages { return _automaticallyIdentifiesLanguages; }
- (void)setAutomaticallyIdentifiesLanguages:(BOOL)v { _automaticallyIdentifiesLanguages = v; }

- (NSView *)accessoryView { return _accessoryView; }
- (void)setAccessoryView:(NSView *)v { _accessoryView = v; }
- (NSViewController *)substitutionsPanelAccessoryViewController { return _substitutionsPanelAccessoryViewController; }
- (void)setSubstitutionsPanelAccessoryViewController:(NSViewController *)v { _substitutionsPanelAccessoryViewController = v; }

- (NSArray<NSString *> *)availableLanguages { return @[]; /* stage2: system dictionaries */ }
- (NSArray<NSString *> *)userPreferredLanguages { return @[]; /* stage2 */ }
- (NSDictionary *)userReplacementsDictionary { return @{}; /* stage2: user config */ }

- (NSString *)language { return _language; }
- (BOOL)setLanguage:(NSString *)language { _language = [language copy]; return YES; /* stage2: validate against installed dicts */ }

/* --- learned words (in-memory; NSSpellServer-backed persistence is stage2) --- */

- (void)learnWord:(NSString *)word { if (word) [_learnedWords addObject:word]; }
- (void)unlearnWord:(NSString *)word { if (word) [_learnedWords removeObject:word]; }
- (BOOL)hasLearnedWord:(NSString *)word { return word != nil && [_learnedWords containsObject:word]; }

/* --- per-document ignored words --- */

- (NSMutableSet<NSString *> *)_ignoredSetForTag:(NSInteger)tag
{
    NSNumber *key = @(tag);
    NSMutableSet *set = _ignoredByTag[key];
    if (!set) { set = [NSMutableSet set]; _ignoredByTag[key] = set; }
    return set;
}

- (void)ignoreWord:(NSString *)wordToIgnore inSpellDocumentWithTag:(NSInteger)tag
{
    if (wordToIgnore) [[self _ignoredSetForTag:tag] addObject:wordToIgnore];
}

- (NSArray<NSString *> *)ignoredWordsInSpellDocumentWithTag:(NSInteger)tag
{
    NSMutableSet *set = _ignoredByTag[@(tag)];
    return set ? set.allObjects : nil;
}

- (void)setIgnoredWords:(NSArray<NSString *> *)words inSpellDocumentWithTag:(NSInteger)tag
{
    _ignoredByTag[@(tag)] = words ? [NSMutableSet setWithArray:words] : [NSMutableSet set];
}

- (void)closeSpellDocumentWithTag:(NSInteger)tag { [_ignoredByTag removeObjectForKey:@(tag)]; }

@end
