/* ca_scene: decoder + painter of the CoreAnimation commit stream of the render server protocol (messages 0x9c42..0x9c45).
 * One scene per process for now.  Out-of-line data (Image pixels) is read from <dir>/ca-ool-<n>-<k>.bin, where n numbers the complex messages and k is the descriptor. */
#ifndef CA_SCENE_H
#define CA_SCENE_H
#include <stdint.h>
#include <stddef.h>
void ca_set_dir(const char *dir);
int ca_load_file(const char *path);		/* the whole stream (u32 length + message, repeated): rebuilds the scene; 0 on success */
void ca_paint(uint8_t *bgra, int w, int h, int stride);
int ca_nlayers(void);
int ca_nimages(void);
int ca_resynced(void);
#endif
