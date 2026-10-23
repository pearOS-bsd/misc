# .DS_Store

`finder/src/TDSStore.mm` reads and writes the file the Finder keeps its folder settings in: a "buddy allocator" file (header `Bud1`, block offset table, table of contents with `DSDB`) holding a B-tree of records (file name UTF-16, structure id, type `bool/long/shor/type/comp/dutc/blob/ustr`, value). Records are sorted by lower-cased name (code points, literal) and then structure id.

Used: `Iloc` (icon centre x, y in the icon view, 8 bytes of 0xFF.. 0), `icvp` on "." (icon view options: iconSize, arrangeBy, ...), `vSrn`. Every other record is kept as read and written back.

Checked against the Mac (macOS 27):
- a real 372-record file from the Mac, read and written again by TDSStore, gives the same records (`tools/dsprobe/dsstore_roundtrip.mm`, `tools/dsprobe/dsstore_check.py`);
- a file written by the Finder on BSD (an icon dragged to (402, 376)) was opened by the real Finder of the Mac: the icon sat at exactly that place (left 370 = 402 - 32, top 344 = 376 - 32 from the view origin).

Written by the Finder: `Iloc`, `icvp`, `bwsp` (window), `vstl`, `lsvp` (list view columns, widths, sort), `vSrn`. Not written yet: `pBBk` (background); tags stay in extended attributes.
