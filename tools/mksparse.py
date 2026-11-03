#!/usr/bin/env python3
"""stream raw ext4 image -> Android sparse image (fastboot 用)"""
import sys, struct
BLK = 4096
RAW, DONT = 0xCAC1, 0xCAC3
ZERO = bytes(BLK)

def main():
    path = sys.argv[1]
    total_blocks = int(sys.argv[2])
    src = sys.stdin.buffer
    out = open(path, 'wb')
    out.write(b'\0' * 28)
    chunks = 0
    pending = bytearray(); pending_blocks = 0
    zero_run = 0
    def flush_raw():
        nonlocal chunks, pending, pending_blocks
        if pending_blocks:
            out.write(struct.pack('<HHII', RAW, 0, pending_blocks, 12 + len(pending)))
            out.write(pending)
            chunks += 1
            pending = bytearray(); pending_blocks = 0
    def flush_zero():
        nonlocal chunks, zero_run
        if zero_run:
            out.write(struct.pack('<HHII', DONT, 0, zero_run, 12))
            chunks += 1
            zero_run = 0
    done = 0
    while True:
        buf = src.read(8 * 1024 * 1024)
        if not buf:
            break
        if len(buf) % BLK:
            buf += bytes(BLK - len(buf) % BLK)
        if buf.count(0) == len(buf):
            flush_raw(); zero_run += len(buf) // BLK; done += len(buf) // BLK
            continue
        for off in range(0, len(buf), BLK):
            blk = buf[off:off + BLK]
            if blk == ZERO:
                flush_raw(); zero_run += 1
            else:
                flush_zero(); pending += blk; pending_blocks += 1
                if pending_blocks >= 4096:
                    flush_raw()
            done += 1
        if done % (1024 * 1024 // 4) == 0:
            print('progress %d/%d blocks' % (done, total_blocks), file=sys.stderr, flush=True)
    flush_raw(); flush_zero()
    out.seek(0)
    out.write(struct.pack('<IHHHHIIII', 0xED26FF3A, 1, 0, 28, 12, BLK, total_blocks, chunks, 0))
    out.close()
    print('sparse done: blocks=%d/%d chunks=%d' % (done, total_blocks, chunks), file=sys.stderr)
    if done != total_blocks:
        print('ERROR: input shorter than partition (%d < %d)' % (done, total_blocks), file=sys.stderr)
        sys.exit(1)

main()
