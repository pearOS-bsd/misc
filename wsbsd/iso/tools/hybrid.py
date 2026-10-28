#!/usr/bin/env python3
"""Makes an ISO that also boots when written to a USB stick (dd, Etcher, Rufus in DD mode).

    hybrid.py image.iso ESP_BYTES

The ISO (makefs cd9660) boots from an optical disc through its El Torito EFI image. A PC's firmware boots a stick through a GPT whose EFI system partition holds the loader. The EFI image is
already in the ISO as a FAT file system, so a GPT that has one partition over exactly those bytes serves both: the first 32 KiB of an ISO 9660 image (the "system area") are unused, the protective
MBR and the GPT header and entries (512-byte sectors: LBA 0 to 33) fit in them, and the backup GPT is appended at the end. This is what FreeBSD's own hybrid ISOs and Debian's do.
ESP_BYTES is the size of the EFI image (the El Torito catalogue cannot say it: its sector count is 16 bits).
"""
import struct, sys, uuid, zlib

ISO_SECTOR = 2048
EFI_TYPE = uuid.UUID("C12A7328-F81F-11D2-BA4B-00A0C93EC93B")


def efi_image_lba(f):
    f.seek(17 * ISO_SECTOR)                                   # boot record volume descriptor
    br = f.read(ISO_SECTOR)
    if br[0] != 0 or br[1:6] != b"CD001" or not br[7:30].startswith(b"EL TORITO SPECIFICATION"):
        raise SystemExit("no El Torito boot record")
    cat = struct.unpack("<I", br[0x47:0x4B])[0]
    f.seek(cat * ISO_SECTOR)
    data = f.read(ISO_SECTOR)
    # validation entry (32 bytes: header id 1, platform id), then the initial/default entry, then section headers (0x90 last, 0x91 more) each followed by entries
    plat = data[1]
    entries = [(plat, data[32:64])]
    i = 64
    while i + 32 <= len(data) and data[i] in (0x90, 0x91):
        entries.append((data[i + 1], data[i + 32:i + 64]))
        i += 64
    for want in (0xEF, None):                                 # the EFI entry; makefs of some FreeBSD versions leaves the platform id 0 (80x86) and the only entry is the EFI image
        for plat, e in entries:
            if e[0] == 0x88 and (want is None or plat == want):
                return struct.unpack("<I", e[8:12])[0]        # load RBA in 2048-byte sectors
    raise SystemExit("no EFI boot entry in the El Torito catalogue")


def main():
    path, esp_bytes = sys.argv[1], int(sys.argv[2])
    with open(path, "r+b") as f:
        lba = efi_image_lba(f)
        f.seek(0, 2)
        size = f.tell()
        pad = (-size) % 512
        if pad:
            f.write(b"\0" * pad)
            size += pad
        total = size // 512 + 33                              # + the backup entries (32 sectors) and the backup header (1)
        first, last_usable = 34, total - 34
        start = lba * ISO_SECTOR // 512
        end = start + (esp_bytes + 511) // 512 - 1
        if start < first or end > last_usable:
            raise SystemExit("the EFI image does not fit the GPT")
        guid_disk, guid_part = uuid.uuid4(), uuid.uuid4()
        entry = EFI_TYPE.bytes_le + guid_part.bytes_le + struct.pack("<QQQ", start, end, 0) + "EFI system".encode("utf-16le").ljust(72, b"\0")
        array = entry + b"\0" * (128 * 128 - len(entry))
        acrc = zlib.crc32(array) & 0xFFFFFFFF

        def header(cur, backup, entries_lba):
            h = struct.pack("<8sIIIIQQQQ16sQIII", b"EFI PART", 0x00010000, 92, 0, 0, cur, backup, first, last_usable, guid_disk.bytes_le, entries_lba, 128, 128, acrc)
            h = h[:16] + struct.pack("<I", zlib.crc32(h[:16] + b"\0\0\0\0" + h[20:]) & 0xFFFFFFFF) + h[20:]
            return h.ljust(512, b"\0")

        mbr = bytearray(512)
        mbr[446:462] = struct.pack("<BBBBBBBBII", 0, 0, 2, 0, 0xEE, 0xFF, 0xFF, 0xFF, 1, min(total - 1, 0xFFFFFFFF))
        mbr[510:512] = b"\x55\xAA"
        f.seek(0)
        f.write(bytes(mbr))
        f.write(header(1, total - 1, 2))
        f.write(array)                                        # LBA 2 .. 33, inside the ISO's 32 KiB system area
        f.seek(size)
        f.write(array)
        f.write(header(total - 1, 1, total - 33))
    print("hybrid: ESP at LBA %d (%d sectors), %d sectors in all" % (start, end - start + 1, total))


main()
