/* i915probe: asks the i915 driver the questions Mesa's iris asks first, and prints the answer or the error of each: chip, slices / subslices / EUs, the engines, the topology, whether a context can be made.
 * It tells a GPU that is not set up (zero slices, no engines) from one that Mesa cannot use. Usage: i915probe [/dev/dri/renderD128]
 * Build: cc -O2 -I/usr/local/include/libdrm -I/usr/local/include -o i915probe i915probe.c */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/ioctl.h>
#include <i915_drm.h>

static int fd;

static void param(const char *name, int p)
{
	int v = -12345;
	struct drm_i915_getparam gp = { .param = p, .value = &v };
	if (ioctl(fd, DRM_IOCTL_I915_GETPARAM, &gp) == 0) printf("  %-34s = %d (0x%x)\n", name, v, (unsigned)v);
	else printf("  %-34s : error %d (%s)\n", name, errno, strerror(errno));
}

static void *query(uint64_t id, int32_t *len_out)
{
	struct drm_i915_query_item item = { .query_id = id };
	struct drm_i915_query q = { .num_items = 1, .items_ptr = (uintptr_t)&item };
	if (ioctl(fd, DRM_IOCTL_I915_QUERY, &q) != 0) { printf("  query %llu: ioctl error %d (%s)\n", (unsigned long long)id, errno, strerror(errno)); return NULL; }
	if (item.length <= 0) { printf("  query %llu: length %d (the driver does not have it)\n", (unsigned long long)id, item.length); return NULL; }
	void *buf = calloc(1, item.length);
	item.data_ptr = (uintptr_t)buf;
	if (ioctl(fd, DRM_IOCTL_I915_QUERY, &q) != 0 || item.length < 0) { printf("  query %llu: second call error %d (%s), length %d\n", (unsigned long long)id, errno, strerror(errno), item.length); free(buf); return NULL; }
	*len_out = item.length;
	return buf;
}

int main(int argc, char **argv)
{
	const char *node = argc > 1 ? argv[1] : "/dev/dri/renderD128";
	fd = open(node, O_RDWR | O_CLOEXEC);
	if (fd < 0) { printf("open %s: %s\n", node, strerror(errno)); return 1; }
	printf("== i915probe %s\n", node);
	char name[64] = "", date[64] = "", desc[128] = "";
	struct drm_version v = { .name = name, .name_len = sizeof name - 1, .date = date, .date_len = sizeof date - 1, .desc = desc, .desc_len = sizeof desc - 1 };
	if (ioctl(fd, DRM_IOCTL_VERSION, &v) == 0) printf("  driver %s %d.%d.%d (%s)\n", name, v.version_major, v.version_minor, v.version_patchlevel, date);
	else printf("  DRM_IOCTL_VERSION: %s\n", strerror(errno));
	printf("-- getparam\n");
	param("CHIPSET_ID", I915_PARAM_CHIPSET_ID);
	param("REVISION", I915_PARAM_REVISION);
	param("SLICE_MASK", I915_PARAM_SLICE_MASK);
	param("SUBSLICE_MASK", I915_PARAM_SUBSLICE_MASK);
	param("SUBSLICE_TOTAL", I915_PARAM_SUBSLICE_TOTAL);
	param("EU_TOTAL", I915_PARAM_EU_TOTAL);
	param("MIN_EU_IN_POOL", I915_PARAM_MIN_EU_IN_POOL);
	param("CS_TIMESTAMP_FREQUENCY", I915_PARAM_CS_TIMESTAMP_FREQUENCY);
	param("HAS_ALIASING_PPGTT", I915_PARAM_HAS_ALIASING_PPGTT);
	param("HAS_EXEC_SOFTPIN", I915_PARAM_HAS_EXEC_SOFTPIN);
	param("HAS_GPU_RESET", I915_PARAM_HAS_GPU_RESET);
	param("HAS_SCHEDULER", I915_PARAM_HAS_SCHEDULER);
	param("HAS_CONTEXT_ISOLATION", I915_PARAM_HAS_CONTEXT_ISOLATION);
	param("PERF_REVISION", I915_PARAM_PERF_REVISION);
	printf("-- engines (I915_QUERY_ENGINE_INFO)\n");
	int32_t len = 0; void *buf = query(DRM_I915_QUERY_ENGINE_INFO, &len);
	if (buf) {
		struct drm_i915_query_engine_info *ei = buf;
		printf("  %u engines\n", ei->num_engines);
		for (unsigned i = 0; i < ei->num_engines; i++) printf("  engine class %u instance %u\n", ei->engines[i].engine.engine_class, ei->engines[i].engine.engine_instance);
		free(buf);
	}
	printf("-- topology (I915_QUERY_TOPOLOGY_INFO)\n");
	buf = query(DRM_I915_QUERY_TOPOLOGY_INFO, &len);
	if (buf) {
		struct drm_i915_query_topology_info *t = buf;
		printf("  max_slices %u max_subslices %u max_eus_per_subslice %u (data %d bytes)\n", t->max_slices, t->max_subslices, t->max_eus_per_subslice, len);
		free(buf);
	}
	printf("-- memory regions (I915_QUERY_MEMORY_REGIONS)\n");
	buf = query(DRM_I915_QUERY_MEMORY_REGIONS, &len);
	if (buf) { printf("  %u regions\n", ((struct drm_i915_query_memory_regions *)buf)->num_regions); free(buf); }
	printf("-- context\n");
	struct drm_i915_gem_context_create cc = { 0 };
	if (ioctl(fd, DRM_IOCTL_I915_GEM_CONTEXT_CREATE, &cc) == 0) { printf("  GEM_CONTEXT_CREATE ok, id %u\n", cc.ctx_id); struct drm_i915_gem_context_destroy d = { .ctx_id = cc.ctx_id }; ioctl(fd, DRM_IOCTL_I915_GEM_CONTEXT_DESTROY, &d); }
	else printf("  GEM_CONTEXT_CREATE: error %d (%s)\n", errno, strerror(errno));
	close(fd);
	return 0;
}
