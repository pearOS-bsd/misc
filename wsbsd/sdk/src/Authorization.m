/* Authorization Services: rights and the references to them. The right database is a property list (/usr/local/etc/wsbsd/authorization.plist, WSBSD_AUTH_DB overrides): right name -> rule name
 * ("allow", "deny", "is-admin", "authenticate-admin", "authenticate-session-owner") or a dictionary with "class" and "group". Root holds every right. Another user holds a right the rule allows
 * (class allow; class user / group when the user is in that group). A rule that needs a password cannot be satisfied: there is no security agent to ask, the answer is errAuthorizationDenied
 * (errAuthorizationInteractionNotAllowed when the call did not allow interaction). */
#import <Foundation/Foundation.h>
#include <Security/Authorization.h>
#include <Security/Security.h>
#include <grp.h>
#include <pwd.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>

@interface WsbsdAuth : NSObject { @public NSMutableSet *granted; } @end
@implementation WsbsdAuth @end
static NSMutableDictionary *gRefs; static NSLock *gLock;
static void Init(void) { static dispatch_once_t o; dispatch_once(&o, ^{ gRefs = [NSMutableDictionary dictionary]; gLock = [NSLock new]; }); }
static NSString *DBPath(void) { const char *e = getenv("WSBSD_AUTH_DB"); return [NSString stringWithUTF8String: e ?: "/usr/local/etc/wsbsd/authorization.plist"]; }
static NSMutableDictionary *LoadDB(void) { return [[NSDictionary dictionaryWithContentsOfFile: DBPath()] mutableCopy] ?: [NSMutableDictionary dictionary]; }
static NSString *Name(const char *c) { return c ? [NSString stringWithUTF8String: c] : nil; }

static BOOL InGroup(const char *group)
{
	struct group *g = getgrnam(group); if (!g) return NO; if (getgid() == g->gr_gid || getegid() == g->gr_gid) return YES;
	struct passwd *pw = getpwuid(getuid()); if (!pw) return NO; for (char **m = g->gr_mem; m && *m; m++) if (!strcmp(*m, pw->pw_name)) return YES; return NO;
}
/* 0 held, 1 needs authentication, 2 denied */
static int Evaluate(NSString *right)
{
	if (geteuid() == 0) return 0;
	id def = LoadDB()[right]; NSString *cls = [def isKindOfClass: [NSString class]] ? def : [def isKindOfClass: [NSDictionary class]] ? def[@"class"] : nil;
	if ([cls isEqual: @"allow"]) return 0; if ([cls isEqual: @"deny"]) return 2;
	if ([def isKindOfClass: [NSDictionary class]] && [def[@"group"] length] && InGroup([def[@"group"] UTF8String]) && [cls isEqual: @"user"]) return 0;
	if ([cls isEqual: @"is-admin"]) return InGroup("wheel") ? 0 : 2;
	return 1;                                                                  /* unknown right, or one that asks for a password */
}

