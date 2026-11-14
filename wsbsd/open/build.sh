cc -arch x86_64 -DWS_DARWIN_ON_BSD -Iinclude -Wno-everything -o demo demo.c s/client.c s/compositor_sw.c s/region.c s/ipc.c s/evrec.c s/buffer.c 2>&1 | head -20
