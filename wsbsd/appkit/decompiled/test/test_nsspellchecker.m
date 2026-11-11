/* test_nsspellchecker.m — behaviour checks for NSSpellChecker core */
#import "../src/NSSpellChecker.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* uniqueSpellDocumentTag is monotonic (does not require the singleton) */
        NSInteger t1 = [NSSpellChecker uniqueSpellDocumentTag];
        NSInteger t2 = [NSSpellChecker uniqueSpellDocumentTag];
        CHECK(t2 == t1 + 1, "uniqueSpellDocumentTag monotonic");

        /* shared singleton + existence flag */
        CHECK([NSSpellChecker sharedSpellCheckerExists] == NO || [NSSpellChecker sharedSpellCheckerExists] == YES, "exists query safe");
        NSSpellChecker *s = [NSSpellChecker sharedSpellChecker];
        CHECK(s != nil && s == [NSSpellChecker sharedSpellChecker], "sharedSpellChecker is a singleton");
        CHECK([NSSpellChecker sharedSpellCheckerExists], "sharedSpellCheckerExists YES after creation");

        /* measured defaults */
        CHECK(s.automaticallyIdentifiesLanguages, "automaticallyIdentifiesLanguages default YES");
        s.automaticallyIdentifiesLanguages = NO;
        CHECK(!s.automaticallyIdentifiesLanguages, "automaticallyIdentifiesLanguages set");

        /* language round-trip */
        CHECK([s setLanguage:@"fr"] && [s.language isEqual:@"fr"], "setLanguage round-trips");

        /* learned words (in-memory core) */
        CHECK(![s hasLearnedWord:@"wsbsd"], "word not learned initially");
        [s learnWord:@"wsbsd"];
        CHECK([s hasLearnedWord:@"wsbsd"], "learnWord records the word");
        [s unlearnWord:@"wsbsd"];
        CHECK(![s hasLearnedWord:@"wsbsd"], "unlearnWord removes it");

        /* per-document ignored words keyed by tag */
        NSInteger tagA = [NSSpellChecker uniqueSpellDocumentTag];
        NSInteger tagB = [NSSpellChecker uniqueSpellDocumentTag];
        [s ignoreWord:@"Xyzzy" inSpellDocumentWithTag:tagA];
        CHECK([[s ignoredWordsInSpellDocumentWithTag:tagA] containsObject:@"Xyzzy"], "ignored word recorded for tag A");
        CHECK([s ignoredWordsInSpellDocumentWithTag:tagB] == nil, "tag B has no ignored words");
        [s setIgnoredWords:@[@"foo", @"bar"] inSpellDocumentWithTag:tagB];
        CHECK([s ignoredWordsInSpellDocumentWithTag:tagB].count == 2, "setIgnoredWords replaces for tag B");

        /* closing a document clears its ignored set */
        [s closeSpellDocumentWithTag:tagA];
        CHECK([s ignoredWordsInSpellDocumentWithTag:tagA] == nil, "closeSpellDocumentWithTag clears tag A");
        CHECK([s ignoredWordsInSpellDocumentWithTag:tagB].count == 2, "tag B unaffected by closing tag A");

        /* stage2 system lists are safe/empty */
        CHECK(s.availableLanguages.count == 0 && s.userReplacementsDictionary.count == 0, "system lists stage2 empty");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
