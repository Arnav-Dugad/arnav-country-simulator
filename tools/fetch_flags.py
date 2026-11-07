#!/usr/bin/env python3
"""Downloads country flags (flag-icons 7.6.0, MIT) for every entity on our map.

    python tools/fetch_flags.py

Writes assets/flags/<iso2>.svg (4:3) plus LICENSE.txt. Godot imports them as DPITexture.
"""
import json, os, urllib.request, concurrent.futures as cf

VERSION = "7.6.0"
BASE = f"https://unpkg.com/flag-icons@{VERSION}"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "flags")
IMPORT = '[remap]\n\nimporter="svg"\ntype="DPITexture"\n'


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "acs-build-tools"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(ROOT, "tools", ".cache", "map_projected.json"), encoding="utf-8") as f:
        codes = sorted({(c.get("iso2") or "").lower() for c in json.load(f)["countries"]} - {"", "-99"})
    def fetch(code):
        dst = os.path.join(OUT, code + ".svg")
        if os.path.exists(dst):
            return code, "cached"
        try:
            data = get(f"{BASE}/flags/4x3/{code}.svg")
        except Exception as e:  # some NE codes have no flag (e.g. disputed areas)
            return code, f"missing ({e})"
        open(dst, "wb").write(data)
        imp = dst + ".import"
        if not os.path.exists(imp):
            open(imp, "w").write(IMPORT)
        return code, "ok"
    with cf.ThreadPoolExecutor(8) as ex:
        results = list(ex.map(fetch, codes))
    open(os.path.join(OUT, "LICENSE.txt"), "wb").write(get(f"{BASE}/LICENSE"))
    missing = [c for c, s in results if s.startswith("missing")]
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".svg"))
    print(f"{len(results) - len(missing)} flags, {total / 1024:.0f} KB; missing: {missing}")


if __name__ == "__main__":
    main()
