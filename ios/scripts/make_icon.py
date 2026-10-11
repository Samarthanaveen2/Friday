"""Draws Friday's app icon (1024x1024 PNG): accent background, white waveform bars.
Pure Python so it runs anywhere. Usage: python3 make_icon.py out.png"""
import struct, sys, zlib

N = 1024
BG = (0x43, 0x38, 0xCA)
FG = (255, 255, 255)
# Bar heights as a fraction of the icon, centred.
BARS = [0.18, 0.34, 0.52, 0.34, 0.18]
BAR_W, GAP = 76, 52

def inside_bar(x, y):
    total = len(BARS) * BAR_W + (len(BARS) - 1) * GAP
    left = (N - total) // 2
    for i, h in enumerate(BARS):
        x0 = left + i * (BAR_W + GAP)
        if not (x0 <= x < x0 + BAR_W):
            continue
        half = h * N / 2
        y0, y1 = N / 2 - half, N / 2 + half
        r = BAR_W / 2
        cx = x0 + r
        if y0 + r <= y <= y1 - r:
            return True
        for cy in (y0 + r, y1 - r):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                return True
    return False

rows = []
for y in range(N):
    row = bytearray(b"\x00")
    for x in range(N):
        row += bytes(FG if inside_bar(x, y) else BG)
    rows.append(bytes(row))

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
