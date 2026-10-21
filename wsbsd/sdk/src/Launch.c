/* launch.h: in-memory launch_data values, socket activation from WSBSD_LAUNCH_SOCKETS, and launch_msg that reports the missing service (errno values as launchd's own error replies). */
#include <launch.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

struct _launch_data { launch_data_type_t type; long long i; char *s; int fd; struct _launch_data **v; char **k; size_t n; };
launch_data_t launch_data_alloc(launch_data_type_t t) { launch_data_t d = calloc(1, sizeof *d); d->type = t; d->fd = -1; return d; }
launch_data_t launch_data_new_string(const char *s) { launch_data_t d = launch_data_alloc(LAUNCH_DATA_STRING); d->s = strdup(s ? s : ""); return d; }
launch_data_t launch_data_new_integer(long long v) { launch_data_t d = launch_data_alloc(LAUNCH_DATA_INTEGER); d->i = v; return d; }
launch_data_t launch_data_new_bool(bool b) { launch_data_t d = launch_data_alloc(LAUNCH_DATA_BOOL); d->i = b; return d; }
launch_data_t launch_data_new_fd(int fd) { launch_data_t d = launch_data_alloc(LAUNCH_DATA_FD); d->fd = fd; return d; }
launch_data_type_t launch_data_get_type(const launch_data_t d) { return d->type; }
const char *launch_data_get_string(const launch_data_t d) { return d->type == LAUNCH_DATA_STRING ? d->s : NULL; }
long long launch_data_get_integer(const launch_data_t d) { return d->i; }
bool launch_data_get_bool(const launch_data_t d) { return d->i != 0; }
int launch_data_get_fd(const launch_data_t d) { return d->fd; }
int launch_data_get_errno(const launch_data_t d) { return (int)d->i; }
static void grow(launch_data_t d) { d->v = realloc(d->v, (d->n + 1) * sizeof *d->v); if (d->type == LAUNCH_DATA_DICTIONARY) d->k = realloc(d->k, (d->n + 1) * sizeof *d->k); }
bool launch_data_dict_insert(launch_data_t d, launch_data_t value, const char *key)
{
	if (d->type != LAUNCH_DATA_DICTIONARY) return false;
	for (size_t i = 0; i < d->n; i++) if (!strcmp(d->k[i], key)) { launch_data_free(d->v[i]); d->v[i] = value; return true; }
	grow(d); d->v[d->n] = value; d->k[d->n] = strdup(key); d->n++; return true;
}
launch_data_t launch_data_dict_lookup(const launch_data_t d, const char *key) { if (d->type == LAUNCH_DATA_DICTIONARY) for (size_t i = 0; i < d->n; i++) if (!strcmp(d->k[i], key)) return d->v[i]; return NULL; }
size_t launch_data_dict_get_count(const launch_data_t d) { return d->n; }
bool launch_data_array_set_index(launch_data_t a, launch_data_t value, size_t i)
{
	if (a->type != LAUNCH_DATA_ARRAY) return false;
	while (a->n <= i) { grow(a); a->v[a->n++] = NULL; }
	launch_data_free(a->v[i]); a->v[i] = value; return true;
}
launch_data_t launch_data_array_get_index(const launch_data_t a, size_t i) { return a->type == LAUNCH_DATA_ARRAY && i < a->n ? a->v[i] : NULL; }
size_t launch_data_array_get_count(const launch_data_t a) { return a->n; }
void launch_data_free(launch_data_t d)
{
	if (!d) return;
	for (size_t i = 0; i < d->n; i++) { launch_data_free(d->v[i]); if (d->k) free(d->k[i]); }
	free(d->v); free(d->k); free(d->s); free(d);
}
launch_data_t launch_msg(const launch_data_t msg) { (void)msg; launch_data_t r = launch_data_alloc(LAUNCH_DATA_ERRNO); r->i = ENOTSUP; return r; }

int launch_activate_socket(const char *name, int **fds, size_t *cnt)
{
	const char *env = getenv("WSBSD_LAUNCH_SOCKETS"); if (!env || !name) return ENOENT;
	size_t nl = strlen(name); const char *p = env;
	while (*p) {
		const char *end = strchr(p, ';'); size_t len = end ? (size_t)(end - p) : strlen(p);
		if (len > nl && !strncmp(p, name, nl) && p[nl] == '=') {
			size_t n = 1; for (const char *c = p + nl + 1; c < p + len; c++) if (*c == ',') n++;
			int *v = malloc(n * sizeof *v); size_t k = 0; const char *c = p + nl + 1;
			while (c < p + len && k < n) { v[k++] = atoi(c); const char *cm = memchr(c, ',', (size_t)(p + len - c)); if (!cm) break; c = cm + 1; }
			*fds = v; *cnt = k; return 0;
		}
		if (!end) break; p = end + 1;
	}
	return ENOENT;
}
