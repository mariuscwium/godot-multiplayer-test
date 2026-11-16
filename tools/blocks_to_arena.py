#!/usr/bin/env python3 -I
"""Expand the 40x40 block grid (maps/arena-blocks.txt) into the 80x80 cell map (maps/arena.txt).

Each block becomes 2x2 cells. A spawn block `P` marks the top-left cell with `P` (a tank spawns on the
2x2 area starting at that cell) and the other three cells are open ground.
Usage: tools/blocks_to_arena.py [blocks.txt] [arena.txt]
"""
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "maps/arena-blocks.txt"
dst = sys.argv[2] if len(sys.argv) > 2 else "maps/arena.txt"
rows = [r.rstrip("\n") for r in open(src) if r.strip()]
assert len(rows) == 40 and all(len(r) == 40 for r in rows), "expected a 40x40 grid"
assert set("".join(rows)) <= set(".BSWIGP"), "unknown block character"
out = []
for r in rows:
    top = "".join(("P." if c == "P" else c * 2) for c in r)
    bottom = "".join((".." if c == "P" else c * 2) for c in r)
    out += [top, bottom]
open(dst, "w").write("\n".join(out) + "\n")
print("wrote", dst, len(out), "x", len(out[0]))
