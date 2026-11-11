/*
 * NSStoryboard.m — behavioral-1:1 core.
 * See NSStoryboard.h (.storyboardc load + controller instantiation are stage2).
 */

#import "NSStoryboard.h"

@implementation NSStoryboard {
    NSBundle *_bundle;
    NSString *_storyboardFileName;
    NSDictionary<NSString *, NSString *> *_identifierToNibNameMap;
    NSDictionary *_identifierToExternalStoryboardReferenceMap;
    NSDictionary<NSString *, NSString *> *_identifierToUUIDMap;
    NSString *_designatedEntryPointIdentifier;
    NSString *_mainMenu;
}

+ (NSStoryboard *)mainStoryboard
{
    /* TODO(stage2): resolve Info.plist NSMainStoryboardFile and load it. */
    return nil;
}

+ (instancetype)storyboardWithName:(NSStoryboardName)name bundle:(NSBundle *)bundleOrNil
{
    NSBundle *bundle = bundleOrNil ?: [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:name ofType:@"storyboardc"];
    if (!path) {
        /* 1:1 measured message. */
        [NSException raise:NSInvalidArgumentException
                    format:@"Could not find a storyboard named '%@' in bundle %@", name, bundle];
        return nil;
    }
    /* TODO(stage2): parse <name>.storyboardc/Info.plist into the identifier maps. */
    return [[self alloc] initWithBundle:bundle
                     storyboardFileName:name
                 identifierToNibNameMap:@{}
identifierToExternalStoryboardReferenceMap:@{}
                    identifierToUUIDMap:@{}
         designatedEntryPointIdentifier:nil
                               mainMenu:nil];
}

- (instancetype)initWithBundle:(NSBundle *)bundle
            storyboardFileName:(NSString *)fileName
         identifierToNibNameMap:(NSDictionary<NSString *, NSString *> *)nibMap
identifierToExternalStoryboardReferenceMap:(NSDictionary *)refMap
            identifierToUUIDMap:(NSDictionary<NSString *, NSString *> *)uuidMap
   designatedEntryPointIdentifier:(NSString *)entryPoint
                       mainMenu:(NSString *)mainMenu
{
    self = [super init];
    if (self) {
        _bundle = bundle;
        _storyboardFileName = [fileName copy];
        _identifierToNibNameMap = [nibMap copy] ?: @{};
        _identifierToExternalStoryboardReferenceMap = [refMap copy] ?: @{};
        _identifierToUUIDMap = [uuidMap copy] ?: @{};
        _designatedEntryPointIdentifier = [entryPoint copy];
        _mainMenu = [mainMenu copy];
    }
    return self;
}

- (NSString *)name { return _storyboardFileName; }
- (NSBundle *)containingBundle { return _bundle; }

- (NSString *)nibForControllerWithIdentifier:(NSString *)identifier { return _identifierToNibNameMap[identifier]; }

- (BOOL)containsNibNamed:(NSString *)nibName
{
    for (NSString *nib in _identifierToNibNameMap.objectEnumerator)
        if ([nib isEqual:nibName]) return YES;
    return NO;
}

- (NSString *)uniqueIDForControllerIdentifier:(NSString *)identifier { return _identifierToUUIDMap[identifier]; }

- (id)instantiateInitialController
{
    /* TODO(stage2): decode the designated-entry-point nib into a controller. */
    return nil;
}

- (id)instantiateControllerWithIdentifier:(NSStoryboardSceneIdentifier)identifier
{
    /* 1:1: an unknown identifier is a hard error; the decode is stage2. */
    if (!_identifierToNibNameMap[identifier]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"NSStoryboard (%@) doesn't contain a controller with identifier '%@'", _storyboardFileName, identifier];
    }
    return nil; /* TODO(stage2): decode the nib for identifier and return the controller */
}

@end
