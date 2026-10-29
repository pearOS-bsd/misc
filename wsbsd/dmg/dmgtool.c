/* dmgtool: reads Apple disk images the way macOS mounts them, without macOS: UDIF containers (raw, zero, zlib, bzip2 chunks), the partition of type Apple_HFS (or a bare HFS+ volume), the HFS+ / HFSX
 * file system inside (catalog and extents overflow B-trees, data forks, symbolic links, hard links), and extracts the tree. The Finder "mounts" a .dmg by extracting it under /Volumes/<volume name>.
 *   dmgtool info IMAGE            volume name, number of folders / files, total size
 *   dmgtool ls IMAGE              the tree (path, mode, size)
 *   dmgtool extract IMAGE DIR     the files of the volume into DIR (made if needed)
 * Not supported yet (reported, the file is skipped): APFS volumes, lzfse / lzma / adc chunks, decmpfs-compressed files (their content is in an attribute), encrypted images. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <utime.h>
#include <zlib.h>
#include <bzlib.h>

static uint16_t be16(const uint8_t *p) { return (uint16_t)(p[0] << 8 | p[1]); }
static uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static uint64_t be64(const uint8_t *p) { return (uint64_t)be32(p) << 32 | be32(p + 4); }
static void die(const char *m) { fprintf(stderr, "dmgtool: %s\n", m); exit(1); }

/* ---------- UDIF ---------- */
static uint8_t *img; static uint64_t img_size;       /* the whole disk image rebuilt in memory */
static int b64v(int c) { if (c >= 'A' && c <= 'Z') return c - 'A'; if (c >= 'a' && c <= 'z') return c - 'a' + 26; if (c >= '0' && c <= '9') return c - '0' + 52; return c == '+' ? 62 : c == '/' ? 63 : -1; }
static size_t b64dec(const char *s, const char *e, uint8_t *out)
{
	size_t n = 0; uint32_t acc = 0; int bits = 0;
	for (; s < e; s++) { int v = b64v((unsigned char)*s); if (v < 0) continue; acc = acc << 6 | (uint32_t)v; bits += 6; if (bits >= 8) { bits -= 8; out[n++] = (uint8_t)(acc >> bits); } }
	return n;
}
typedef struct { uint64_t first, count; char name[160]; } part_t;
static part_t parts[64]; static int nparts;
static void load_udif(const uint8_t *f, uint64_t size)
{
	if (size < 512 || memcmp(f + size - 512, "koly", 4)) die("not a UDIF disk image (no koly trailer): only .dmg files of that kind are supported");
	const uint8_t *k = f + size - 512; uint64_t data_off = be64(k + 24), xml_off = be64(k + 216), xml_len = be64(k + 224);
	if (xml_off + xml_len > size) die("bad plist range"); const char *x = (const char *)f + xml_off, *xe = x + xml_len;
	const char *bk = NULL; for (const char *p = x; p + 14 < xe; p++) if (!memcmp(p, "<key>blkx</key>", 15)) { bk = p; break; }
	if (!bk) die("no blkx in the image's property list");
	const char *arr = strstr(bk, "<array>"), *arr_end = arr ? strstr(arr, "</array>") : NULL; if (!arr_end) die("blkx array");
	uint64_t total = 0; struct { uint8_t *mish; size_t len; char name[160]; } blk[64]; int nb = 0;
	for (const char *p = arr; p < arr_end && nb < 64;) {
		const char *d = strstr(p, "<dict>"); if (!d || d > arr_end) break; const char *de = strstr(d, "</dict>"); if (!de) break;
		const char *dk = strstr(d, "<key>Data</key>"); const char *nk = strstr(d, "<key>Name</key>");
		if (dk && dk < de) { const char *ds = strstr(dk, "<data>"), *dend = ds ? strstr(ds, "</data>") : NULL; if (ds && dend && dend < de + 8) {
			ds += 6; blk[nb].mish = malloc((size_t)(dend - ds) + 8); blk[nb].len = b64dec(ds, dend, blk[nb].mish); blk[nb].name[0] = 0;
			if (nk && nk < de) { const char *ss = strstr(nk, "<string>"); const char *se = ss ? strstr(ss, "</string>") : NULL; if (ss && se && se < de) { size_t l = (size_t)(se - ss - 8); if (l > 159) l = 159; memcpy(blk[nb].name, ss + 8, l); blk[nb].name[l] = 0; } }
			nb++; } }
		p = de + 7;
	}
	for (int i = 0; i < nb; i++) { const uint8_t *m = blk[i].mish; if (blk[i].len < 204 || memcmp(m, "mish", 4)) continue; uint64_t e = be64(m + 8) + be64(m + 16); if (e > total) total = e; }
	img_size = total * 512; if (!img_size) die("empty image");
	img = mmap(NULL, img_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0); if (img == MAP_FAILED) die("out of memory for the image");
	for (int i = 0; i < nb; i++) {
		const uint8_t *m = blk[i].mish; if (blk[i].len < 204 || memcmp(m, "mish", 4)) continue;
		uint64_t first = be64(m + 8), count = be64(m + 16), doff = be64(m + 24); uint32_t nch = be32(m + 200);
		if (nparts < 64) { parts[nparts].first = first; parts[nparts].count = count; snprintf(parts[nparts].name, sizeof parts[nparts].name, "%s", blk[i].name); nparts++; }
		for (uint32_t c = 0; c < nch && 204 + (size_t)(c + 1) * 40 <= blk[i].len + 4; c++) {
			const uint8_t *ch = m + 204 + (size_t)c * 40; uint32_t type = be32(ch); uint64_t sec = be64(ch + 8), cnt = be64(ch + 16), off = be64(ch + 24), len = be64(ch + 32);
			uint64_t dst = (first + sec) * 512, dlen = cnt * 512; if (dst + dlen > img_size) continue; uint64_t src = data_off + doff + off; if (type != 0 && type != 2 && type != 0xFFFFFFFFu && type != 0x7FFFFFFEu && src + len > size) die("chunk outside the file");
			if (type == 0 || type == 2 || type == 0x7FFFFFFEu || type == 0xFFFFFFFFu) continue;       /* zero fill / ignore: the memory is zero already */
			else if (type == 1) memcpy(img + dst, f + src, (size_t)(len < dlen ? len : dlen));
			else if (type == 0x80000005u) { uLongf out = (uLongf)dlen; if (uncompress(img + dst, &out, f + src, (uLong)len) != Z_OK) die("zlib chunk"); }
			else if (type == 0x80000006u) { unsigned int out = (unsigned int)dlen; if (BZ2_bzBuffToBuffDecompress((char *)img + dst, &out, (char *)(f + src), (unsigned int)len, 0, 0) != BZ_OK) die("bzip2 chunk"); }
			else { fprintf(stderr, "dmgtool: chunk type 0x%x (lzfse / lzma / adc) is not supported\n", type); exit(2); }
		}
	}
}

