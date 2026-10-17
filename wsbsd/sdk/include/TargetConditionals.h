/* TargetConditionals.h for the wsbsd SDK: the stack presents itself as macOS (AppKit) to source code that asks. */
#ifndef WSBSD_TARGETCONDITIONALS_H
#define WSBSD_TARGETCONDITIONALS_H
#define TARGET_OS_MAC 1
#define TARGET_OS_OSX 1
#define TARGET_OS_UNIX 0
#define TARGET_OS_WIN32 0
#define TARGET_OS_IPHONE 0
#define TARGET_OS_IOS 0
#define TARGET_OS_WATCH 0
#define TARGET_OS_TV 0
#define TARGET_OS_VISION 0
#define TARGET_OS_MACCATALYST 0
#define TARGET_OS_SIMULATOR 0
#define TARGET_OS_EMBEDDED 0
#define TARGET_IPHONE_SIMULATOR 0
#if defined(__x86_64__)
#define TARGET_CPU_X86_64 1
#define TARGET_CPU_X86 0
#define TARGET_CPU_ARM64 0
#define TARGET_CPU_ARM 0
#elif defined(__aarch64__)
#define TARGET_CPU_X86_64 0
#define TARGET_CPU_X86 0
#define TARGET_CPU_ARM64 1
#define TARGET_CPU_ARM 0
#else
#define TARGET_CPU_X86_64 0
#define TARGET_CPU_X86 0
#define TARGET_CPU_ARM64 0
#define TARGET_CPU_ARM 0
#endif
#define TARGET_CPU_PPC 0
#define TARGET_CPU_PPC64 0
#define TARGET_RT_LITTLE_ENDIAN 1
#define TARGET_RT_BIG_ENDIAN 0
#define TARGET_RT_64_BIT 1
#define TARGET_RT_MAC_MACHO 1
#define TARGET_RT_MAC_CFM 0
#endif
