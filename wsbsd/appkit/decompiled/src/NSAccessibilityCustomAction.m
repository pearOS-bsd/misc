/*
 * NSAccessibilityCustomAction.m — 1:1 (core). See the header for the evidence.
 *
 * Two constructors: a handler block, or a target/selector pair. The core stores
 * name, handler, target (weak) and selector. Actually performing the action for
 * an assistive client is stage2.
 */
#import "NSAccessibilityCustomAction.h"

@implementation NSAccessibilityCustomAction {
    NSString *_name;
    BOOL (^_handler)(void);
    __weak id _target;
    SEL _selector;
}

- (instancetype)initWithName:(NSString *)name handler:(BOOL (^)(void))handler
{
    self = [super init];
    if (self) { _name = [name copy]; _handler = [handler copy]; }
    return self;
}
- (instancetype)initWithName:(NSString *)name target:(id)target selector:(SEL)selector
{
    self = [super init];
    if (self) { _name = [name copy]; _target = target; _selector = selector; }
    return self;
}

- (NSString *)name { return _name; }
- (void)setName:(NSString *)v { _name = [v copy]; }
- (BOOL (^)(void))handler { return _handler; }
- (void)setHandler:(BOOL (^)(void))h { _handler = [h copy]; }
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)selector { return _selector; }
- (void)setSelector:(SEL)s { _selector = s; }

@end
