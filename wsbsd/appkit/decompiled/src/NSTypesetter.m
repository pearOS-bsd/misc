/*
 * NSTypesetter.m — behavioral-1:1 core. See the header.
 */

#import "NSTypesetter.h"

@implementation NSTypesetter {
    BOOL _usesFontLeading;
    NSTypesetterBehavior _typesetterBehavior;
    float _hyphenationFactor;
    CGFloat _lineFragmentPadding;
    BOOL _bidiProcessingEnabled;
    NSAttributedString *_attributedString;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _usesFontLeading = YES;                       /* measured */
        _typesetterBehavior = NSTypesetterBehavior_10_4;  /* measured default (4) */
        _bidiProcessingEnabled = YES;                 /* measured */
        /* hyphenationFactor=0, lineFragmentPadding=0, attributedString=nil */
    }
    return self;
}

+ (NSTypesetter *)sharedSystemTypesetter
{
    static NSTypesetter *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

+ (NSTypesetter *)sharedSystemTypesetterForBehavior:(NSTypesetterBehavior)behavior
{
    NSTypesetter *t = [self sharedSystemTypesetter];
    return t;   /* the shared typesetter configured for the requested behavior */
}

+ (NSTypesetterBehavior)defaultTypesetterBehavior { return NSTypesetterBehavior_10_4; }  /* measured (4) */

- (BOOL)usesFontLeading { return _usesFontLeading; }
- (void)setUsesFontLeading:(BOOL)v { _usesFontLeading = v; }
- (NSTypesetterBehavior)typesetterBehavior { return _typesetterBehavior; }
- (void)setTypesetterBehavior:(NSTypesetterBehavior)b { _typesetterBehavior = b; }
- (float)hyphenationFactor { return _hyphenationFactor; }
- (void)setHyphenationFactor:(float)f { _hyphenationFactor = f; }
- (CGFloat)lineFragmentPadding { return _lineFragmentPadding; }
- (void)setLineFragmentPadding:(CGFloat)p { _lineFragmentPadding = p; }
- (BOOL)bidiProcessingEnabled { return _bidiProcessingEnabled; }
- (void)setBidiProcessingEnabled:(BOOL)v { _bidiProcessingEnabled = v; }
- (NSAttributedString *)attributedString { return _attributedString; }
- (void)setAttributedString:(NSAttributedString *)s { _attributedString = s; }

@end
