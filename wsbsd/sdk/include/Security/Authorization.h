/* <Security/Authorization.h> for the wsbsd SDK: Authorization Services: rights are kept in /usr/local/etc/wsbsd/authorization.plist (AuthorizationRightGet/Set/Remove); a right is granted to root and, for the rights that name a group, to its members (sdk/src/Authorization.m); there is no interactive security agent yet. */
#ifndef WSBSD_SECURITY_AUTHORIZATION_H
#define WSBSD_SECURITY_AUTHORIZATION_H
#if defined(__APPLE__)
#include_next <Security/Authorization.h>
#else
#include <stdint.h>
#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>
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
       errAuthorizationInternal = -60008, errAuthorizationInteractionNotAllowed = -60007, errAuthorizationToolExecuteFailure = -60031 };
enum { kAuthorizationFlagDefaults = 0, kAuthorizationFlagInteractionAllowed = 1, kAuthorizationFlagExtendRights = 2, kAuthorizationFlagPartialRights = 4,
       kAuthorizationFlagDestroyRights = 8, kAuthorizationFlagPreAuthorize = 16 };
#define kAuthorizationEmptyEnvironment NULL
#include <stdlib.h>
#define kAuthorizationRightExecute "system.privilege.admin"
#define kAuthorizationRuleClassAllow "allow"
#define kAuthorizationRuleClassDeny "deny"
#define kAuthorizationRuleIsAdmin "is-admin"
#define kAuthorizationRuleAuthenticateAsAdmin "authenticate-admin"
#define kAuthorizationRuleAuthenticateAsSessionUser "authenticate-session-owner"
#define kAuthorizationEnvironmentPrompt "prompt"
#ifdef __cplusplus
extern "C" {
#endif
OSStatus AuthorizationFreeItemSet(AuthorizationItemSet *set);
OSStatus AuthorizationCreate(const AuthorizationRights *rights, const AuthorizationEnvironment *environment, AuthorizationFlags flags, AuthorizationRef *authorization);
OSStatus AuthorizationFree(AuthorizationRef authorization, AuthorizationFlags flags);
OSStatus AuthorizationCopyRights(AuthorizationRef authorization, const AuthorizationRights *rights, const AuthorizationEnvironment *environment, AuthorizationFlags flags, AuthorizationRights **authorizedRights);
OSStatus AuthorizationExecuteWithPrivileges(AuthorizationRef authorization, const char *pathToTool, AuthorizationFlags flags, char *const *arguments, FILE **communicationsPipe);
OSStatus AuthorizationMakeExternalForm(AuthorizationRef authorization, AuthorizationExternalForm *extForm);
OSStatus AuthorizationCreateFromExternalForm(const AuthorizationExternalForm *extForm, AuthorizationRef *authorization);
OSStatus AuthorizationRightGet(const char *rightName, CFDictionaryRef *rightDefinition);
OSStatus AuthorizationRightSet(AuthorizationRef authRef, const char *rightName, CFTypeRef rightDefinition, CFStringRef descriptionKey, CFBundleRef bundle, CFStringRef localeTableName);
OSStatus AuthorizationRightRemove(AuthorizationRef authorization, const char *rightName);
#ifdef __cplusplus
}
#endif
#endif
#endif
