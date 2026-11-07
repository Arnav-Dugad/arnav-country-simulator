#!/usr/bin/env python3
"""Builds data/countries.json — the real-world starting snapshot for every map entity.

Sources (open data):
  * World Bank WDI API  (population, GDP, growth, unemployment, inflation, revenue,
                         military spending, life expectancy)
  * World Bank WGI      (political stability estimate, source=3)
  * IMF DataMapper API  (general government gross debt, net lending/borrowing,
                         and fallbacks for GDP/population/growth/inflation/unemployment)
  * Natural Earth       (names, region grouping, entity type, fallback pop/GDP)

Missing values are filled with REGIONAL MEDIANS (by World Bank region) and every
filled field is listed in that country's "estimated" array, so the game can flag it.

    python tools/fetch_map.py          # once (downloads Natural Earth)
    python tools/build_country_data.py
"""
import datetime
import json
import os
import statistics
import time
import urllib.request

from fetch_map import iso3 as ne_iso3, SRC as NE_SRC

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(ROOT, "data", "countries.json")

WB = "https://api.worldbank.org/v2"
IMF = "https://www.imf.org/external/datamapper/api/v1"
MAX_YEAR = 2025  # newest year accepted (avoid IMF projections beyond this)

WB_INDICATORS = {
    "population": ("SP.POP.TOTL", None),
    "gdp": ("NY.GDP.MKTP.CD", None),
    "gdp_growth": ("NY.GDP.MKTP.KD.ZG", None),
    "unemployment": ("SL.UEM.TOTL.ZS", None),
    "inflation": ("FP.CPI.TOTL.ZG", None),
    "revenue_pct": ("GC.REV.XGRT.GD.ZS", None),
    "military_pct": ("MS.MIL.XPND.GD.ZS", None),
    "life_expectancy": ("SP.DYN.LE00.IN", None),
    "stability_wgi": ("GOV_WGI_PV.EST", 3),
    "fuel_exports_pct": ("TX.VAL.FUEL.ZS.UN", None),
    # Detail that shapes each country (filled with regional medians when missing,
    # listed in "estimated_detail" rather than "estimated").
    "health_pct": ("SH.XPD.GHED.GD.ZS", None),        # government health spending, % GDP
    "education_pct": ("SE.XPD.TOTL.GD.ZS", None),     # government education spending, % GDP
    "research_pct": ("GB.XPD.RSDV.GD.ZS", None),      # R&D spending, % GDP
    "gini": ("SI.POV.GINI", None),
    "age65_pct": ("SP.POP.65UP.TO.ZS", None),
    "urban_pct": ("SP.URB.TOTL.IN.ZS", None),
    "tourism_pct": ("ST.INT.RCPT.XP.ZS", None),        # tourism receipts, % of exports
    "manufacturing_pct": ("NV.IND.MANF.ZS", None),
    "agriculture_pct": ("NV.AGR.TOTL.ZS", None),
    "internet_pct": ("IT.NET.USER.ZS", None),
    "electricity_pct": ("EG.ELC.ACCS.ZS", None),
    "trade_pct": ("NE.TRD.GNFS.ZS", None),             # exports + imports, % GDP
    "corruption_wgi": ("GOV_WGI_CC.EST", 3),
    "voice_wgi": ("GOV_WGI_VA.EST", 3),
    "co2_pc": ("EN.GHG.CO2.PC.CE.AR5", None),          # CO2 excl. land use, tonnes per person
    "renewables_pct": ("EG.FEC.RNEW.ZS", None),        # renewables, % of final energy use
}
DETAIL_KEYS = ["health_pct", "education_pct", "research_pct", "gini", "age65_pct", "urban_pct",
               "tourism_pct", "manufacturing_pct", "agriculture_pct", "internet_pct", "electricity_pct",
               "trade_pct", "corruption_wgi", "voice_wgi", "co2_pc", "renewables_pct", "net_migration_rate"]
IMF_INDICATORS = {
    "debt_pct": "GGXWDG_NGDP",
    "budget_balance_pct": "GGXCNL_NGDP",
    "_imf_gdp_bn": "NGDPD",
    "_imf_pop_m": "LP",
    "_imf_growth": "NGDP_RPCH",
    "_imf_inflation": "PCPIPCH",
    "_imf_unemployment": "LUR",
    "_imf_revenue": "GGR_NGDP",
}
# Natural Earth code -> (World Bank code, IMF code) where they differ.
ALIASES = {"KOS": ("XKX", "UVK"), "PSX": ("PSE", "WBG"), "SDS": ("SSD", "SSD")}
PLAYABLE_TYPES = {"Sovereign country", "Country", "Disputed"}  # Disputed: e.g. Israel, Kosovo (need real data)


