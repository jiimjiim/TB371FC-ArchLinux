#!/usr/bin/env python3
"""Android sparse -> sparse (hole-preserving) raw image."""
import struct, sys

src_path, dst_path = sys.argv[1], sys.argv[2]
BLK = 4096
f = open(src_path, 'rb')
magic, maj, mnr, fsz, csz, blk, total, chunks, cks = struct.unpack('<IHHHHIIII', f.read(28))
assert magic == 0xED26FF3A
out = open(dst_path, 'wb')
pos = 0
while True:
    h = f.read(12)
    if not h:
        break
    ct, res, cnt, tsz = struct.unpack('<HHII', h)
    body = tsz - 12
    if ct == 0xCAC1:
        out.seek(pos * blk)
        out.write(f.read(body))
        pos += cnt
    elif ct == 0xCAC3:
        pos += cnt
    elif ct == 0xCAC2:
        v = f.read(4)
        out.seek(pos * blk)
        out.write(v * cnt)
        pos += cnt
    else:
        f.seek(body, 1)
        pos += cnt
out.truncate(pos * blk)
out.close()
print("raw blocks %d -> %d bytes" % (pos, pos * blk))
