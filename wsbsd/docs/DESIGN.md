# wsbsd: window server for FreeBSD

Goal: a native window server and Quartz-style compositor for FreeBSD (amd64/arm64), with no X11 and no Wayland.
Method: behaviour observed in macOS SkyLight with REA/Ghidra, reimplemented from scratch. No Apple code is copied.

## What SkyLight showed (macOS 27.0, arm64e)
- `WindowServer` is a 93 KB launcher. The server is in SkyLight (20,801 procedures).
- Client requests are MIG routines named `__X*`: **744** of them (`docs/skylight-server-routines.txt`).
  Window 190, Display 135, Space 82, Event 42, Key 41, Surface 33, Cursor 32, Connection 29, Session 26.
- Three compositors behind one interface: `CompositorMetal` (GPU), `CompositorSW` (CPU), `CompositorNoop`.
  `CompositorSW` works on IOSurfaces in BGRA, with `FillSurface`, `CopySurface`, `CompositeLayersToDestination`,
  `CreateShadowFromMask/Layers`, `CreateCaptureSurface`, `CreateDisplayStreamState`.
  `CompositeLayersToDestination` only dispatches; the per-pixel work runs in a block (not yet traced).

## Mapping to FreeBSD
| macOS | wsbsd |
|---|---|
| Mach ports, `mach_msg`, `bootstrap_look_up` | unix socket + kqueue; later Mach IPC from XNU (APSL 2.0) |
| XPC | small framed message layer over the same socket |
| IOSurface | shared pixel buffer (shm / memfd; dma-buf when the GPU path is on) |
| IOKit (display, HID) | DRM/KMS via drm-kmod; input via evdev (libinput) |
| Metal | EGL + OpenGL ES 2 on GBM (Mesa), Vulkan later |

## GPU acceleration (requested)
Runs on the BSD drivers: `drm-kmod` (i915, amdgpu, radeon) for KMS and rendering nodes, Mesa for EGL/GLES.
`ws_compositor` is the seam: `sw` exists and is tested; `gl` will implement `fill`, `over` and `flush` as
textured quads with premultiplied blending and a fence on flush, scanning out through KMS page flips.
The server model never changes between backends.

## Status
Working end to end (`make demo`, runs on macOS and is portable to FreeBSD: kqueue, unix sockets, POSIX shm):
- `wsd`: window server daemon (kqueue loop, unix socket IPC, shared-memory backing stores, headless PPM output).
- Protocol (`include/ws_proto.h`): connect, create/order/move/release window, alpha, level, shadow, flush,
  find window, screenshot. Names follow SkyLight routines. Client library: `include/ws_client.h`.
- Software compositor: premultiplied source-over, fill, copy, window opacity, levels and ordering.
- Shadows follow SkyLight's embedded shader (see below): nine-part cached mask, diffuse shadow with vertical offset,
  outer rim, white inner rim, all cut out of the window shape, drawn above the window.
  The numeric defaults (stdev 19 / offset 18 / density 0.665 active, 7 / 7 / 0.39 inactive; rim values) are NOT in SkyLight:
  AppKit and WindowManager pass them at run time. They come from an earlier measurement of macOS windows or are estimates.
- `test_window`: a client that draws a window (title bar, traffic lights, sidebar, controls, rounded corners)
  into shared memory, plus a back window and a translucent panel. Output: `window.png` after `make demo`.

Observed in SkyLight and not yet reproduced: tile-based compositing (`layer_tile_traverse`, `layer_tile_cut`)
with occlusion culling, per-layer colour-conversion LUTs, layers below opacity 0.0001 skipped.

- Input and cursor: pointer position, click-to-raise and focus, grab while a button is held, per-window event queues,
  key events to the focused window, software arrow cursor; protocol ops for injection and polling.
- FreeBSD backend `src/backend_kms.c` (DRM/KMS dumb buffers with page flips, evdev input), wired into `wsd -b kms`.
  UNTESTED: only syntax-checked against stub headers. See docs/FREEBSD.md.

Not done: running and fixing the KMS/evdev backend on real FreeBSD, GPU (`gl`) compositor, tile-based occlusion culling,
the Mach/XPC compatibility layer, spaces, multiple displays, window resize, text rendering, a real window manager
and Dock/menu bar, the other 700 or so protocol routines.

## Software compositing pipeline recovered from SkyLight (REA/Ghidra, macOS 27.0)
`CompositorSW::CompositeLayersToDestination` runs, inside `WSSessionConnectionPerformWithPluginOwner`:
1. Pick the kernel from the destination bitmap format: 8-bit formats -> `_layer_blit_byte`, float formats -> `_layer_blit_float`;
   the other formats log "not supported on this architecture" / "Unsupported destination".
2. `layer_tile_traverse` / `layer_tile_cut`: cut layers into tiles (arena allocated), skip layers with opacity < 0.0001,
   cache colour-conversion LUTs per (source, destination) colour space.
