/* os_log: unified logging is not there; the macros evaluate nothing (diagnostic messages only) */
#ifndef WSBSD_OS_LOG_H
#define WSBSD_OS_LOG_H
typedef void *os_log_t;
typedef unsigned char os_log_type_t;
#define OS_LOG_DEFAULT ((os_log_t)0)
#define OS_LOG_TYPE_DEFAULT ((os_log_type_t)0)
#define OS_LOG_TYPE_INFO ((os_log_type_t)1)
#define OS_LOG_TYPE_DEBUG ((os_log_type_t)2)
#define OS_LOG_TYPE_ERROR ((os_log_type_t)0x10)
#define OS_LOG_TYPE_FAULT ((os_log_type_t)0x11)
#define os_log_create(sub, cat) ((os_log_t)0)
#define os_log(log, ...) ((void)(log))
#define os_log_info(log, ...) ((void)(log))
#define os_log_debug(log, ...) ((void)(log))
#define os_log_error(log, ...) ((void)(log))
#define os_log_fault(log, ...) ((void)(log))
#define os_log_info_enabled(log) (0)
#define os_log_debug_enabled(log) (0)
#define os_log_type_enabled(log, type) (0)
#define os_log_with_type(log, type, ...) ((void)(log))
#endif
