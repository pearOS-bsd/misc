/* defaults: the command line tool of macOS (defaults(1)) on the Foundation of this system. Preferences are property lists, ~/Library/Preferences/<domain>.plist, the global domain
 * ~/Library/Preferences/.GlobalPreferences.plist; reading prints the "old style" text of the Mac, writing makes a binary property list (what the Mac writes). Commands: read, read-type, write,
 * delete, rename, domains, find, import, export, help. Types for write: -string -data -int -integer -float -bool -boolean -date -array -array-add -dict -dict-add, or one property list literal.
 * After a write a distributed notification tells running programs which domain changed (the job of cfprefsd on the Mac; see ../cfprefsd). */
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static NSString *PrefsDir(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences"]; }
static BOOL IsGlobal(NSString *d) { return [d isEqual: @"-g"] || [d isEqual: @"-globalDomain"] || [d isEqual: @"NSGlobalDomain"] || [d isEqual: @"Apple Global Domain"]; }
static NSString *BundleIdOfApp(NSString *name)
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSString *app = [name hasSuffix: @".app"] ? name : [name stringByAppendingString: @".app"];
	NSArray *dirs = @[ @"", @"/Applications", @"/System/Applications", @"/System/Applications/Utilities", @"/System/Library/CoreServices", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"] ];
	for (NSString *d in dirs) { NSString *p = [name hasPrefix: @"/"] ? name : [d stringByAppendingPathComponent: app]; if (![fm fileExistsAtPath: p]) continue;
		NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: [p stringByAppendingPathComponent: @"Contents/Info.plist"]]; NSString *bid = info[@"CFBundleIdentifier"]; if (bid) return bid; }
	return nil;
}
/* the file of a domain: "-g", a bundle identifier, "-app Name", or a path (with or without .plist) */
static NSString *FileOfDomain(NSString *d)
{
	if (IsGlobal(d)) return [PrefsDir() stringByAppendingPathComponent: @".GlobalPreferences.plist"];
	if ([d hasPrefix: @"/"] || [d hasPrefix: @"~"]) { d = [d stringByExpandingTildeInPath]; return [d hasSuffix: @".plist"] ? d : [d stringByAppendingPathExtension: @"plist"]; }
	return [[PrefsDir() stringByAppendingPathComponent: d] stringByAppendingPathExtension: @"plist"];
}
static NSMutableDictionary *Load(NSString *file)
{
	NSData *d = [NSData dataWithContentsOfFile: file]; if (!d) return nil; id o = [NSPropertyListSerialization propertyListWithData: d options: NSPropertyListMutableContainers format: NULL error: NULL];
	return [o isKindOfClass: [NSMutableDictionary class]] ? o : nil;
}
static BOOL Save(NSDictionary *dict, NSString *file, NSString *domain)
{
	[[NSFileManager defaultManager] createDirectoryAtPath: [file stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL];
	NSData *d = [NSPropertyListSerialization dataWithPropertyList: dict format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL]; if (!d || ![d writeToFile: file atomically: YES]) return NO;
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.apple.cfprefsd.domainChanged" object: IsGlobal(domain) ? @"kCFPreferencesAnyApplication" : domain userInfo: nil deliverImmediately: YES];
	return YES;
}
/* the "old style" text of the Mac: strings are quoted only when they hold anything but letters, digits and . _ / - $ : , dictionaries and arrays indent by four */
/* old-style quoting as the Mac does it: a string stays bare only when it is made of ASCII letters and digits; anything else (a dot, a minus sign, a space, a slash) is quoted, and a character beyond ASCII is written \Uxxxx */
static BOOL Plain(NSString *s) { if (![s length]) return NO; for (NSUInteger i = 0; i < [s length]; i++) { unichar c = [s characterAtIndex: i]; if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))) return NO; } return YES; }
static NSString *Quote(NSString *s)
{
	if (Plain(s)) return s; NSMutableString *m = [NSMutableString string];
	for (NSUInteger i = 0; i < [s length]; i++) { unichar c = [s characterAtIndex: i]; if (c == '\\') [m appendString: @"\\\\"]; else if (c == '"') [m appendString: @"\\\""]; else if (c == '\n') [m appendString: @"\\n"]; else if (c == '\t') [m appendString: @"\\t"]; else if (c > 126) [m appendFormat: @"\\U%04x", c]; else [m appendFormat: @"%C", c]; }
	return [NSString stringWithFormat: @"\"%@\"", m];
}
static BOOL IsBool(id o) { return [o isKindOfClass: [NSNumber class]] && (!strcmp([o objCType], "c") || !strcmp([o objCType], "B") || [NSStringFromClass([o class]) rangeOfString: @"Bool"].length); }
static NSString *Scalar(id o)     /* a value that is no container, as the text of the value */
{
	if ([o isKindOfClass: [NSData class]]) { const unsigned char *b = [o bytes]; NSUInteger n = [o length]; NSMutableString *h = [NSMutableString string];
		if (n > 24) { for (NSUInteger i = 0; i < 16; i++) { [h appendFormat: @"%02x", b[i]]; if (i % 4 == 3) [h appendString: @" "]; } [h appendString: @"... "]; for (NSUInteger i = n - 8; i < n; i++) { [h appendFormat: @"%02x", b[i]]; if ((i - (n - 8)) % 4 == 3) [h appendString: @" "]; } }
		else for (NSUInteger i = 0; i < n; i++) [h appendFormat: @"%02x", b[i]];
		return [NSString stringWithFormat: @"{length = %lu, bytes = 0x%@}", (unsigned long)n, h]; }
	if ([o isKindOfClass: [NSDate class]]) return [o description];
	if (IsBool(o)) return [o boolValue] ? @"1" : @"0";
	if ([o isKindOfClass: [NSNumber class]]) return [o stringValue];
	return [o description];
}
static void Print(id o, int ind, NSMutableString *out)      /* ind: the level of the container being printed; its first line is already placed */
{
	NSString *pad = [@"" stringByPaddingToLength: (NSUInteger)ind * 4 withString: @" " startingAtIndex: 0];
	if ([o isKindOfClass: [NSDictionary class]] || [o isKindOfClass: [NSArray class]]) {
		BOOL dict = [o isKindOfClass: [NSDictionary class]]; [out appendString: dict ? @"{\n" : @"(\n"];
		if (dict) for (NSString *k in [[o allKeys] sortedArrayUsingSelector: @selector(compare:)]) { id v = o[k]; [out appendFormat: @"%@    %@ = ", pad, Quote(k)];
			if ([v isKindOfClass: [NSDictionary class]] || [v isKindOfClass: [NSArray class]]) [out appendFormat: @"%@    ", pad];      /* the Mac puts the indentation of the key's line again before a container */
			Print(v, ind + 1, out); [out appendString: @";\n"]; }
		else for (NSUInteger i = 0; i < [o count]; i++) { [out appendFormat: @"%@    ", pad]; Print(o[i], ind + 1, out); [out appendString: i + 1 < [o count] ? @",\n" : @"\n"]; }
		[out appendFormat: @"%@%@", pad, dict ? @"}" : @")"]; return;
	}
	NSString *t = Scalar(o); [out appendString: ([o isKindOfClass: [NSData class]] || IsBool(o)) ? t : Quote(t)];
}
static id Parse(NSString *s)      /* a property list literal ("(a, b)", "{k = v;}" or XML) */
{
	NSData *d = [s dataUsingEncoding: NSUTF8StringEncoding]; id o = [NSPropertyListSerialization propertyListWithData: d options: NSPropertyListMutableContainers format: NULL error: NULL]; if (o) return o;
	return [s propertyList];
}
static void Usage(void) { fprintf(stderr, "Command line interface to a user's defaults.\nSyntax:\n\n'defaults' [-currentHost | -host <hostname>] followed by one of the following:\n\n  read                                 shows all defaults\n  read <domain>                        shows defaults for given domain\n  read <domain> <key>                  shows defaults for given domain, key\n\n  read-type <domain> <key>             shows the type for the given domain, key\n\n  write <domain> <domain_rep>          writes domain (overwrites existing)\n  write <domain> <key> <value>         writes key for domain\n\n  rename <domain> <old_key> <new_key>  renames old_key to new_key\n\n  delete <domain>                      deletes domain\n  delete <domain> <key>                deletes key in domain\n\n  import <domain> <path to plist>      writes the plist at path to domain\n  import <domain> -                    writes a plist from stdin to domain\n  export <domain> <path to plist>      saves domain as a binary plist to path\n  export <domain> -                    writes domain as an xml plist to stdout\n  domains                              lists all domains\n  find <word>                          lists all entries containing word\n  help                                 print this help\n\n<domain> is ( <domain_name> | -app <application_name> | -globalDomain )\n         or a path to a file omitting the '.plist' extension\n\n<value> is one of:\n  <value_rep>\n  -string <string_value>\n  -data <hex_digits>\n  -int[eger] <integer_value>\n  -float  <floating-point_value>\n  -bool[ean] (true | false | yes | no)\n  -date <date_rep>\n  -array <value1> <value2> ...\n  -array-add <value1> <value2> ...\n  -dict <key1> <value1> <key2> <value2> ...\n  -dict-add <key1> <value1> ...\n"); }
static id Typed(NSArray *a, NSUInteger *i, NSString *type)      /* the value after -type (a is the remaining arguments) */
{
	NSString *v = *i < [a count] ? a[*i] : nil;
	if ([type isEqual: @"-string"]) { (*i)++; return v ?: @""; }
	if ([type isEqual: @"-int"] || [type isEqual: @"-integer"]) { (*i)++; return @([v longLongValue]); }
	if ([type isEqual: @"-float"]) { (*i)++; return @([v doubleValue]); }
	if ([type isEqual: @"-bool"] || [type isEqual: @"-boolean"]) { (*i)++; NSString *l = [v lowercaseString]; return [NSNumber numberWithBool: [l isEqual: @"true"] || [l isEqual: @"yes"] || [l isEqual: @"1"]]; }
	if ([type isEqual: @"-date"]) { (*i)++; id dt = [NSDate dateWithString: v]; return dt ?: [NSDate date]; }
	if ([type isEqual: @"-data"]) { (*i)++; NSMutableData *d = [NSMutableData data]; NSString *h = [v stringByReplacingOccurrencesOfString: @" " withString: @""]; for (NSUInteger k = 0; k + 1 < [h length]; k += 2) { unsigned x = 0; sscanf([[h substringWithRange: NSMakeRange(k, 2)] UTF8String], "%x", &x); unsigned char c = (unsigned char)x; [d appendBytes: &c length: 1]; } return d; }
	(*i)++; return Parse(v ?: @"");
}
int main(int argc, char **argv)
{
	@autoreleasepool {
		[NSTimeZone setDefaultTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];            /* the image has no /etc/localtime of its own to begin with; dates are printed with a +0000 offset */
		NSMutableArray *a = [NSMutableArray array]; for (int i = 1; i < argc; i++) [a addObject: @(argv[i])];
		while ([a count] && ([a[0] isEqual: @"-currentHost"] || [a[0] isEqual: @"-host"])) { if ([a[0] isEqual: @"-host"] && [a count] > 1) [a removeObjectAtIndex: 0]; [a removeObjectAtIndex: 0]; }
		if (![a count] || [a[0] isEqual: @"help"]) { Usage(); return [a count] ? 0 : 1; }
		NSString *cmd = a[0]; [a removeObjectAtIndex: 0]; NSFileManager *fm = [NSFileManager defaultManager];
		/* the domain: -g, -app Name, a name or a path */
		NSString *domain = nil;
		if ([cmd isEqual: @"domains"]) { NSMutableArray *r = [NSMutableArray array]; for (NSString *f in [fm contentsOfDirectoryAtPath: PrefsDir() error: NULL]) if ([f hasSuffix: @".plist"] && ![f hasPrefix: @"."]) [r addObject: [f stringByDeletingPathExtension]]; printf("%s\n", [[[r sortedArrayUsingSelector: @selector(compare:)] componentsJoinedByString: @", "] UTF8String]); return 0; }
		if ([cmd isEqual: @"find"]) { NSString *w = [a firstObject]; if (!w) { Usage(); return 1; } for (NSString *f in [[fm contentsOfDirectoryAtPath: PrefsDir() error: NULL] sortedArrayUsingSelector: @selector(compare:)]) { if (![f hasSuffix: @".plist"]) continue; NSDictionary *d = Load([PrefsDir() stringByAppendingPathComponent: f]); NSMutableString *t = [NSMutableString string]; Print(d ?: @{}, 0, t); if ([t rangeOfString: w options: NSCaseInsensitiveSearch].length || [f rangeOfString: w options: NSCaseInsensitiveSearch].length) printf("Found %lu keys in domain '%s'\n", (unsigned long)[d count], [[f stringByDeletingPathExtension] UTF8String]); } return 0; }
		if (![a count]) { if ([cmd isEqual: @"read"]) { for (NSString *f in [[fm contentsOfDirectoryAtPath: PrefsDir() error: NULL] sortedArrayUsingSelector: @selector(compare:)]) if ([f hasSuffix: @".plist"]) { NSDictionary *d = Load([PrefsDir() stringByAppendingPathComponent: f]); NSMutableString *t = [NSMutableString string]; Print(d ?: @{}, 0, t); printf("Domain %s: %s\n", [[f stringByDeletingPathExtension] UTF8String], [t UTF8String]); } return 0; } Usage(); return 1; }
		if ([a[0] isEqual: @"-app"]) { if ([a count] < 2) { Usage(); return 1; } domain = BundleIdOfApp(a[1]); if (!domain) { fprintf(stderr, "No domain for application %s\n", [a[1] UTF8String]); return 1; } [a removeObjectAtIndex: 0]; [a removeObjectAtIndex: 0]; }
		else { domain = a[0]; [a removeObjectAtIndex: 0]; }
		NSString *file = FileOfDomain(domain); NSMutableDictionary *dict = Load(file);
		if ([cmd isEqual: @"read"] || [cmd isEqual: @"read-type"]) {
			if (!dict) { fprintf(stderr, "Error: Domain '%s' not found.\n", [domain UTF8String]); return 1; }
			id v = dict; if ([a count]) { v = dict[a[0]]; if (!v) { fprintf(stderr, "Error: Could not find key '%s' in domain '%s'.\n", [a[0] UTF8String], IsGlobal(domain) ? "kCFPreferencesAnyApplication" : [domain UTF8String]); return 1; } }
			if ([cmd isEqual: @"read-type"]) { const char *t = [v isKindOfClass: [NSString class]] ? "string" : [v isKindOfClass: [NSDictionary class]] ? "dictionary" : [v isKindOfClass: [NSArray class]] ? "array" : [v isKindOfClass: [NSData class]] ? "data" : [v isKindOfClass: [NSDate class]] ? "date" : IsBool(v) ? "boolean" : (!strcmp([v objCType], "d") || !strcmp([v objCType], "f")) ? "float" : "integer"; printf("Type is %s\n", t); return 0; }
			if ([v isKindOfClass: [NSDictionary class]] || [v isKindOfClass: [NSArray class]]) { NSMutableString *t = [NSMutableString string]; Print(v, 0, t); printf("%s\n", [t UTF8String]); } else printf("%s\n", [Scalar(v) UTF8String]); return 0;
		}
		if ([cmd isEqual: @"delete"]) {
			if (![a count]) { if (![fm removeItemAtPath: file error: NULL]) { fprintf(stderr, "\nDomain %s does not exist\n", [domain UTF8String]); return 1; } [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.apple.cfprefsd.domainChanged" object: domain userInfo: nil deliverImmediately: YES]; return 0; }
			if (!dict || !dict[a[0]]) { fprintf(stderr, "Error: Could not find key '%s' in domain '%s'.\nDefaults have not been changed.\n", [a[0] UTF8String], IsGlobal(domain) ? "kCFPreferencesAnyApplication" : [domain UTF8String]); return 1; } [dict removeObjectForKey: a[0]]; return Save(dict, file, domain) ? 0 : 1;
		}
		if ([cmd isEqual: @"rename"]) { if ([a count] < 2 || !dict || !dict[a[0]]) { fprintf(stderr, "\nCould not rename, domain/default pair (%s, %s) does not exist\n", [domain UTF8String], [a count] ? [a[0] UTF8String] : ""); return 1; } dict[a[1]] = dict[a[0]]; [dict removeObjectForKey: a[0]]; return Save(dict, file, domain) ? 0 : 1; }
		if ([cmd isEqual: @"export"]) { if (!dict || [a count] < 1) return 1; if ([a[0] isEqual: @"-"]) { NSData *x = [NSPropertyListSerialization dataWithPropertyList: dict format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL]; fwrite([x bytes], 1, [x length], stdout); return 0; } NSData *b = [NSPropertyListSerialization dataWithPropertyList: dict format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL]; return [b writeToFile: [a[0] stringByExpandingTildeInPath] atomically: YES] ? 0 : 1; }
		if ([cmd isEqual: @"import"]) { if ([a count] < 1) return 1; NSData *d = [a[0] isEqual: @"-"] ? [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] : [NSData dataWithContentsOfFile: [a[0] stringByExpandingTildeInPath]]; id o = d ? [NSPropertyListSerialization propertyListWithData: d options: NSPropertyListMutableContainers format: NULL error: NULL] : nil; if (![o isKindOfClass: [NSDictionary class]]) { fprintf(stderr, "Could not read a property list dictionary\n"); return 1; } return Save(o, file, domain) ? 0 : 1; }
		if ([cmd isEqual: @"write"]) {
			if (![a count]) { Usage(); return 1; }
			if ([a count] == 1) { id o = Parse(a[0]); if (![o isKindOfClass: [NSDictionary class]]) { fprintf(stderr, "Rep argument is not a dictionary\nDefaults have not been changed.\n"); return 1; } return Save(o, file, domain) ? 0 : 1; }
			if (!dict) dict = [NSMutableDictionary dictionary]; NSString *key = a[0]; NSArray *rest = [a subarrayWithRange: NSMakeRange(1, [a count] - 1)]; NSUInteger i = 0; NSString *t = rest[0];
			if ([t isEqual: @"-array"] || [t isEqual: @"-array-add"]) {                                                  /* the elements: plain strings, or -type value pairs */
				NSMutableArray *arr = [NSMutableArray array]; if ([t isEqual: @"-array-add"] && [dict[key] isKindOfClass: [NSArray class]]) [arr addObjectsFromArray: dict[key]];
				i = 1; while (i < [rest count]) { NSString *e = rest[i]; if ([e hasPrefix: @"-"] && [e length] > 1 && i + 1 < [rest count]) { i++; [arr addObject: Typed(rest, &i, e)]; } else { [arr addObject: e]; i++; } } dict[key] = arr; }
			else if ([t isEqual: @"-dict"] || [t isEqual: @"-dict-add"]) { NSMutableDictionary *d = [t isEqual: @"-dict-add"] && [dict[key] isKindOfClass: [NSDictionary class]] ? [dict[key] mutableCopy] : [NSMutableDictionary dictionary]; i = 1; while (i + 1 < [rest count]) { NSString *k = rest[i++]; NSString *e = rest[i]; if ([e hasPrefix: @"-"] && i + 1 < [rest count]) { i++; d[k] = Typed(rest, &i, e); } else { d[k] = e; i++; } } dict[key] = d; }
			else if ([t hasPrefix: @"-"] && [t length] > 1) { i = 1; dict[key] = Typed(rest, &i, t); }
			else dict[key] = Parse(t);
			return Save(dict, file, domain) ? 0 : 1;
		}
		Usage(); return 1;
	}
}
