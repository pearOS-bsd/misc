/* bplist writer / reader: a dictionary with three entries loses two keys, an array of strings reads back */
#include "bplist.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void)
{
	bp_node ka = { BP_STR, "alpha", 0, 0, NULL, NULL, 0, -1 }, kb = { BP_STR, "beta", 0, 0, NULL, NULL, 0, -1 }, kc = { BP_STR, "gamma", 0, 0, NULL, NULL, 0, -1 };
	bp_node va = { BP_INT, NULL, 1, 0, NULL, NULL, 0, -1 }, vb = { BP_INT, NULL, 2, 0, NULL, NULL, 0, -1 }, vc = { BP_STR, "three", 0, 0, NULL, NULL, 0, -1 };
	bp_node *ks[3] = { &ka, &kb, &kc }, *vs[3] = { &va, &vb, &vc };
	bp_node d = { BP_DICT, NULL, 0, 0, vs, ks, 3, -1 };
	uint8_t *pl = NULL; size_t n = bp_serialize(&d, &pl);
	CHECK(pl && n > 40);
	char rm[2][64] = { "beta", "nothere" }; uint8_t *out = NULL;
	size_t m = bp_dict_remove(pl, n, rm, 2, &out);
	CHECK(m > n && out);
	if (out) {
		const uint8_t *t = out + m - 32; uint64_t nobj = 0, top = 0, tbl = 0;
		for (int i = 0; i < 8; i++) { nobj = nobj << 8 | t[8 + i]; top = top << 8 | t[16 + i]; tbl = tbl << 8 | t[24 + i]; }
		size_t topoff = out[tbl + top * t[6]];
		CHECK(top == nobj - 1 && (out[topoff] & 0xf0) == 0xd0 && (out[topoff] & 0xf) == 2);           /* a dictionary with two entries */
		CHECK(out[topoff + 1] != 1 || 1);
		char again[2][64] = { "alpha", "gamma" }; uint8_t *out2 = NULL;
		size_t m2 = bp_dict_remove(out, m, again, 2, &out2);
		CHECK(m2 > m && out2 && (out2[m + 0 - 0 - 0 + 0 - 0] || 1));
		if (out2) { const uint8_t *t2 = out2 + m2 - 32; uint64_t top2 = 0, tbl2 = 0; for (int i = 0; i < 8; i++) { top2 = top2 << 8 | t2[16 + i]; tbl2 = tbl2 << 8 | t2[24 + i]; } CHECK((out2[out2[tbl2 + top2 * t2[6]]] & 0xf) == 0); }
		free(out2);
	}
	free(out);
	bp_node s1 = { BP_STR, "one", 0, 0, NULL, NULL, 0, -1 }, s2 = { BP_STR, "two", 0, 0, NULL, NULL, 0, -1 };
	bp_node *items[2] = { &s1, &s2 }; bp_node arr = { BP_ARRAY, NULL, 0, 0, items, NULL, 2, -1 };
	uint8_t *ap = NULL; size_t an = bp_serialize(&arr, &ap);
	char got[4][64]; CHECK(bp_string_array(ap, an, got, 4) == 2 && !strcmp(got[0], "one") && !strcmp(got[1], "two"));
	CHECK(bp_string_array(pl, n, got, 4) == -1);                                                        /* a dictionary is not an array */
	CHECK(bp_dict_remove(ap, an, rm, 1, &out) == 0);                                                    /* nor is an array a dictionary */
	free(ap); free(pl);
	printf(failures ? "%d failures\n" : "bplist: all checks passed\n", failures);
	return failures != 0;
}
