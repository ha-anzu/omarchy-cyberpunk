#!/usr/bin/env python3
# Build the Night City pointer into an icon theme directory.
# Ships the SVG source. Does not write a home path, a hostname, or a serial.

import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


def pack_xcursor(png_sizes, hotspot32):
    images = []
    for nominal, raw, width, height in png_sizes:
        hot_x = max(0, min(width - 1, round(hotspot32[0] * width / 32)))
        hot_y = max(0, min(height - 1, round(hotspot32[1] * height / 32)))
        header = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nominal, 1, width, height, hot_x, hot_y, 0)
        pixels = []
        for offset in range(0, len(raw), 4):
            red, green, blue, alpha = raw[offset:offset + 4]
            pixels.append(struct.pack("<I", (alpha << 24) | (red << 16) | (green << 8) | blue))
        images.append(header + b"".join(pixels))
    count = len(images)
    position = 16 + 12 * count
    toc = b""
    chunks = b""
    for (nominal, _raw, _width, _height), chunk in zip(png_sizes, images):
        toc += struct.pack("<III", 0xFFFD0002, nominal, position)
        chunks += chunk
        position += len(chunk)
    return struct.pack("<IIII", 0x72756358, 16, 0x00010000, count) + toc + chunks


def build_hyprcursor(source, dest):
    if not shutil.which("hyprcursor-util"):
        print("hyprcursor-util is missing. The compositor pointer was not built.")
        return False
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        proc = subprocess.run(
            ["hyprcursor-util", "--create", str(source), "-o", str(out)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr[-400:])
            print("hyprcursor-util failed. The compositor pointer was not built.")
            return False
        built = next(out.glob("theme_*"), None)
        if built is None:
            print("hyprcursor-util wrote no theme.")
            return False
        target = dest / "hyprcursors"
        target.mkdir(parents=True, exist_ok=True)
        for theme_file in built.iterdir():
            if theme_file.name == "hyprcursors":
                for cursor in theme_file.iterdir():
                    shutil.copy2(cursor, target / cursor.name)
            else:
                shutil.copy2(theme_file, dest / theme_file.name)
    return True


def build_xcursor(source, dest):
    if not shutil.which("magick"):
        print("magick is missing. The Xcursor fallback was not built.")
        return False
    cursors = dest / "cursors"
    cursors.mkdir(parents=True, exist_ok=True)
    for shape in sorted((source / "hyprcursors").iterdir()):
        meta = (shape / "meta.hl").read_text()
        hot_x = float(re.search(r"hotspot_x = ([0-9.]+)", meta).group(1)) * 32
        hot_y = float(re.search(r"hotspot_y = ([0-9.]+)", meta).group(1)) * 32
        names = [shape.name] + re.findall(r"define_override = (\S+)", meta)
        sizes = []
        for size in (24, 32, 48):
            raw = subprocess.check_output(
                [
                    "magick",
                    "-background",
                    "none",
                    str(shape / "cursor.svg"),
                    "-resize",
                    f"{size}x{size}",
                    "-depth",
                    "8",
                    "rgba:-",
                ]
            )
            if len(raw) != size * size * 4:
                raise RuntimeError(f"bad cursor image for {shape.name} at {size}")
            sizes.append((size, raw, size, size))
        blob = pack_xcursor(sizes, (hot_x, hot_y))
        for name in names:
            (cursors / name).write_bytes(blob)
    shutil.copy2(source / "index.theme", dest / "index.theme")
    return True


def main():
    if len(sys.argv) != 3:
        print("usage: build.py SOURCE DEST", file=sys.stderr)
        return 2
    source = Path(sys.argv[1]).resolve()
    dest = Path(sys.argv[2]).resolve()
    dest.mkdir(parents=True, exist_ok=True)
    hypr = build_hyprcursor(source, dest)
    xcursor = build_xcursor(source, dest)
    if not hypr and not xcursor:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