/* ---------- HFS+ ---------- */
static const uint8_t *vol; static uint64_t vol_size; static uint32_t bsz;       /* the HFS+ volume (start of the partition) */
typedef struct { uint32_t start, count; } ext_t;
typedef struct { uint64_t size; uint32_t total; ext_t e[8]; } fork_t;
static void fork_parse(const uint8_t *p, fork_t *f) { f->size = be64(p); f->total = be32(p + 12); for (int i = 0; i < 8; i++) { f->e[i].start = be32(p + 16 + 8 * i); f->e[i].count = be32(p + 20 + 8 * i); } }
static fork_t catalog_fk, extents_fk;
static uint8_t *cat; static uint64_t cat_len; static uint8_t *ext; static uint64_t ext_len;
static void read_extents(const fork_t *f, uint32_t fileID, int rsrc, uint8_t *out, uint64_t want);
/* the extents overflow file: records for forks with more than 8 extents: key = fork type (0 data, 0xFF resource), file ID, start block */
static int overflow_find(uint32_t fileID, int rsrc, uint32_t start, ext_t out[8])
{
	if (!ext) return 0; uint32_t ns = be16(ext + 32), node = be32(ext + 24);
	while (node) {
		const uint8_t *n = ext + (uint64_t)node * ns; uint16_t nr = be16(n + 10);
		for (uint16_t i = 0; i < nr; i++) {
			uint16_t off = be16(n + ns - 2 * (i + 1)); const uint8_t *r = n + off; if (be16(r) != 10) continue;
			if ((r[2] == 0xFF) == (rsrc != 0) && be32(r + 4) == fileID && be32(r + 8) == start) { for (int k = 0; k < 8; k++) { out[k].start = be32(r + 12 + 8 * k); out[k].count = be32(r + 16 + 8 * k); } return 1; }
		}
		node = be32(n);
	}
	return 0;
}
static void read_extents(const fork_t *f, uint32_t fileID, int rsrc, uint8_t *out, uint64_t want)
{
	uint64_t done = 0; uint32_t blocks_seen = 0; const ext_t *ex = f->e; ext_t more[8]; int idx = 0;
	while (done < want) {
		if (idx == 8) { if (!overflow_find(fileID, rsrc, blocks_seen, more)) break; ex = more; idx = 0; }
		if (!ex[idx].count) break;
		uint64_t off = (uint64_t)ex[idx].start * bsz, len = (uint64_t)ex[idx].count * bsz; if (off + len > vol_size) break;
		if (len > want - done) len = want - done; memcpy(out + done, vol + off, (size_t)len); done += len; blocks_seen += ex[idx].count; idx++;
	}
	if (done < want) memset(out + done, 0, (size_t)(want - done));
}
typedef struct { uint32_t parent, id; uint16_t kind; uint16_t mode; uint32_t special; uint32_t ftype, fcreator; uint16_t flags; uint32_t mdate; fork_t data; char *name; } ent_t;
static ent_t *ents; static size_t nents, capents;
static char *utf8(const uint8_t *u, uint16_t n)
{
	char *s = malloc((size_t)n * 3 + 1), *o = s;
	for (uint16_t i = 0; i < n; i++) {
		uint32_t c = be16(u + 2 * i); if (c >= 0xD800 && c < 0xDC00 && i + 1 < n) { uint32_t d = be16(u + 2 * (i + 1)); if (d >= 0xDC00 && d < 0xE000) { c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); i++; } }
		if (c < 0x80) { if (c == 0) c = '?'; *o++ = (char)c; } else if (c < 0x800) { *o++ = (char)(0xC0 | c >> 6); *o++ = (char)(0x80 | (c & 0x3F)); }
		else if (c < 0x10000) { *o++ = (char)(0xE0 | c >> 12); *o++ = (char)(0x80 | ((c >> 6) & 0x3F)); *o++ = (char)(0x80 | (c & 0x3F)); }
		else { *o++ = (char)(0xF0 | c >> 18); *o++ = (char)(0x80 | ((c >> 12) & 0x3F)); *o++ = (char)(0x80 | ((c >> 6) & 0x3F)); *o++ = (char)(0x80 | (c & 0x3F)); }
	}
	*o = 0; for (char *q = s; *q; q++) if (*q == '/') *q = ':';       /* HFS+ keeps a '/' of a POSIX name as ':' and a ':' as '/': the other way round when read */
	return s;
}
static int cmp_ent(const void *a, const void *b) { const ent_t *x = a, *y = b; return x->parent != y->parent ? (x->parent < y->parent ? -1 : 1) : strcmp(x->name, y->name); }
static void load_hfs(const uint8_t *v, uint64_t size)
{
	vol = v; vol_size = size; const uint8_t *h = v + 1024; if (size < 2048 || (memcmp(h, "H+", 2) && memcmp(h, "HX", 2))) die("no HFS+ volume (an APFS image is not supported yet)");
	bsz = be32(h + 40); fork_parse(h + 112 + 80 * 1, &extents_fk); fork_parse(h + 112 + 80 * 2, &catalog_fk);
	ext_len = extents_fk.size; ext = malloc(ext_len ? ext_len : 1); if (ext_len) read_extents(&extents_fk, 3, 0, ext, ext_len); else ext = NULL;
	cat_len = catalog_fk.size; cat = malloc(cat_len); read_extents(&catalog_fk, 4, 0, cat, cat_len);
	uint32_t ns = be16(cat + 32), node = be32(cat + 24);
	while (node) {
		const uint8_t *n = cat + (uint64_t)node * ns; uint16_t nr = be16(n + 10);
		for (uint16_t i = 0; i < nr; i++) {
			uint16_t off = be16(n + ns - 2 * (i + 1)); const uint8_t *r = n + off; uint16_t kl = be16(r); const uint8_t *key = r + 2, *rec = r + 2 + kl; if (kl & 1) rec++;
			uint16_t rt = be16(rec); if (rt != 1 && rt != 2) continue;
			if (nents == capents) { capents = capents ? capents * 2 : 1024; ents = realloc(ents, capents * sizeof *ents); }
			ent_t *e = &ents[nents++]; memset(e, 0, sizeof *e); e->parent = be32(key); e->name = utf8(key + 6, be16(key + 4)); e->kind = rt; e->id = be32(rec + 8);
			e->mode = be16(rec + 42); e->special = be32(rec + 44); e->mdate = be32(rec + 16);
			if (rt == 2) { e->flags = be16(rec + 2); e->ftype = be32(rec + 48); e->fcreator = be32(rec + 52); fork_parse(rec + 88, &e->data); }
		}
		node = be32(n);
	}
	qsort(ents, nents, sizeof *ents, cmp_ent);
}
static void range_of(uint32_t parent, size_t *lo, size_t *hi)
{
	size_t a = 0, b = nents; while (a < b) { size_t m = (a + b) / 2; if (ents[m].parent < parent) a = m + 1; else b = m; } *lo = a;
	b = nents; while (a < b) { size_t m = (a + b) / 2; if (ents[m].parent <= parent) a = m + 1; else b = m; } *hi = a;
}
static const ent_t *find_name(uint32_t parent, const char *name) { size_t lo, hi; range_of(parent, &lo, &hi); for (size_t i = lo; i < hi; i++) if (!strcmp(ents[i].name, name)) return &ents[i]; return NULL; }
static int is_private(const ent_t *e) { return e->kind == 1 && (!strncmp(e->name + (strlen(e->name) >= 4 ? 4 : 0), "HFS+ Private Data", 17) || !strncmp(e->name, ".HFS+ Private Directory Data", 28)); }
static uint32_t private_dir(void)
{
	size_t lo, hi; range_of(2, &lo, &hi);
	for (size_t i = lo; i < hi; i++) if (ents[i].kind == 1 && (!strncmp(ents[i].name + 4, "HFS+ Private Data", 17) || !strncmp(ents[i].name, ".HFS+ Private Directory Data", 28))) return ents[i].id;
	return 0;
}
static void walk(uint32_t dir, const char *path, int (*visit)(const ent_t *, const char *, void *), void *ctx, uint32_t priv)
{
	size_t lo, hi; range_of(dir, &lo, &hi);
	for (size_t i = lo; i < hi; i++) {
		const ent_t *e = &ents[i]; if (dir == 2 && (e->id == priv || is_private(e))) continue; if (e->name[0] == 0 && e->kind == 1) continue;
		char *p = malloc(strlen(path) + strlen(e->name) + 2); sprintf(p, "%s%s%s", path, path[0] ? "/" : "", e->name);
		if (visit(e, p, ctx)) { if (e->kind == 1) walk(e->id, p, visit, ctx, priv); } free(p);
	}
}
static uint8_t *file_bytes(const ent_t *e, uint64_t *len)
{
	const ent_t *src = e;
	if (e->kind == 2 && e->ftype == 0x686C6E6B /* hlnk */ && e->fcreator == 0x6866732B /* hfs+ */) { char nm[32]; snprintf(nm, sizeof nm, "iNode%u", e->special); uint32_t pd = private_dir(); const ent_t *t = pd ? find_name(pd, nm) : NULL; if (t) src = t; }
	*len = src->data.size; uint8_t *b = malloc(*len ? *len : 1); read_extents(&src->data, src->id, 0, b, *len); return b;
}
/* ---------- commands ---------- */
static int do_ls(const ent_t *e, const char *p, void *c) { (void)c; printf("%c %04o %10llu %s\n", e->kind == 1 ? 'd' : (e->mode & 0170000) == 0120000 ? 'l' : '-', e->mode & 07777, (unsigned long long)(e->kind == 2 ? e->data.size : 0), p); return 1; }
typedef struct { const char *dst; int files, dirs, skipped; uint64_t bytes; } xctx;
static int mkdirs(const char *path, mode_t m) { char *t = strdup(path); for (char *q = t + 1; *q; q++) if (*q == '/') { *q = 0; mkdir(t, 0755); *q = '/'; } int r = mkdir(t, m); free(t); return r; }
static int do_extract(const ent_t *e, const char *p, void *c)
{
	xctx *x = c; char *full = malloc(strlen(x->dst) + strlen(p) + 2); sprintf(full, "%s/%s", x->dst, p);
	if (e->kind == 1) { mkdirs(full, 0755); chmod(full, (e->mode & 0777) ? (mode_t)((e->mode & 0777) | 0700) : 0755); x->dirs++; free(full); return 1; }
	if (e->flags & 0x0004 /* kHFSHasAttributes? decmpfs files keep their content in an attribute */ && e->data.size == 0 && e->ftype != 0) { }
	uint64_t len; uint8_t *b = file_bytes(e, &len);
	if ((e->mode & 0170000) == 0120000) { char *t = malloc(len + 1); memcpy(t, b, len); t[len] = 0; unlink(full); if (symlink(t, full)) fprintf(stderr, "dmgtool: symlink %s: %s\n", p, strerror(errno)); free(t); x->files++; }
	else {
		unlink(full); int fd = open(full, O_WRONLY | O_CREAT | O_TRUNC, 0644); if (fd < 0) { fprintf(stderr, "dmgtool: %s: %s\n", p, strerror(errno)); x->skipped++; }
		else { uint64_t w = 0; while (w < len) { ssize_t n = write(fd, b + w, (size_t)(len - w)); if (n <= 0) break; w += (uint64_t)n; } close(fd); chmod(full, (mode_t)((e->mode & 07777) ? (e->mode & 07777) | 0600 : 0644)); x->files++; x->bytes += len;
			if (e->mdate > 2082844800u) { struct utimbuf tb = { 0, (time_t)(e->mdate - 2082844800u) }; tb.actime = tb.modtime; utime(full, &tb); } }
	}
	free(b); free(full); return 1;
}
static int do_count(const ent_t *e, const char *p, void *c) { (void)p; xctx *x = c; if (e->kind == 1) x->dirs++; else { x->files++; x->bytes += e->data.size; } return 1; }
static const char *volname(void) { size_t lo, hi; range_of(1, &lo, &hi); return lo < hi ? ents[lo].name : "Untitled"; }

