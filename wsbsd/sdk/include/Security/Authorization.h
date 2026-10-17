/* <Security/Authorization.h> for the wsbsd SDK: Authorization Services (privilege elevation through the macOS security agent) do not exist; every call fails. */
#ifndef WSBSD_SECURITY_AUTHORIZATION_H
#define WSBSD_SECURITY_AUTHORIZATION_H
#if defined(__APPLE__)
#include_next <Security/Authorization.h>
#else
#include <stdint.h>
#include <stdio.h>
typedef int32_t OSStatus;
typedef struct AuthorizationOpaqueRef *AuthorizationRef;
typedef uint32_t AuthorizationFlags;
typedef const char *AuthorizationString;
typedef struct { AuthorizationString name; size_t valueLength; void *value; uint32_t flags; } AuthorizationItem;
typedef struct { uint32_t count; AuthorizationItem *items; } AuthorizationItemSet;
typedef AuthorizationItemSet AuthorizationRights;
typedef AuthorizationItemSet AuthorizationEnvironment;
typedef struct { char bytes[32]; } AuthorizationExternalForm;
enum { errAuthorizationSuccess = 0, errAuthorizationInvalidSet = -60001, errAuthorizationInvalidRef = -60002, errAuthorizationDenied = -60005, errAuthorizationCanceled = -60006,
       errAuthorizationInternal = -60008, errAuthorizationToolExecuteFailure = -60031 };
enum { kAuthorizationFlagDefaults = 0, kAuthorizationFlagInteractionAllowed = 1, kAuthorizationFlagExtendRights = 2, kAuthorizationFlagPartialRights = 4,
       kAuthorizationFlagDestroyRights = 8, kAuthorizationFlagPreAuthorize = 16 };
#define kAuthorizationEmptyEnvironment NULL
#define kAuthorizationRightExecute "system.privilege.admin"
static inline OSStatus AuthorizationCreate(const AuthorizationRights *r, const AuthorizationEnvironment *e, AuthorizationFlags f, AuthorizationRef *a) { (void)r; (void)e; (void)f; if (a) *a = 0; return errAuthorizationInternal; }
static inline OSStatus AuthorizationFree(AuthorizationRef a, AuthorizationFlags f) { (void)a; (void)f; return errAuthorizationInvalidRef; }
static inline OSStatus AuthorizationCopyRights(AuthorizationRef a, const AuthorizationRights *r, const AuthorizationEnvironment *e, AuthorizationFlags f, AuthorizationRights **o) { (void)a; (void)r; (void)e; (void)f; (void)o; return errAuthorizationDenied; }
static inline OSStatus AuthorizationExecuteWithPrivileges(AuthorizationRef a, const char *p, AuthorizationFlags f, char *const *args, FILE **pipe) { (void)a; (void)p; (void)f; (void)args; (void)pipe; return errAuthorizationToolExecuteFailure; }
static inline OSStatus AuthorizationMakeExternalForm(AuthorizationRef a, AuthorizationExternalForm *e) { (void)a; (void)e; return errAuthorizationInvalidRef; }
static inline OSStatus AuthorizationCreateFromExternalForm(const AuthorizationExternalForm *e, AuthorizationRef *a) { (void)e; if (a) *a = 0; return errAuthorizationInvalidRef; }
#endif
#endif
