/* Code signing queries: no signature exists here, the calls report that (applications fall back to their unsigned behaviour). */
#include <Security/Security.h>
int32_t SecCodeCopySelf(SecCSFlags flags, SecCodeRef *self) { (void)flags; if (self) *self = NULL; return errSecNotAvailable; }
int32_t SecCodeCopySigningInformation(SecCodeRef code, SecCSFlags flags, CFDictionaryRef *information) { (void)code; (void)flags; if (information) *information = NULL; return errSecNotAvailable; }
