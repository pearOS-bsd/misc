/*
 * NSTrackingArea.m — 1:1 (core). See NSTrackingArea.h for interface evidence.
 *
 * -initWithRect:options:owner:userInfo: stores the region and, like AppKit,
 * validates the options: exactly one tracking type (MouseEnteredAndExited /
 * MouseMoved / CursorUpdate) must be requested together with exactly one active
 * option (ActiveWhenFirstResponder / ActiveInKeyWindow / ActiveInActiveApp /
 * ActiveAlways); otherwise it raises NSInvalidArgumentException. owner is weak.
 * The install/enable lifecycle flags and window-server hit testing are stage2.
 */
#import "NSTrackingArea.h"

@implementation NSTrackingArea {
    CGRect _rect;
    NSTrackingAreaOptions _options;
    __weak id _owner;
    NSDictionary *_userInfo;
}

- (instancetype)initWithRect:(CGRect)rect
                     options:(NSTrackingAreaOptions)options
                       owner:(id)owner
                    userInfo:(NSDictionary *)userInfo
{
    NSTrackingAreaOptions trackingTypes = NSTrackingMouseEnteredAndExited |
                                          NSTrackingMouseMoved | NSTrackingCursorUpdate;
    NSTrackingAreaOptions activeOptions = NSTrackingActiveWhenFirstResponder |
                                          NSTrackingActiveInKeyWindow |
                                          NSTrackingActiveInActiveApp | NSTrackingActiveAlways;
    if ((options & trackingTypes) == 0)
        [NSException raise:NSInvalidArgumentException
                    format:@"NSTrackingArea: at least one tracking type "
                           @"(MouseEnteredAndExited, MouseMoved, CursorUpdate) is required"];
    if ((options & activeOptions) == 0)
        [NSException raise:NSInvalidArgumentException
                    format:@"NSTrackingArea: exactly one active option is required"];

    self = [super init];
    if (self) {
        _rect = rect;
        _options = options;
        _owner = owner;
        _userInfo = [userInfo copy];
    }
    return self;
}

- (CGRect)rect { return _rect; }
- (NSTrackingAreaOptions)options { return _options; }
- (id)owner { return _owner; }
- (NSDictionary *)userInfo { return _userInfo; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[NSTrackingArea alloc] initWithRect:_rect options:_options owner:_owner userInfo:_userInfo];
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSTrackingArea class]]) return NO;
    NSTrackingArea *o = object;
    return CGRectEqualToRect(_rect, o->_rect) && _options == o->_options &&
           _owner == o->_owner &&
           ((_userInfo == o->_userInfo) || [_userInfo isEqualToDictionary:o->_userInfo]);
}

- (NSUInteger)hash { return (NSUInteger)_rect.size.width ^ _options; }

@end
