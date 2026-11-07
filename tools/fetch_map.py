#!/usr/bin/env python3
"""Step 1 of the map pipeline.

Downloads Natural Earth 1:50m Admin-0 countries (public domain), projects every
outer ring with the Equal Earth projection, finds land neighbours, and writes
tools/.cache/map_projected.json for the Godot baker (tools/bake_map.gd).

    python tools/fetch_map.py
    godot --headless --path . --script res://tools/bake_map.gd

Only the Python standard library is used.
"""
import json
import math
import os
import urllib.request

NE_TAG = "v5.1.2"
URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
       f"{NE_TAG}/geojson/ne_50m_admin_0_countries.geojson")
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
SRC = os.path.join(CACHE, "ne_50m_admin_0_countries.geojson")
OUT = os.path.join(CACHE, "map_projected.json")

# Projected units per radian. World spans roughly x ±2706, y ±1317.
SCALE = 1000.0

# Equal Earth constants (Šavrič, Patterson & Jenny, 2018).
A1, A2, A3, A4 = 1.340264, -0.081106, 0.000893, 0.003796
M = math.sqrt(3.0) / 2.0


def equal_earth(lon_deg, lat_deg):
    lam = math.radians(lon_deg)
    phi = math.radians(max(-89.999, min(89.999, lat_deg)))
    th = math.asin(M * math.sin(phi))
    t2 = th * th
    t6 = t2 * t2 * t2
    x = lam * math.cos(th) / (M * (A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)))
    y = th * (A1 + A2 * t2 + t6 * (A3 + A4 * t2))
    return x * SCALE, -y * SCALE  # screen y grows downwards


def iso3(p):
    for k in ("ISO_A3_EH", "ISO_A3", "ADM0_A3"):
        v = p.get(k)
        if v and v != "-99":
            return v
    return p.get("ADM0_A3")


def main():
    os.makedirs(CACHE, exist_ok=True)
    open(os.path.join(CACHE, ".gdignore"), "a").close()  # keep Godot from importing raw data
    if not os.path.exists(SRC):
        print("Downloading", URL)
        req = urllib.request.Request(URL, headers={"User-Agent": "acs-build-tools"})
        with urllib.request.urlopen(req) as r, open(SRC, "wb") as f:
            f.write(r.read())
    with open(SRC, encoding="utf-8") as f:
        gj = json.load(f)

    countries = []
    vertex_owner = {}  # rounded lon/lat -> set of country indices (for adjacency)
    seen = set()
    for feat in gj["features"]:
        p = feat["properties"]
        code = iso3(p)
        if code in seen:  # a few dependencies share codes; keep the first
            code = p.get("ADM0_A3")
        seen.add(code)
        g = feat["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        idx = len(countries)
        rings = []
        for poly in polys:
            outer = poly[0]  # holes are dropped; enclaves draw on top (area-sorted)
            flat = []
            for lon, lat in outer[:-1]:
                x, y = equal_earth(lon, lat)
                flat += [round(x, 2), round(y, 2)]
                vertex_owner.setdefault((round(lon, 4), round(lat, 4)), set()).add(idx)
            if len(flat) >= 6:
                rings.append(flat)
            for hole in poly[1:]:  # holes still count for adjacency (e.g. Lesotho)
                for lon, lat in hole:
                    vertex_owner.setdefault((round(lon, 4), round(lat, 4)), set()).add(idx)
        lx, ly = equal_earth(p.get("LABEL_X") or 0, p.get("LABEL_Y") or 0)
        countries.append({
            "iso3": code,
            "iso2": p.get("ISO_A2_EH") if p.get("ISO_A2_EH") not in (None, "-99") else p.get("ISO_A2"),
            "name": p.get("NAME"),
            "name_long": p.get("NAME_LONG") or p.get("NAME"),
            "continent": p.get("CONTINENT"),
            "subregion": p.get("SUBREGION"),
            "region_wb": p.get("REGION_WB"),
            "sovereign": p.get("SOV_A3"),
            "type": p.get("TYPE"),
            "label": [round(lx, 2), round(ly, 2)],
            "label_rank": int(p.get("LABELRANK") or 9),
            "pop_est": float(p.get("POP_EST") or 0),
            "gdp_md": float(p.get("GDP_MD") or 0),
            "rings": rings,
        })

    neighbours = [set() for _ in countries]
    for owners in vertex_owner.values():
        if len(owners) > 1:
            for a in owners:
                neighbours[a] |= owners - {a}
    for c, n in zip(countries, neighbours):
        c["neighbours"] = sorted(countries[i]["iso3"] for i in n)

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"scale": SCALE, "source": f"Natural Earth 1:50m admin-0 {NE_TAG}",
                   "countries": countries}, f, separators=(",", ":"))
    pts = sum(len(r) // 2 for c in countries for r in c["rings"])
    print(f"Wrote {OUT}: {len(countries)} countries, {pts} points")


if __name__ == "__main__":
    main()
