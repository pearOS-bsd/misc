# Ploader

Moved to https://github.com/pearOS-bsd/ploader (the boot manager, a rEFInd fork). The `ploader` job of `.github/workflows/iso.yml` checks it out and builds it; `iso/build.sh` takes the build from `PLOADER_DIR`.
