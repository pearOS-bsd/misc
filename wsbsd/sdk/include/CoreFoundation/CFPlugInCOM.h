/* CFPlugIn COM interfaces: the IUnknown layout and the HRESULT codes of the plug-in factories (QuickLook generators, importers ...) */
#ifndef WSBSD_CFPLUGINCOM_H
#define WSBSD_CFPLUGINCOM_H
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef SInt32 HRESULT;
typedef UInt32 ULONG;
typedef void *LPVOID;
typedef CFUUIDBytes REFIID;
#define S_OK ((HRESULT)0x00000000)
#define S_FALSE ((HRESULT)0x00000001)
#define E_UNEXPECTED ((HRESULT)0x8000FFFFL)
#define E_NOTIMPL ((HRESULT)0x80000001L)
#define E_OUTOFMEMORY ((HRESULT)0x8000000EL)
#define E_INVALIDARG ((HRESULT)0x80000003L)
#define E_NOINTERFACE ((HRESULT)0x80000004L)
#define E_POINTER ((HRESULT)0x80000005L)
#define E_HANDLE ((HRESULT)0x80000006L)
#define E_ABORT ((HRESULT)0x80000007L)
#define E_FAIL ((HRESULT)0x80000008L)
#define E_ACCESSDENIED ((HRESULT)0x80000009L)
#define SUCCEEDED(Status) ((HRESULT)(Status) >= 0)
#define FAILED(Status) ((HRESULT)(Status) < 0)
#define IUNKNOWN_C_GUTS void *_reserved; HRESULT (*QueryInterface)(void *thisPointer, REFIID iid, LPVOID *ppv); ULONG (*AddRef)(void *thisPointer); ULONG (*Release)(void *thisPointer)
typedef struct IUnknownVTbl { IUNKNOWN_C_GUTS; } IUnknownVTbl;
#ifdef __cplusplus
}
#endif
#endif
