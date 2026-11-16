#!/usr/bin/env python3 -I
"""Install only the single-threaded Web export templates for Godot 4.7.2.

The full templates pack is ~1.3 GB; this reads just the Web members of the .tpz via HTTP range
requests. Usage: tools/install_web_templates.py
"""
import io, os, sys, urllib.request, zipfile

VERSION = "4.7.2.stable"
URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
WANT = ["templates/web_nothreads_release.zip", "templates/web_nothreads_debug.zip", "templates/version.txt"]
DEST = os.path.expanduser("~/.local/share/godot/export_templates/" + VERSION)


class RangeFile(io.RawIOBase):
    def __init__(self, url):
        req = urllib.request.Request(url, method="HEAD")
        self.url = urllib.request.urlopen(req).geturl()  # resolve redirect once
        self.size = int(urllib.request.urlopen(urllib.request.Request(self.url, method="HEAD")).headers["Content-Length"])
        self.pos = 0

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos

    def read(self, n=-1):
        if n < 0 or self.pos + n > self.size:
            n = self.size - self.pos
        if n <= 0:
            return b""
        req = urllib.request.Request(self.url, headers={"Range": "bytes=%d-%d" % (self.pos, self.pos + n - 1)})
        data = urllib.request.urlopen(req).read()
        self.pos += len(data)
        return data

    def readinto(self, b):
        d = self.read(len(b))
        b[:len(d)] = d
        return len(d)


def main():
    os.makedirs(DEST, exist_ok=True)
    z = zipfile.ZipFile(io.BufferedReader(RangeFile(URL), buffer_size=1 << 20))
    for name in WANT:
        data = z.read(name)
        out = os.path.join(DEST, os.path.basename(name))
        with open(out, "wb") as f:
            f.write(data)
        print("installed", out, len(data), "bytes")


if __name__ == "__main__":
    sys.exit(main())
