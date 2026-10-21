/* AddressBook: there is no contacts database; the address book answers, and "me" is nobody (applications then fall back to the account name). Implemented in sdk/src/SystemFrameworks.m */
#ifndef WSBSD_ADDRESSBOOK_H
#define WSBSD_ADDRESSBOOK_H
#import <Foundation/Foundation.h>
extern NSString *const kABEmailProperty;
extern NSString *const kABFirstNameProperty;
extern NSString *const kABLastNameProperty;
@interface ABMultiValue : NSObject
- (NSUInteger)count;
- (id)valueAtIndex:(NSUInteger)index;
- (NSString *)labelAtIndex:(NSUInteger)index;
- (NSString *)primaryIdentifier;
@end
@interface ABMutableMultiValue : ABMultiValue @end
@interface ABRecord : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface ABPerson : ABRecord @end
@interface ABAddressBook : NSObject
+ (ABAddressBook *)sharedAddressBook;
- (ABPerson *)me;
@end
#endif
