/* <launch.h>: launchd's job and socket interface. The system has no launchd; the data types (launch_data_t) are real and in memory, launch_activate_socket answers from the descriptors a supervisor passes in
 * WSBSD_LAUNCH_SOCKETS ("Name=fd,fd;Name2=fd"), and launch_msg answers that the service is not available. Implemented in sdk/src/Launch.c */
#ifndef WSBSD_LAUNCH_H
#define WSBSD_LAUNCH_H
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct _launch_data *launch_data_t;
typedef enum { LAUNCH_DATA_DICTIONARY = 1, LAUNCH_DATA_ARRAY, LAUNCH_DATA_FD, LAUNCH_DATA_INTEGER, LAUNCH_DATA_REAL, LAUNCH_DATA_BOOL, LAUNCH_DATA_STRING, LAUNCH_DATA_OPAQUE, LAUNCH_DATA_ERRNO, LAUNCH_DATA_MACHPORT } launch_data_type_t;
#define LAUNCH_KEY_SUBMITJOB "SubmitJob"
#define LAUNCH_KEY_REMOVEJOB "RemoveJob"
#define LAUNCH_KEY_STARTJOB "StartJob"
#define LAUNCH_KEY_STOPJOB "StopJob"
#define LAUNCH_KEY_GETJOB "GetJob"
#define LAUNCH_KEY_GETJOBS "GetJobs"
#define LAUNCH_JOBKEY_LABEL "Label"
#define LAUNCH_JOBKEY_PROGRAM "Program"
#define LAUNCH_JOBKEY_PROGRAMARGUMENTS "ProgramArguments"
#define LAUNCH_JOBKEY_SOCKETS "Sockets"
#define LAUNCH_JOBKEY_RUNATLOAD "RunAtLoad"
launch_data_t launch_data_alloc(launch_data_type_t type);
launch_data_t launch_data_new_string(const char *s);
launch_data_t launch_data_new_integer(long long v);
launch_data_t launch_data_new_bool(bool b);
launch_data_t launch_data_new_fd(int fd);
launch_data_type_t launch_data_get_type(const launch_data_t d);
const char *launch_data_get_string(const launch_data_t d);
long long launch_data_get_integer(const launch_data_t d);
bool launch_data_get_bool(const launch_data_t d);
int launch_data_get_fd(const launch_data_t d);
int launch_data_get_errno(const launch_data_t d);
bool launch_data_dict_insert(launch_data_t dict, launch_data_t value, const char *key);
launch_data_t launch_data_dict_lookup(const launch_data_t dict, const char *key);
size_t launch_data_dict_get_count(const launch_data_t dict);
bool launch_data_array_set_index(launch_data_t array, launch_data_t value, size_t i);
launch_data_t launch_data_array_get_index(const launch_data_t array, size_t i);
size_t launch_data_array_get_count(const launch_data_t array);
void launch_data_free(launch_data_t d);
launch_data_t launch_msg(const launch_data_t msg);
int launch_activate_socket(const char *name, int **fds, size_t *cnt);
#ifdef __cplusplus
}
#endif
#endif
