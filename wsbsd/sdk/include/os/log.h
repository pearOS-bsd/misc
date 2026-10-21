/* os_log: unified logging is not there. Errors and faults go to stderr with the process name; info and debug only when WSBSD_OSLOG is set. The format is Apple's (%{public}s, %{private}@ ...: the braces are dropped),
 * %@ prints an object. Implemented in sdk/src/OSLog.m */
#ifndef WSBSD_OS_LOG_H
#define WSBSD_OS_LOG_H
#include <stdarg.h>
typedef void *os_log_t;
typedef unsigned char os_log_type_t;
#define OS_LOG_DEFAULT ((os_log_t)0)
#define OS_LOG_TYPE_DEFAULT ((os_log_type_t)0)
#define OS_LOG_TYPE_INFO ((os_log_type_t)1)
#define OS_LOG_TYPE_DEBUG ((os_log_type_t)2)
#define OS_LOG_TYPE_ERROR ((os_log_type_t)0x10)
#define OS_LOG_TYPE_FAULT ((os_log_type_t)0x11)
#ifdef __cplusplus
extern "C" {
#endif
void wsbsd_os_log(int type, const char *format, ...);
#ifdef __cplusplus
}
#endif
#define os_log_create(sub, cat) ((os_log_t)0)
#define os_log(log, ...) ((void)(log), wsbsd_os_log(0, __VA_ARGS__))
#define os_log_info(log, ...) ((void)(log), wsbsd_os_log(1, __VA_ARGS__))
#define os_log_debug(log, ...) ((void)(log), wsbsd_os_log(2, __VA_ARGS__))
#define os_log_error(log, ...) ((void)(log), wsbsd_os_log(0x10, __VA_ARGS__))
#define os_log_fault(log, ...) ((void)(log), wsbsd_os_log(0x11, __VA_ARGS__))
#define os_log_info_enabled(log) (0)
#define os_log_debug_enabled(log) (0)
#define os_log_type_enabled(log, type) (0)
#define os_log_with_type(log, type, ...) ((void)(log), wsbsd_os_log((int)(type), __VA_ARGS__))
#endif
