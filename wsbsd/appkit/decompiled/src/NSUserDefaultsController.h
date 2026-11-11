/*
 * NSUserDefaultsController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSUserDefaultsController (: NSController), the bindings bridge to NSUserDefaults.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSUserDefaultsController_interface.txt. Real ivars: _defaults,
 * _valueBuffer (the deferred-edit buffer), _initialValues, and a packed
 * _userDefaultsControllerFlags (sharedInstance / appliesImmediately bits).
 *
 * Measured on this Mac: shared and plain instances have appliesImmediately=YES;
 * a nil `defaults:` resolves to [NSUserDefaults standardUserDefaults]; the
 * `values` proxy reads default-then-initialValues; an immediate write hits the
 * defaults at once (hasUnappliedChanges stays NO), a deferred write buffers
 * (defaults untouched, hasUnappliedChanges YES, the proxy reads the buffered
 * value). save:/revert: flush/discard the buffer (documented behavior; the
 * binding-commit edge a standalone AppKit instance showed is stage2).
 */

#import "NSController.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSUserDefaultsController : NSController

+ (NSUserDefaultsController *)sharedUserDefaultsController;
- (instancetype)initWithDefaults:(nullable NSUserDefaults *)defaults
                   initialValues:(nullable NSDictionary<NSString *, id> *)initialValues NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

@property (readonly, strong) NSUserDefaults *defaults;
@property (nullable, copy) NSDictionary<NSString *, id> *initialValues;
@property BOOL appliesImmediately;              /* default YES */
@property (readonly) BOOL hasUnappliedChanges;
@property (readonly, strong) id values;

- (void)save:(nullable id)sender;
- (void)revert:(nullable id)sender;
- (void)revertToInitialValues:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