def fetch_json(url, cache_name):
    path = os.path.join(CACHE, cache_name)
    if os.path.exists(path) and time.time() - os.path.getmtime(path) < 7 * 86400:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    print("GET", url)
    # imf.org rejects non-browser user agents with 403.
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; acs-build-tools)",
                                               "Accept": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                data = json.loads(r.read().decode("utf-8"))
            break
        except Exception as e:  # network hiccup: back off and retry
            print("  retry", attempt + 1, e)
            time.sleep(3 * (attempt + 1))
    else:
        raise SystemExit(f"Failed to fetch {url}")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)
    return data


def wb_latest(code, source):
    """{iso3: (value, year)} — most recent non-empty value per country."""
    src = f"&source={source}" if source else ""
    date = f"&date=2015:{MAX_YEAR}"
    url = f"{WB}/country/all/indicator/{code}?format=json&per_page=20000{date}{src}"
    rows = fetch_json(url, f"wb_{code}.json")
    out = {}
    if not isinstance(rows, list) or len(rows) < 2 or rows[1] is None:
        print("  no rows for", code)
        return out
    for r in rows[1]:
        iso, v, y = r.get("countryiso3code"), r.get("value"), r.get("date")
        if not iso or v is None:
            continue
        y = int(y)
        if iso not in out or y > out[iso][1]:
            out[iso] = (float(v), y)
    return out


def wb_mean(code, y0, y1):
    """{iso3: (mean value, last year)} over y0..y1 (smooths volatile series)."""
    url = f"{WB}/country/all/indicator/{code}?format=json&per_page=20000&date={y0}:{y1}"
    rows = fetch_json(url, f"wb_{code}_{y0}_{y1}.json")
    acc = {}
    if not isinstance(rows, list) or len(rows) < 2 or rows[1] is None:
        return {}
    for r in rows[1]:
        iso, v, y = r.get("countryiso3code"), r.get("value"), r.get("date")
        if iso and v is not None:
            acc.setdefault(iso, []).append((float(v), int(y)))
    return {iso: (sum(v for v, _ in xs) / len(xs), max(y for _, y in xs)) for iso, xs in acc.items()}


def imf_latest(code):
    data = fetch_json(f"{IMF}/{code}", f"imf_{code}.json")
    out = {}
    for iso, series in (data.get("values", {}).get(code, {}) or {}).items():
        years = [int(y) for y, v in series.items() if v is not None and int(y) <= MAX_YEAR]
        if years:
            y = max(years)
            out[iso] = (float(series[str(y)]), y)
    return out


