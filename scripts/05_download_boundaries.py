"""Fetch provenance-rich geoBoundaries gbOpen data; Python standard library only.

First run: python scripts/05_download_boundaries.py boundaries countries
Then select intersecting countries with 06_prepare_boundaries.R select.
Second run: python scripts/05_download_boundaries.py boundaries adm1
The API metadata and exact source files are retained with SHA256. No GADM data.
"""
import concurrent.futures
import csv
import hashlib
import json
import pathlib
import sys
import time
import urllib.request

BASE = "https://www.geoboundaries.org/api/current/gbOpen"
if len(sys.argv) != 3:
    raise SystemExit("Usage: python scripts/05_download_boundaries.py boundaries countries|adm1")
ROOT = pathlib.Path(sys.argv[1]).resolve()
MODE = sys.argv[2]
ROOT.mkdir(parents=True, exist_ok=True)
RAW = ROOT / "raw"
RAW.mkdir(exist_ok=True)
prior = ROOT / f"manifest_{MODE}.csv"
if prior.exists():
    with prior.open(encoding="utf-8", newline="") as stream:
        for row in csv.DictReader(stream):
            for path_key, hash_key in (("path", "sha256"), ("metadata_path", "metadata_sha256")):
                path = ROOT / row[path_key]
                if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() != row[hash_key]:
                    raise SystemExit(f"Cached file differs from previous manifest: {path}")


def get(url, dest):
    if dest.exists():
        data = dest.read_bytes()
        json.loads(data)
        return data
    error = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TNC-MoFuSS-v1-reproducibility/1.0"})
            with urllib.request.urlopen(req, timeout=90) as response:
                data = response.read()
            json.loads(data)
            part = dest.with_suffix(dest.suffix + ".part")
            part.write_bytes(data)
            part.replace(dest)
            return data
        except Exception as exc:
            error = exc
            if attempt < 3:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"Could not fetch {url}: {error}")


def source_url(url):
    # github.com/raw URLs can return LFS pointer text. media.githubusercontent
    # resolves exactly the commit and path supplied by the provider API.
    if url.startswith("https://github.com/") and "/raw/" in url:
        prefix, suffix = url.split("/raw/", 1)
        owner_repo = prefix.removeprefix("https://github.com/")
        return f"https://media.githubusercontent.com/media/{owner_repo}/{suffix}"
    return url


def fetch_country(meta, level, simplified=False):
    iso = meta["boundaryISO"]
    d = RAW / f"{iso}_{level}"
    d.mkdir(exist_ok=True)
    (d / "metadata.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    field = "simplifiedGeometryGeoJSON" if simplified else "gjDownloadURL"
    url = source_url(meta[field])
    p = d / ("boundary_simplified.geojson" if simplified else "boundary.geojson")
    data = get(url, p)
    decoded = json.loads(data)
    if decoded.get("type") != "FeatureCollection" or not decoded.get("features"):
        raise RuntimeError(f"Invalid boundary data: {iso} {level}")
    print(f"Verified {iso} {level}: {len(data):,} bytes", flush=True)
    return {"iso": iso, "level": level, "country": meta["boundaryName"],
            "boundary_id": meta["boundaryID"], "source": meta["boundarySource"],
            "upstream_license": meta["boundaryLicense"], "license_url": meta["licenseSource"],
            "provider_url": meta[field], "download_url": url,
            "geometry_variant": "simplified_country_selection_only" if simplified else "full_resolution",
            "path": p.relative_to(ROOT).as_posix(), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "metadata_path": (d / "metadata.json").relative_to(ROOT).as_posix(),
            "metadata_sha256": hashlib.sha256((d / "metadata.json").read_bytes()).hexdigest()}


if MODE == "countries":
    entries = json.loads(get(f"{BASE}/ALL/ADM0/", ROOT / "api_all_adm0.json"))
    selected = [m for m in entries if m["Continent"].strip().lower() == "africa"]
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        rows = list(pool.map(lambda m: fetch_country(m, "ADM0", True), selected))
elif MODE == "adm1":
    countries = json.loads((ROOT / "selected_countries.json").read_text(encoding="utf-8"))
    iso_codes = sorted(set(iso for region in countries.values() for iso in region))
    def run(iso):
        meta = json.loads(get(f"{BASE}/{iso}/ADM1/", ROOT / f"api_{iso}_adm1.json"))
        if meta.get("boundaryISO") != iso or meta.get("boundaryType") != "ADM1":
            raise RuntimeError(f"Unexpected metadata: {iso}")
        return fetch_country(meta, "ADM1")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(run, iso_codes))
else:
    raise SystemExit("Mode must be countries or adm1")

rows.sort(key=lambda r: (r["iso"], r["level"]))
with (ROOT / f"manifest_{MODE}.csv").open("w", newline="", encoding="utf-8") as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
print(f"Complete: {len(rows)} verified files", flush=True)
