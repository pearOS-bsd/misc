/*
 * NSEvent.m — 1:1 (core). See NSEvent.h for the interface evidence.
 *
 * Immutable events built by the factory methods; every accessor returns a field
 * set at construction. Mouse-only fields (clickCount/buttonNumber/pressure) are
 * meaningful for mouse events; key-only fields (characters/keyCode/isARepeat)
 * for key events, matching AppKit (reading a key field off a mouse event just
 * returns the zero/empty default). CGEvent bridging and the server event stream
 * are stage2.
 */
#import "NSEvent.h"

@implementation NSEvent {
    NSEventType _type;
    NSEventModifierFlags _flags;
    NSTimeInterval _timestamp;
    CGPoint _location;
    NSInteger _windowNumber;
    NSInteger _clickCount;
    NSInteger _buttonNumber;
    float _pressure;
    unsigned short _keyCode;
    NSString *_characters;
    NSString *_charactersIgnoringModifiers;
    BOOL _isARepeat;
}

+ (NSEvent *)mouseEventWithType:(NSEventType)type
                       location:(CGPoint)location
                  modifierFlags:(NSEventModifierFlags)flags
                      timestamp:(NSTimeInterval)time
                   windowNumber:(NSInteger)wNum
                        context:(id)context
                    eventNumber:(NSInteger)eNum
                     clickCount:(NSInteger)cNum
                       pressure:(float)pressure
{
    NSEvent *e = [[NSEvent alloc] init];
    e->_type = type;
    e->_flags = flags;
    e->_timestamp = time;
    e->_location = location;
    e->_windowNumber = wNum;
    e->_clickCount = cNum;
    e->_pressure = pressure;
    e->_buttonNumber = (type == NSEventTypeRightMouseDown ||
                        type == NSEventTypeRightMouseUp ||
                        type == NSEventTypeRightMouseDragged) ? 1 : 0;
    return e;
}

+ (NSEvent *)keyEventWithType:(NSEventType)type
                     location:(CGPoint)location
                modifierFlags:(NSEventModifierFlags)flags
                    timestamp:(NSTimeInterval)time
                 windowNumber:(NSInteger)wNum
                      context:(id)context
                   characters:(NSString *)keys
  charactersIgnoringModifiers:(NSString *)ukeys
                    isARepeat:(BOOL)flag
                      keyCode:(unsigned short)code
{
    NSEvent *e = [[NSEvent alloc] init];
    e->_type = type;
    e->_flags = flags;
    e->_timestamp = time;
    e->_location = location;
    e->_windowNumber = wNum;
    e->_characters = [keys copy];
    e->_charactersIgnoringModifiers = [ukeys copy];
    e->_isARepeat = flag;
    e->_keyCode = code;
    return e;
}

- (NSEventType)type { return _type; }
- (NSEventModifierFlags)modifierFlags { return _flags; }
- (NSTimeInterval)timestamp { return _timestamp; }
- (CGPoint)locationInWindow { return _location; }
- (NSInteger)windowNumber { return _windowNumber; }
- (NSInteger)clickCount { return _clickCount; }
- (NSInteger)buttonNumber { return _buttonNumber; }
- (float)pressure { return _pressure; }
- (unsigned short)keyCode { return _keyCode; }
- (NSString *)characters { return _characters; }
- (NSString *)charactersIgnoringModifiers { return _charactersIgnoringModifiers; }
- (BOOL)isARepeat { return _isARepeat; }

- (id)copyWithZone:(NSZone *)zone { return self; } /* events are immutable */

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ type=%lu flags=0x%lx loc={%g,%g} keyCode=%u chars=%@",
            [super description], (unsigned long)_type, (unsigned long)_flags,
            _location.x, _location.y, _keyCode, _characters];
}

@end