def main():
    os.makedirs(CACHE, exist_ok=True)
    with open(NE_SRC, encoding="utf-8") as f:
        ne = json.load(f)
    meta = fetch_json(f"{WB}/country?format=json&per_page=400", "wb_countries.json")[1]
    wb_region = {m["id"]: m["region"]["value"] for m in meta if m["region"]["value"] != "Aggregates"}

    wb = {k: wb_latest(code, src) for k, (code, src) in WB_INDICATORS.items()}
    imf = {k: imf_latest(code) for k, code in IMF_INDICATORS.items()}
    # Net migration (UN WPP via World Bank): 2019-2023 average, people per year.
    # Converted to a rate per 1,000 people below. Later years are projections.
    netm = wb_mean("SM.POP.NETM", 2019, 2023)

    countries = {}
    admin_to_iso = {}
    seen = set()
    for feat in ne["features"]:
        p = feat["properties"]
        code = ne_iso3(p)
        if code in seen:
            code = p.get("ADM0_A3")
        seen.add(code)
        admin_to_iso.setdefault(p.get("ADMIN"), code)
        wb_code, imf_code = ALIASES.get(code, (code, code))
        c = {
            "name": p.get("NAME"),
            "name_long": p.get("NAME_LONG") or p.get("NAME"),
            "type": p.get("TYPE"),
            "sovereign_name": p.get("SOVEREIGNT"),
            "region": wb_region.get(wb_code) or p.get("REGION_WB") or p.get("CONTINENT"),
            "subregion": p.get("SUBREGION"),
            "estimated": [],
            "estimated_detail": [],
            "years": {},
        }
        for k in WB_INDICATORS:
            if wb_code in wb[k]:
                c[k], c["years"][k] = wb[k][wb_code]
        for k in IMF_INDICATORS:
            if imf_code in imf[k]:
                c[k], y = imf[k][imf_code]
                if not k.startswith("_"):
                    c["years"][k] = y
        # IMF fallbacks for entities the World Bank does not cover (e.g. Taiwan).
        fb = {"gdp": ("_imf_gdp_bn", 1e9), "population": ("_imf_pop_m", 1e6),
              "gdp_growth": ("_imf_growth", 1), "inflation": ("_imf_inflation", 1),
              "unemployment": ("_imf_unemployment", 1), "revenue_pct": ("_imf_revenue", 1)}
        for k, (ik, mul) in fb.items():
            if k not in c and ik in c:
                c[k] = c[ik] * mul
        if wb_code in netm and c.get("population"):
            c["net_migration_rate"] = netm[wb_code][0] / c["population"] * 1000.0
            c["years"]["net_migration_rate"] = netm[wb_code][1]
        for k in list(c):
            if k.startswith("_"):
                del c[k]
        # Natural Earth fallbacks for size.
        if "population" not in c and (p.get("POP_EST") or 0) > 0:
            c["population"] = float(p["POP_EST"])
            c["estimated"].append("population")
        if "gdp" not in c and (p.get("GDP_MD") or 0) > 0:
            c["gdp"] = float(p["GDP_MD"]) * 1e6
            c["estimated"].append("gdp")
        countries[code] = c

    # Playability & sovereign links.
    for code, c in countries.items():
        has_core = "population" in c and "gdp" in c and c["population"] > 50_000
        c["playable"] = bool(c["type"] in PLAYABLE_TYPES and has_core
                             and "population" not in c["estimated"])
        sov = admin_to_iso.get(c["sovereign_name"])
        c["sovereign"] = sov if sov and sov != code else (code if c["playable"] else sov)
        # Autonomous parts of another state (Greenland, Hong Kong, Macau) are not playable.
        if c["sovereign"] not in (None, code):
            c["playable"] = False
        del c["sovereign_name"]

    # Regional medians for remaining gaps (flagged).
    fill_keys = ["gdp_growth", "unemployment", "inflation", "revenue_pct", "military_pct",
                 "life_expectancy", "stability_wgi", "debt_pct", "budget_balance_pct"]
    by_region = {}
    for c in countries.values():
        by_region.setdefault(c["region"], []).append(c)
    world_med = {k: statistics.median([c[k] for c in countries.values() if k in c]) for k in fill_keys}
    for region, members in by_region.items():
        med = {}
        for k in fill_keys:
            vals = [m[k] for m in members if k in m and k not in m["estimated"]]
            med[k] = statistics.median(vals) if len(vals) >= 3 else world_med[k]
        dmed = {}
        for k in DETAIL_KEYS:
            vals = [m[k] for m in members if k in m and k not in m["estimated_detail"]]
            allv = [c[k] for c in countries.values() if k in c]
            dmed[k] = statistics.median(vals) if len(vals) >= 3 else (statistics.median(allv) if allv else 0.0)
        for m in members:
            for k in DETAIL_KEYS:
                if k not in m:
                    m[k] = dmed[k]
                    m["estimated_detail"].append(k)
            for k in fill_keys:
                if k not in m:
                    m[k] = med[k]
                    m["estimated"].append(k)
            if "gdp" not in m and "population" in m:
                pcs = [x["gdp"] / x["population"] for x in members if "gdp" in x and x.get("population")]
                m["gdp"] = m["population"] * (statistics.median(pcs) if pcs else 5000.0)
                m["estimated"].append("gdp")

    # Rounding for a compact file.
    for c in countries.values():
        for k, v in list(c.items()):
            if isinstance(v, float):
                c[k] = round(v, 3) if abs(v) < 1e6 else round(v)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    years = [y for c in countries.values() for y in c["years"].values()]
    out = {
        "meta": {
            "generated": datetime.date.today().isoformat(),
            "snapshot": f"most recent available value per indicator, {min(years)}-{max(years)} (mostly {statistics.mode(years)})",
            "sources": ["World Bank WDI", "World Bank WGI", "IMF DataMapper (WEO)", "Natural Earth 1:50m v5.1.2"],
        },
        "countries": countries,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=None, separators=(",", ":"), ensure_ascii=False)
    playable = sum(1 for c in countries.values() if c["playable"])
    est = sum(1 for c in countries.values() if c["playable"] and c["estimated"])
    print(f"Wrote {OUT}: {len(countries)} entities, {playable} playable, {est} playable with estimated fields")
    print("Snapshot:", out["meta"]["snapshot"])


if __name__ == "__main__":
    main()
