/* UniformTypeIdentifiers: UTType over the table of uniform type identifiers of the reference Mac (launchservices/uti_table.json, see sdk/src/UTI.m). */
#import <Foundation/Foundation.h>
typedef NSString *UTTagClass;
extern NSString *const UTTagClassFilenameExtension, *const UTTagClassMIMEType;
@interface UTType : NSObject <NSCopying, NSSecureCoding>
+ (UTType *)typeWithIdentifier:(NSString *)identifier;
+ (UTType *)typeWithFilenameExtension:(NSString *)extension;
+ (UTType *)typeWithFilenameExtension:(NSString *)extension conformingToType:(UTType *)supertype;
+ (UTType *)typeWithMIMEType:(NSString *)mimeType;
+ (UTType *)typeWithMIMEType:(NSString *)mimeType conformingToType:(UTType *)supertype;
+ (NSArray<UTType *> *)typesWithTag:(NSString *)tag tagClass:(UTTagClass)tagClass conformingToType:(UTType *)supertype;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSString *preferredFilenameExtension, *preferredMIMEType, *localizedDescription;
@property (readonly, copy) NSDictionary<UTTagClass, NSArray<NSString *> *> *tags;
@property (readonly, getter=isDeclared) BOOL declared;
@property (readonly, getter=isDynamic) BOOL dynamic;
@property (readonly, getter=isPublicType) BOOL publicType;
@property (readonly, copy) NSSet<UTType *> *supertypes;
- (BOOL)conformsToType:(UTType *)type;
- (BOOL)isSupertypeOfType:(UTType *)type;
- (BOOL)isSubtypeOfType:(UTType *)type;
+ (UTType *)item; + (UTType *)content; + (UTType *)compositeContent; + (UTType *)diskImage; + (UTType *)data; + (UTType *)directory; + (UTType *)resolvable; + (UTType *)symbolicLink; + (UTType *)executable; + (UTType *)mountPoint; + (UTType *)aliasFile; + (UTType *)urlBookmarkData;
+ (UTType *)url; + (UTType *)fileURL; + (UTType *)text; + (UTType *)plainText; + (UTType *)utf8PlainText; + (UTType *)utf16PlainText; + (UTType *)rtf; + (UTType *)html; + (UTType *)xml; + (UTType *)sourceCode; + (UTType *)cSource; + (UTType *)json; + (UTType *)pdf; + (UTType *)image; + (UTType *)jpeg; + (UTType *)png; + (UTType *)gif; + (UTType *)tiff; + (UTType *)audio; + (UTType *)mp3; + (UTType *)movie; + (UTType *)video; + (UTType *)archive; + (UTType *)zip; + (UTType *)folder; + (UTType *)package; + (UTType *)bundle; + (UTType *)application; + (UTType *)applicationBundle; + (UTType *)propertyList;
@end