3. `layer_tile_walk` builds a work queue (`CGBlitWorkQueueEntry`); up to 8 entries run concurrently, otherwise serially.
4. `layer_blit_entry`: processes the tile in horizontal bands sized so per-layer scratch fits 16 KB, fetches each layer
   (`_CGLayerKitFetch` via a CoreGraphics software context, `_RenderAffineSW`, `_RenderMeshSW`, or a direct pointer with
   8.8 fixed-point sub-pixel offsets), then calls the kernel.
5. `_layer_blit_byte` is a selector: solid fill and same-format copy fast paths, `_sample` when scaled, `_ANY` generic,
   and specialised kernels for 2 or 3 stacked layers (`ARGB8_RGB8`, `ARGB8_ARGB8_RGB8`, `S8_*`, `RGBA_*`, `*_colormatch`).
6. Blend arithmetic (`_layer_blit_byte_ARGB8_RGB8`): premultiplied source; destination scaled by (255 - src alpha),
   floor-divided by 255 with (t + 1 + (t >> 8)) >> 8; saturating add. Opacity is 8.8 fixed point, applied as (x*o)>>8.
   `src/compositor_sw.c` now uses this arithmetic. The multiplier being (255 - alpha) is inferred, not confirmed.
Not yet read: `_layer_blit_float`, the `S8` mask kernels, `_RenderAffineSW`, the colour-match LUT code, the shadow blur
(`create_shadow_texture_from_vImage_with_description`).

## Shadow model recovered from SkyLight (strings: ShadowVerticalBlurRGBA.template, Shadow.mm, WindowShadow.cc)
Inputs per pixel: W window alpha, S shadow alpha (gaussian of the window shape, sampled with a vertical offset),
R outer-rim alpha, G inner glow. Output (premultiplied):
  rim = R * rimDensity * (1 - W);  out += rimColor * rim
  out.a += S * density * (1 - W) * (1 - rim)        // rim and diffuse shadow never stack
  out += innerRimColor * G * innerRimDensity * W      // white, inside the window edge
Properties: stdev, density, rimDensity, rimRadius, innerRimDensity, innerRimRadius, verticalOffset, rimStyle, rimColor,
innerRimColor, clipTop, contentAware; separate Active/Inactive sets; a per-field override mask merges the AppKit and
WindowManager layers. `radius = (int)(stdev * 2.8)`, max stdev 128. A mask is "nine-partable" when it can be sliced into
corners, edges and centre (that is how the cache works). Shadows render above their window (`WSWindowShadowWantsRenderAbove`).
Not recovered: the exact blur kernel (vImage on the software path, a template-generated gaussian in Metal).

## Protocol fidelity (subsystem 1): status
Done, from decompilation and black-box probes (details and evidence tags in docs/SPEC-SLS-WIRE.md):
- MIG subsystem 30000..30646: every routine's id, argc and max reply size (`docs/skylight-msgid-table.txt`, `include/sls_msgids.h`).
- Byte-exact request and reply layouts for 23 routines (including PostEventRecord with real CGEvent records, the NewConnectionPort handshake, ConnectionGetPIDAndVersion,
  WarpCursorPosition, SetWindowEventMask, GetCursorScale) (CreateWindow, TerminateWindow, MoveWindow, OrderWindow, SetWindowLevel,
  SetWindowListAlpha, Get/SetSubLevel, GetLevel/Alpha/FrameBounds/ShapeBounds/Count/OnScreenCount/Owner, FindWindow, MoveWindowList,
  OrderWindowList) with the original validation order and error codes; rights model.
- Region serialisation, checked against 12 vectors from the live system (`test/test_region.c`).
- Transport: SOCK_SEQPACKET + SCM_RIGHTS on FreeBSD (stream framing on macOS for tests), zero-allocation receive path.
- Event records: parser and builders verified byte-for-byte against events serialised by the live system.
- `make check` includes wire conformance tests (`test/test_wire.c`) that talk raw messages to a running wsd.
Asynchronous input: events for a window are pushed to its owner over the event channel returned by the handshake.
Not done: ~700 other routines, the window property plists (shadow), CA remote contexts (how real macOS windows get pixels),
shared-window-state memory, event shared memory, bootstrap/connection handshake. Pixel backing, flush, screenshot, input injection
and event polling still use private ids (39001+).

## Surface exchange (subsystem 2): status
Done: SkyLight surface routines (AddSurface, RemoveSurface, BindSurface, FlushSurface, GetSurfaceBinding) with real layouts, the IOSurface stride and
allocation rules (golden values from the live system, `test/test_buffer.c`), shared-memory buffers passed by SCM_RIGHTS, bind + commit, composition from the
bound buffer, cleanup when a client disconnects, a client test window drawn through this path (`make demo`).
Written and only syntax-checked against stub headers (never run): GBM allocation and dma-buf export (`-DWS_GBM`), EGLImage import with EGL_LINUX_DMA_BUF_EXT (`-DWS_EGL`).
Not done: tiled dma-bufs (need the GL compositor), multi-plane formats, FlushSurfaceInline (30096), BindSurface kinds 1 and 2, buffer release fences, and the
Core Animation context path real macOS windows use.
