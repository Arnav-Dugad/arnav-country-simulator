#!/usr/bin/env python3
"""Downloads Lucide icons (ISC) into assets/icons, recoloured white at our stroke
width, with DPITexture import settings like the existing icons.

    python tools/fetch_icons.py name [name ...]
"""
import os
import sys
import urllib.request

VERSION = "0.469.0"
HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(os.path.dirname(HERE), "assets", "icons")
IMPORT = """[remap]

importer="svg"
type="DPITexture"

[deps]

source_file="res://assets/icons/{name}.svg"

[params]

base_scale=1.0
saturation=1.0
color_map={{}}
fix_alpha_border=false
premult_alpha=false
compress=true
"""


def fetch(name):
    path = os.path.join(DEST, name + ".svg")
    if os.path.exists(path):
        return "exists"
    url = f"https://unpkg.com/lucide-static@{VERSION}/icons/{name}.svg"
    req = urllib.request.Request(url, headers={"User-Agent": "acs-build-tools"})
    with urllib.request.urlopen(req, timeout=60) as r:
        svg = r.read().decode("utf-8")
    svg = svg.replace('stroke="currentColor"', 'stroke="#FFFFFF"').replace('stroke-width="2"', 'stroke-width="1.75"')
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)
    imp = path + ".import"
    if not os.path.exists(imp):
        with open(imp, "w", encoding="utf-8", newline="\n") as f:
            f.write(IMPORT.format(name=name))
    return "ok"


if __name__ == "__main__":
    for n in sys.argv[1:]:
        try:
            print(n, fetch(n))
        except Exception as e:  # noqa: BLE001
            print(n, "FAILED", e)
