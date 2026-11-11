/*
 * NSUserDefaultsController.m — behavioral-1:1 core.
 * See NSUserDefaultsController.h (behavior measured on this Mac; binding-commit
 * edge + KVO notifications are stage2).
 */

#import "NSUserDefaultsController.h"

@class NSUserDefaultsController;

/* KVC proxy returned by -values: reads/writes go through the controller,
 * honouring appliesImmediately and the initialValues fallback. */
@interface _NSUserDefaultsControllerValues : NSObject
- (instancetype)initWithController:(NSUserDefaultsController *)c;
@end

@interface NSUserDefaultsController ()
- (id)_valueForDefaultsKey:(NSString *)key;
- (void)_setValue:(nullable id)value forDefaultsKey:(NSString *)key;
@end

@implementation _NSUserDefaultsControllerValues {
    __weak NSUserDefaultsController *_controller;
}
- (instancetype)initWithController:(NSUserDefaultsController *)c { if ((self = [super init])) _controller = c; return self; }
- (id)valueForKey:(NSString *)key { return [_controller _valueForDefaultsKey:key]; }
- (void)setValue:(id)value forKey:(NSString *)key { [_controller _setValue:value forDefaultsKey:key]; }
- (id)valueForUndefinedKey:(NSString *)key { return [_controller _valueForDefaultsKey:key]; }
- (void)setValue:(id)value forUndefinedKey:(NSString *)key { [_controller _setValue:value forDefaultsKey:key]; }
@end

@implementation NSUserDefaultsController {
    NSUserDefaults *_defaults;
    NSMutableDictionary *_valueBuffer;
    NSDictionary *_initialValues;
    BOOL _appliesImmediately;
    _NSUserDefaultsControllerValues *_valuesProxy;
}

+ (NSUserDefaultsController *)sharedUserDefaultsController
{
    static NSUserDefaultsController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[NSUserDefaultsController alloc] initWithDefaults:nil initialValues:nil];
    });
    return shared;
}

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults initialValues:(NSDictionary *)initialValues
{
    self = [super init];
    if (self) {
        _defaults = defaults ?: [NSUserDefaults standardUserDefaults];
        _initialValues = [initialValues copy];
        _valueBuffer = [NSMutableDictionary dictionary];
        _appliesImmediately = YES;
        _valuesProxy = [[_NSUserDefaultsControllerValues alloc] initWithController:self];
    }
    return self;
}

- (instancetype)init { return [self initWithDefaults:nil initialValues:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithDefaults:nil initialValues:nil]; }

- (NSUserDefaults *)defaults { return _defaults; }
- (NSDictionary *)initialValues { return _initialValues; }
- (void)setInitialValues:(NSDictionary *)v { _initialValues = [v copy]; }
- (BOOL)appliesImmediately { return _appliesImmediately; }

- (void)setAppliesImmediately:(BOOL)v
{
    /* Turning it back on flushes whatever is buffered (documented). */
    if (v && !_appliesImmediately) [self save:nil];
    _appliesImmediately = v;
}

- (BOOL)hasUnappliedChanges { return !_appliesImmediately && _valueBuffer.count > 0; }

- (id)values { return _valuesProxy; }

/* --- value resolution: buffer (deferred) -> defaults -> initialValues --- */

- (id)_valueForDefaultsKey:(NSString *)key
{
    if (!_appliesImmediately) {
        id buffered = _valueBuffer[key];
        if (buffered) return buffered;
    }
    id stored = [_defaults objectForKey:key];
    if (stored) return stored;
    return _initialValues[key];
}

- (void)_setValue:(id)value forDefaultsKey:(NSString *)key
{
    if (_appliesImmediately) {
        if (value) [_defaults setObject:value forKey:key];
        else [_defaults removeObjectForKey:key];
    } else {
        _valueBuffer[key] = value ?: [NSNull null];
    }
}

/* --- apply / discard the deferred buffer --- */

- (void)save:(id)sender
{
    for (NSString *key in _valueBuffer) {
        id v = _valueBuffer[key];
        if (v == [NSNull null]) [_defaults removeObjectForKey:key];
        else [_defaults setObject:v forKey:key];
    }
    [_valueBuffer removeAllObjects];
}

- (void)revert:(id)sender
{
    [_valueBuffer removeAllObjects];
    /* stage2: KVO-notify the bound value keys that they changed back. */
}

- (void)revertToInitialValues:(id)sender
{
    for (NSString *key in _initialValues)
        [self _setValue:_initialValues[key] forDefaultsKey:key];
}

@end
