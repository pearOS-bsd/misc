/*
 * NSObjectController.m — behavioral-1:1 content-model core.
 * See NSObjectController.h (defaults measured on this Mac; CoreData+KVO stage2).
 */

#import "NSObjectController.h"

/* KVC selection proxy: forwards value(s) for key(s) to the controller's content.
 * TODO(stage2): the real _NSControllerObjectProxy drives KVO change notifications
 * and multi-value markers (NSNoSelectionMarker / NSMultipleValuesMarker). */
@interface _NSObjectControllerSelectionProxy : NSObject
- (instancetype)initWithController:(NSObjectController *)controller;
@end

@implementation _NSObjectControllerSelectionProxy {
    __weak NSObjectController *_controller;
}
- (instancetype)initWithController:(NSObjectController *)c { if ((self = [super init])) _controller = c; return self; }
- (id)valueForKey:(NSString *)key { return [_controller.content valueForKey:key]; }
- (void)setValue:(id)value forKey:(NSString *)key { [_controller.content setValue:value forKey:key]; }
- (id)valueForKeyPath:(NSString *)kp { return [_controller.content valueForKeyPath:kp]; }
@end

@implementation NSObjectController {
    id _content;
    Class _objectClass;
    BOOL _editable;
    BOOL _automaticallyPreparesContent;
    BOOL _explicitlyCannotAdd;
    BOOL _explicitlyCannotRemove;
    _NSObjectControllerSelectionProxy *_selectionProxy;
}

- (instancetype)initWithContent:(id)content
{
    self = [super init];
    if (self) {
        _objectClass = [NSMutableDictionary class];
        _editable = YES;
        _automaticallyPreparesContent = NO;
        _content = content;
        _selectionProxy = [[_NSObjectControllerSelectionProxy alloc] initWithController:self];
    }
    return self;
}

- (instancetype)init { return [self initWithContent:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithContent:nil]; /* stage2 */ }

- (id)content { return _content; }
- (void)setContent:(id)content { _content = content; }

- (id)selection { return _selectionProxy; }
- (NSArray *)selectedObjects { return _content ? @[_content] : @[]; }

- (BOOL)isEditable { return _editable; }
- (void)setEditable:(BOOL)e { _editable = e; }

- (BOOL)automaticallyPreparesContent { return _automaticallyPreparesContent; }
- (void)setAutomaticallyPreparesContent:(BOOL)v { _automaticallyPreparesContent = v; }

- (Class)objectClass { return _objectClass; }
- (void)setObjectClass:(Class)c { _objectClass = c; }

/* non-managed gating (CoreData adds _canModifyManagedContent, stage2) */
- (BOOL)canAdd { return _editable && !_explicitlyCannotAdd; }
- (BOOL)canRemove { return _editable && (_content != nil) && !_explicitlyCannotRemove; }

- (void)_setExplicitlyCannotAdd:(BOOL)a remove:(BOOL)r { _explicitlyCannotAdd = a; _explicitlyCannotRemove = r; }

- (id)newObject { return [[_objectClass alloc] init]; }

- (void)prepareContent { [self setContent:[self newObject]]; }

- (void)addObject:(id)object { [self setContent:object]; }

- (void)removeObject:(id)object { if (object == _content || [object isEqual:_content]) [self setContent:nil]; }

- (void)add:(id)sender
{
    if (![self canAdd]) return;
    [self addObject:[self newObject]];
    /* stage2: _executeAdd:…commits editing first and routes through the adaptor. */
}

- (void)remove:(id)sender
{
    if (![self canRemove]) return;
    [self removeObject:_content];
}

@end