int main(int argc, char **argv)
{
	if (argc < 3) { fprintf(stderr, "usage: dmgtool info IMAGE | ls IMAGE | extract IMAGE DIR\n"); return 1; }
	int fd = open(argv[2], O_RDONLY); if (fd < 0) { perror(argv[2]); return 1; } struct stat st; fstat(fd, &st);
	uint8_t *f = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_PRIVATE, fd, 0); if (f == MAP_FAILED) die("mmap");
	load_udif(f, (uint64_t)st.st_size);
	int hfs = -1; for (int i = 0; i < nparts; i++) if (strstr(parts[i].name, "Apple_HFS")) { hfs = i; break; }
	if (hfs >= 0) load_hfs(img + parts[hfs].first * 512, parts[hfs].count * 512); else load_hfs(img, img_size);
	uint32_t priv = private_dir();
	if (!strcmp(argv[1], "info")) { xctx x = { 0 }; walk(2, "", do_count, &x, priv); printf("volume: %s\nfolders: %d\nfiles: %d\nbytes: %llu\n", volname(), x.dirs, x.files, (unsigned long long)x.bytes); }
	else if (!strcmp(argv[1], "ls")) walk(2, "", do_ls, NULL, priv);
	else if (!strcmp(argv[1], "extract") && argc > 3) { xctx x = { argv[3], 0, 0, 0, 0 }; mkdirs(argv[3], 0755); walk(2, "", do_extract, &x, priv); printf("%s\n", volname()); fprintf(stderr, "dmgtool: %d folders, %d files, %llu bytes%s\n", x.dirs, x.files, (unsigned long long)x.bytes, x.skipped ? " (some skipped)" : ""); return x.skipped ? 3 : 0; }
	else { fprintf(stderr, "usage: dmgtool info IMAGE | ls IMAGE | extract IMAGE DIR\n"); return 1; }
	return 0;
}
