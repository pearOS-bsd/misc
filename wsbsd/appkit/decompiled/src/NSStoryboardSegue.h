/*
 * NSStoryboardSegue.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSStoryboardSegue : NSObject {
 *       @? _performHandler;  @"NSString" _identifier;  @ _sourceController;
 *       @ _destinationController;  @? _prepareHandler;
 *   }
 *   +segueWithIdentifier:source:destination:performHandler:
 *   -perform -identifier -sourceController -destinationController
 *   @property prepareHandler / performHandler (blocks)
 *
 * A transition between two controllers. The core stores identifier, source,
 * destination and the perform/prepare handlers; -perform invokes the perform
 * handler (AppKit subclasses override -perform to drive the actual presentation,
 * which is stage2).
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSStoryboardSegue : NSObject

+ (instancetype)segueWithIdentifier:(NSString *)identifier
                             source:(id)sourceController
                        destination:(id)destinationController
                     performHandler:(void (^)(void))performHandler;

- (instancetype)initWithIdentifier:(NSString *)identifier
                            source:(id)sourceController
                       destination:(id)destinationController;

@property (readonly, copy) NSString *identifier;
@property (readonly, strong) id sourceController;
@property (readonly, strong) id destinationController;
@property (nullable, copy) void (^prepareHandler)(void);
@property (nullable, copy) void (^performHandler)(void);

- (void)perform;

@end

NS_ASSUME_NONNULL_END
