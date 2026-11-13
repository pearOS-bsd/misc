/* ca_scene: decoder + painter of the CoreAnimation commit stream of the render server protocol (messages 0x9c42..0x9c45).
 * One scene per process for now.  Out-of-line data (Image pixels) is read from <dir>/ca-ool-<n>-<k>.bin, where n numbers the complex messages and k is the descriptor. */
#ifndef CA_SCENE_H
#define CA_SCENE_H
#include <stdint.h>
#include <stddef.h>
typedef uint8_t *(*ca_ool_fn)(void *ctx, int msg, int desc, size_t *size);	/* the out-of-line data of descriptor desc of the msg-th complex message: malloc'd, or NULL */
void ca_set_dir(const char *dir);
void ca_set_ool_loader(ca_ool_fn fn, void *ctx);	/* default: files in the directory */
void ca_reset(void);
int ca_feed(const uint8_t *msg, size_t n);		/* one commit message (as the render server received it, from the header on); returns the scene (one for each context) it went to, -1 if not understood */
int ca_nscenes(void);
uint32_t ca_scene_ctx(int scene);
void ca_paint_scene(int scene, uint8_t *bgra, int w, int h, int stride);	/* one scene on a transparent canvas (premultiplied BGRA) */
int ca_load_file(const char *path);		/* the whole stream (u32 length + message, repeated): rebuilds the scene; 0 on success */
void ca_paint(uint8_t *bgra, int w, int h, int stride);
int ca_nlayers(void);
int ca_nimages(void);
int ca_resynced(void);
#endif
