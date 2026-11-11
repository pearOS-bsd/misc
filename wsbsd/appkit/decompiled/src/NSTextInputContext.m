/*
 * NSTextInputContext.m — behavioral-1:1 public core.
 * See NSTextInputContext.h (TSM/RTI engine + TIS registry are stage2).
 */

#import "NSTextInputContext.h"

/* The active input context. On macOS this is derived from TSM + the app's key
 * window first responder; here -activate/-deactivate drive it directly, which is
 * the documented contract and what our window-server stack will set. */
static __weak NSTextInputContext *gCurrentInputContext = nil;

@implementation NSTextInputContext {
    __weak id<NSTextInputClient> _client;
    BOOL _acceptsGlyphInfo;
    NSArray<NSString *> *_allowedInputSourceLocales;
    NSString *_selectedKeyboardInputSource;
}

+ (NSTextInputContext *)currentInputContext { return gCurrentInputContext; }

- (instancetype)initWithClient:(id<NSTextInputClient>)client
{
    self = [super init];
    if (self) {
        _client = client;
        _acceptsGlyphInfo = NO;   /* measured */
    }
    return self;
}

- (id<NSTextInputClient>)client { return _client; }

- (BOOL)acceptsGlyphInfo { return _acceptsGlyphInfo; }
- (void)setAcceptsGlyphInfo:(BOOL)v { _acceptsGlyphInfo = v; }

- (NSArray<NSString *> *)allowedInputSourceLocales { return _allowedInputSourceLocales; }
- (void)setAllowedInputSourceLocales:(NSArray<NSString *> *)v { _allowedInputSourceLocales = [v copy]; }

- (NSArray<NSString *> *)keyboardInputSources { return @[]; /* stage2: enumerate TIS */ }
- (NSString *)selectedKeyboardInputSource { return _selectedKeyboardInputSource; /* stage2: TIS */ }
- (void)setSelectedKeyboardInputSource:(NSString *)v { _selectedKeyboardInputSource = [v copy]; }

- (void)activate   { gCurrentInputContext = self; /* stage2: TSM activation + key-window gating */ }
- (void)deactivate { if (gCurrentInputContext == self) gCurrentInputContext = nil; }

- (BOOL)handleEvent:(id)event { return NO; /* stage2: TSM/RTI */ }
- (void)discardMarkedText { /* stage2 */ }
- (void)invalidateCharacterCoordinates { /* stage2 */ }

@end