OSStatus AuthorizationFreeItemSet(AuthorizationItemSet *set) { if (!set) return errAuthorizationInvalidSet; free(set->items); free(set); return errAuthorizationSuccess; }
OSStatus AuthorizationCreate(const AuthorizationRights *r, const AuthorizationEnvironment *e, AuthorizationFlags f, AuthorizationRef *a)
{
	Init(); (void)e; if (!a) return errAuthorizationInvalidRef;
	WsbsdAuth *o = [WsbsdAuth new]; o->granted = [NSMutableSet set]; [gLock lock]; gRefs[@((uintptr_t)(__bridge void *)o)] = o; [gLock unlock]; *a = (AuthorizationRef)CFBridgingRetain(o);
	if (r && r->count && (f & kAuthorizationFlagExtendRights)) { OSStatus st = AuthorizationCopyRights(*a, r, e, f, NULL); if (st) { AuthorizationFree(*a, 0); *a = NULL; return st; } }
	return errAuthorizationSuccess;
}
OSStatus AuthorizationFree(AuthorizationRef a, AuthorizationFlags f)
{
	Init(); (void)f; if (!a) return errAuthorizationInvalidRef; WsbsdAuth *o = (__bridge WsbsdAuth *)a; [gLock lock]; [gRefs removeObjectForKey: @((uintptr_t)(__bridge void *)o)]; [gLock unlock]; CFRelease(a); return errAuthorizationSuccess;
}
OSStatus AuthorizationCopyRights(AuthorizationRef a, const AuthorizationRights *r, const AuthorizationEnvironment *e, AuthorizationFlags f, AuthorizationRights **out)
{
	(void)e; if (!a) return errAuthorizationInvalidRef; if (!r) return errAuthorizationInvalidSet; WsbsdAuth *o = (__bridge WsbsdAuth *)a;
	AuthorizationRights *res = out ? calloc(1, sizeof *res) : NULL; if (res) res->items = calloc(r->count ?: 1, sizeof *res->items);
	OSStatus st = errAuthorizationSuccess;
	for (uint32_t i = 0; i < r->count; i++) {
		NSString *n = Name(r->items[i].name); int v = [o->granted containsObject: n] ? 0 : Evaluate(n);
		if (v == 0) { [o->granted addObject: n]; if (res) res->items[res->count++] = r->items[i]; }
		else if (!(f & kAuthorizationFlagPartialRights)) { st = (v == 1 && !(f & kAuthorizationFlagInteractionAllowed)) ? errAuthorizationInteractionNotAllowed : errAuthorizationDenied; break; }
	}
	if (st != errAuthorizationSuccess && res) { AuthorizationFreeItemSet(res); res = NULL; }
	if (out) *out = res; return st;
}
OSStatus AuthorizationExecuteWithPrivileges(AuthorizationRef a, const char *path, AuthorizationFlags f, char *const *args, FILE **pipeOut)
{
	(void)f; if (!a) return errAuthorizationInvalidRef; if (geteuid() != 0 || !path) return errAuthorizationToolExecuteFailure;
	int fds[2]; if (pipeOut && pipe(fds)) return errAuthorizationInternal;
	pid_t pid = fork(); if (pid < 0) return errAuthorizationToolExecuteFailure;
	if (pid == 0) { if (pipeOut) { close(fds[0]); dup2(fds[1], 1); close(fds[1]); } char *const none[] = { (char *)path, NULL }; execv(path, args ? (char *const *)args : none); _exit(127); }
	if (pipeOut) { close(fds[1]); *pipeOut = fdopen(fds[0], "r+"); } else { int status; waitpid(pid, &status, 0); }
	return errAuthorizationSuccess;
}
OSStatus AuthorizationMakeExternalForm(AuthorizationRef a, AuthorizationExternalForm *x)
{
	Init(); if (!a || !x) return errAuthorizationInvalidRef; memset(x, 0, sizeof *x); uintptr_t k = (uintptr_t)a; memcpy(x->bytes, &k, sizeof k); uint32_t pid = (uint32_t)getpid(); memcpy(x->bytes + 8, &pid, 4); return errAuthorizationSuccess;
}
OSStatus AuthorizationCreateFromExternalForm(const AuthorizationExternalForm *x, AuthorizationRef *a)
{
	Init(); if (!x || !a) return errAuthorizationInvalidRef; *a = NULL; uintptr_t k; uint32_t pid; memcpy(&k, x->bytes, sizeof k); memcpy(&pid, x->bytes + 8, 4);
	if (pid != (uint32_t)getpid()) return errAuthorizationInvalidRef;                                      /* the reference lives in the process that made the form */
	[gLock lock]; WsbsdAuth *o = gRefs[@(k)]; [gLock unlock]; if (!o) return errAuthorizationInvalidRef; *a = (AuthorizationRef)CFBridgingRetain(o); return errAuthorizationSuccess;
}
OSStatus AuthorizationRightGet(const char *right, CFDictionaryRef *def)
{
	NSString *n = Name(right); if (!n) return errAuthorizationInvalidSet; id d = LoadDB()[n]; if (!d) { if (def) *def = NULL; return errAuthorizationDenied; }
	if (def) *def = (CFDictionaryRef)CFBridgingRetain([d isKindOfClass: [NSDictionary class]] ? d : @{ @"class": d }); return errAuthorizationSuccess;
}
OSStatus AuthorizationRightSet(AuthorizationRef a, const char *right, CFTypeRef def, CFStringRef descKey, CFBundleRef bundle, CFStringRef table)
{
	(void)descKey; (void)bundle; (void)table; if (!a) return errAuthorizationInvalidRef; NSString *n = Name(right); if (!n || !def) return errAuthorizationInvalidSet;
	if (geteuid() != 0) return errAuthorizationDenied;                                                    /* only root edits the database */
	NSMutableDictionary *db = LoadDB(); id dv = (__bridge id)def;
	if (CFGetTypeID(def) == CFStringGetTypeID()) { char b[256]; if (!CFStringGetCString((CFStringRef)def, b, sizeof b, kCFStringEncodingUTF8)) return errAuthorizationInvalidSet; dv = [NSString stringWithUTF8String: b]; }
	db[n] = dv;                  /* a plain NSString: property list writing trips over corebase string objects */ NSString *p = DBPath();
	[[NSFileManager defaultManager] createDirectoryAtPath: [p stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL];
	return [db writeToFile: p atomically: YES] ? errAuthorizationSuccess : errAuthorizationInternal;
}
OSStatus AuthorizationRightRemove(AuthorizationRef a, const char *right)
{
	if (!a) return errAuthorizationInvalidRef; NSString *n = Name(right); if (!n) return errAuthorizationInvalidSet; if (geteuid() != 0) return errAuthorizationDenied;
	NSMutableDictionary *db = LoadDB(); if (!db[n]) return errAuthorizationSuccess; [db removeObjectForKey: n]; return [db writeToFile: DBPath() atomically: YES] ? errAuthorizationSuccess : errAuthorizationInternal;
}
