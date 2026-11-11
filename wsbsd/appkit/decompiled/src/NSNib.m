/*
 * NSNib.m — behavioral-1:1 core.
 * See NSNib.h (keyed-archive IB instantiation is stage2).
 */

#import "NSNib.h"

@implementation NSNib {
    NSData   *_data;
    NSBundle *_bundle;
    NSString *_path;
    BOOL      _inheritsDecodeTimeBundle;
}

- (instancetype)initWithNibNamed:(NSString *)nibName bundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        _bundle = bundle ?: [NSBundle mainBundle];
        /* locate "<nibName>.nib" (nibName may already carry the extension). */
        NSString *base = [nibName stringByDeletingPathExtension];
        NSString *path = [_bundle pathForResource:base ofType:@"nib"];
        if (!path) path = [_bundle pathForResource:nibName ofType:@"nib"];
        if (!path) path = [_bundle pathForResource:base ofType:@"storyboardc"];
        if (!path) {
            /* 1:1 with AppKit: a missing nib is a hard error, not a nil return. */
            [NSException raise:NSInternalInconsistencyException
                        format:@"-[NSNib _initWithNibNamed:bundle:options:] could not load the nib '%@' in bundle %@.",
                               nibName, _bundle];
            return nil;
        }
        _path = [path copy];
        _data = [NSData dataWithContentsOfFile:path];
    }
    return self;
}

- (instancetype)initWithNibData:(NSData *)nibData bundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        _data = [nibData copy];
        _bundle = bundle ?: [NSBundle mainBundle];
    }
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)nibFileURL
{
    self = [super init];
    if (self) {
        _path = [nibFileURL.path copy];
        _data = [NSData dataWithContentsOfURL:nibFileURL];
        _bundle = [NSBundle mainBundle];
        if (!_data && ![nibFileURL isFileURL]) return nil;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [super init]; /* stage2 */ }
- (void)encodeWithCoder:(NSCoder *)coder { /* TODO(stage2) */ }

- (BOOL)instantiateWithOwner:(id)owner topLevelObjects:(NSArray * _Nullable *)topLevelObjects
{
    /* TODO(stage2): decode the keyed IB archive in _data, build the object graph,
     * connect outlets/actions to `owner`, and return the top-level objects. */
    if (topLevelObjects) *topLevelObjects = @[];
    return NO;
}

- (BOOL)inheritsDecodeTimeBundlePath { return _inheritsDecodeTimeBundle; }
- (void)setInheritsDecodeTimeBundlePath:(BOOL)flag { _inheritsDecodeTimeBundle = flag; }

/* internal accessors used by tests / later stage2 wiring */
- (NSData *)_data { return _data; }
- (NSBundle *)_bundle { return _bundle; }
- (NSString *)_path { return _path; }

@end
