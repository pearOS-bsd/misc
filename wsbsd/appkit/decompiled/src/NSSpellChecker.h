/*
 * NSSpellChecker.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSpellChecker.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSpellChecker_interface.txt. The class also owns the spelling /
 * substitutions panels (NSPanel/NSTableView/… ivars) and talks to the
 * NSSpellServer daemon.
 *
 * Measured on this Mac: +sharedSpellCheckerExists is NO until +sharedSpellChecker
 * is first called; +uniqueSpellDocumentTag returns a monotonic counter from 1;
 * automaticallyIdentifiesLanguages defaults to YES. The actual checking
 * (checkSpellingOfString:…, learnWord: via NSSpellServer) and the system
 * language/replacement lists are TODO(stage2); this core keeps the document-tag
 * counter, the learned/ignored-word bookkeeping and the config value model.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSView, NSViewController, NSPanel;

@interface NSSpellChecker : NSObject

@property (class, readonly, strong) NSSpellChecker *sharedSpellChecker;
@property (class, readonly) BOOL sharedSpellCheckerExists;
@property (class, readonly) NSInteger uniqueSpellDocumentTag;

@property BOOL automaticallyIdentifiesLanguages;             /* default YES */
@property (nullable, strong) NSView *accessoryView;
@property (nullable, strong) NSViewController *substitutionsPanelAccessoryViewController;

@property (readonly, copy) NSArray<NSString *> *availableLanguages;       /* stage2 */
@property (readonly, copy) NSArray<NSString *> *userPreferredLanguages;   /* stage2 */
@property (readonly, copy) NSDictionary *userReplacementsDictionary;      /* stage2 */

- (NSString *)language;
- (BOOL)setLanguage:(NSString *)language;

- (void)learnWord:(NSString *)word;
- (void)unlearnWord:(NSString *)word;
- (BOOL)hasLearnedWord:(NSString *)word;

- (void)ignoreWord:(NSString *)wordToIgnore inSpellDocumentWithTag:(NSInteger)tag;
- (nullable NSArray<NSString *> *)ignoredWordsInSpellDocumentWithTag:(NSInteger)tag;
- (void)setIgnoredWords:(nullable NSArray<NSString *> *)words inSpellDocumentWithTag:(NSInteger)tag;
- (void)closeSpellDocumentWithTag:(NSInteger)tag;

@end

NS_ASSUME_NONNULL_END
