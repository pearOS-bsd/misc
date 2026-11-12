/*
 * NSSpeechRecognizer.m — behavioral-1:1 core. See the header.
 */

#import "NSSpeechRecognizer.h"

@implementation NSSpeechRecognizer {
    __weak id<NSSpeechRecognizerDelegate> _delegate;
    NSArray<NSString *> *_commands;
    NSString *_displayedCommandsTitle;
    BOOL _listensInForegroundOnly;
    BOOL _blocksOtherRecognizers;
    BOOL _listening;
}

- (instancetype)init
{
    self = [super init];
    /* all configuration nil/NO by default (measured). */
    return self;
}

- (id<NSSpeechRecognizerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSSpeechRecognizerDelegate>)d { _delegate = d; }
- (NSArray<NSString *> *)commands { return _commands; }
- (void)setCommands:(NSArray<NSString *> *)c { _commands = [c copy]; }
- (NSString *)displayedCommandsTitle { return _displayedCommandsTitle; }
- (void)setDisplayedCommandsTitle:(NSString *)t { _displayedCommandsTitle = [t copy]; }
- (BOOL)listensInForegroundOnly { return _listensInForegroundOnly; }
- (void)setListensInForegroundOnly:(BOOL)v { _listensInForegroundOnly = v; }
- (BOOL)blocksOtherRecognizers { return _blocksOtherRecognizers; }
- (void)setBlocksOtherRecognizers:(BOOL)v { _blocksOtherRecognizers = v; }
- (BOOL)isListening { return _listening; }

- (void)startListening { _listening = YES; /* TODO(stage2): bind to speech server */ }
- (void)stopListening  { _listening = NO; }

- (void)_processRecognitionResult:(NSString *)command
{
    /* Engine delivers a recognized phrase; forward only members of -commands,
       and only while listening, mirroring the documented contract. */
    if (!_listening || command == nil) return;
    if (_commands != nil && ![_commands containsObject:command]) return;
    if ([_delegate respondsToSelector:@selector(speechRecognizer:didRecognizeCommand:)]) {
        [_delegate speechRecognizer:self didRecognizeCommand:command];
    }
}

@end
