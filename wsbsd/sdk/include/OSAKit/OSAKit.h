/* OSAKit: there is no scripting engine; an OSAScript compiles to an error and runs to an error (NSAppleScript behaves the same) */
#ifndef WSBSD_OSAKIT_H
#define WSBSD_OSAKIT_H
#import <Foundation/Foundation.h>
@interface OSAScript : NSObject
- (instancetype)initWithSource:(NSString *)source;
- (instancetype)initWithSource:(NSString *)source language:(id)language;
- (BOOL)compileAndReturnError:(NSDictionary **)errorInfo;
- (NSAppleEventDescriptor *)executeAndReturnError:(NSDictionary **)errorInfo;
@property (nonatomic, readonly, copy) NSString *source;
@end
#endif
