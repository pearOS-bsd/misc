#ifndef BPLIST_H
#define BPLIST_H
#include <stddef.h>
#include <stdint.h>
enum { BP_INT, BP_STR, BP_ARRAY, BP_DICT, BP_REAL };
typedef struct bp_node { int kind; const char *s; uint64_t i; double d; struct bp_node **kids; struct bp_node **keys; int n; int id; } bp_node;
/* returns a malloc'd bplist00 of the tree (at most 255 objects of fewer than 256 bytes of offsets), its length; the caller frees *out */
size_t bp_serialize(bp_node *root, uint8_t **out);
/* the text of a property list holding one string (bplist00, ASCII or UTF-16 string as the first object); 0 when it is anything else */
int bp_string(const uint8_t *b, size_t n, char *out, size_t cap);
#endif
