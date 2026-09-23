"""Fetch public scenario population, observed national poverty, and country boundaries.

Python standard library only. Frozen manifest reuse is offline and checksum checked.
To refresh observations use a NEW storage_dir; snapshots are never overwritten.
"""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

ENDPOINT = "https://wbg-cckp.s3.amazonaws.com"
NS = {"s": "http://s3.amazonaws.com/doc/2006-03-01/"}


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fetch(url):
    for attempt in range(3):
        try:
            with urlopen(Request(url, headers={"User-Agent": "TNC-restoration-social/1.0"}), timeout=90) as response:
                return response.read()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def most_recent(rows, countries, cutoff):
    """Preserve unavailable values, reject invalid percentages and ambiguous duplicates."""
    selected = []
    for iso in countries:
        valid = [r for r in rows if r["countryiso3code"] == iso and r["value"] is not None
                 and 2000 <= int(r["date"]) <= cutoff]
        if not valid:
            selected.append(dict(iso3=iso, country=iso, observation_year=None, poverty_pct=None,
                                 indicator="SI.POV.DDAY", status="no_observation_since_2000"))
            continue
        year = max(int(r["date"]) for r in valid)
        latest = [r for r in valid if int(r["date"]) == year]
        if len(latest) != 1:
            raise ValueError("Ambiguous latest poverty observation: " + iso)
        row = latest[0]
        if not 0 <= row["value"] <= 100:
            raise ValueError("Invalid poverty percentage: " + iso)
        if "$3.00" not in row["indicator"]["value"] or "2021 PPP" not in row["indicator"]["value"]:
            raise ValueError("World Bank indicator definition changed; review the poverty threshold")
        selected.append(dict(iso3=iso, country=row["country"]["value"], observation_year=year,
                             poverty_pct=row["value"], indicator="SI.POV.DDAY", status="national_observation"))
    return selected


def run(cfg):
    output = Path(cfg["storage_dir"])
    output.mkdir(parents=True, exist_ok=True)
    raw = output / "raw"
    raw.mkdir(exist_ok=True)
    manifest_path = output / "download_manifest.json"
    selection = {key: cfg[key] for key in ("periods", "scenarios", "poverty_cutoff_year", "poverty_country_codes")}
    selection_path = output / "download_selection.json"
    if manifest_path.exists():
        if json.loads(selection_path.read_text()) != selection:
            raise RuntimeError("Selection changed; use a NEW storage directory")
        for row in json.loads(manifest_path.read_text()):
            path = output / row["path"]
            if not path.is_file() or checksum(path) != row["sha256"]:
                raise RuntimeError("Frozen input checksum failure: " + str(path))
        print("Frozen social inputs verified; no network refresh", flush=True)
        return
    if any(raw.iterdir()):
        raise RuntimeError("Incomplete/unmanifested download directory; use a fresh storage_dir")
    specs = []
    for scenario in cfg["scenarios"]:
        prefix = f"data/pop-x0.25/popdensity/gpw-v4-rev11-{scenario}/"
        xml = ET.fromstring(fetch(ENDPOINT + "/?" + urlencode({"list-type":"2", "prefix":prefix})))
        if xml.findtext("s:IsTruncated", namespaces=NS) == "true":
            raise RuntimeError("Unexpected paginated listing; refine population prefix")
        entries = {Path(e.findtext("s:Key", namespaces=NS)).name: e for e in xml.findall("s:Contents", NS)}
        for period in cfg["periods"]:
            name = f"climatology-popdensity-annual-mean_pop-x0.25_gpw-v4-rev11-{scenario}_climatology_mean_{period}.nc"
            entry = entries[name]
            specs.append(dict(path="raw/" + name, url=ENDPOINT + "/" + entry.findtext("s:Key", namespaces=NS),
                              bytes=int(entry.findtext("s:Size", namespaces=NS)),
                              etag=entry.findtext("s:ETag", namespaces=NS).strip('"'),
                              kind="population", scenario=scenario, period=period, license="CC-BY-4.0; SEDAC attribution"))
    countries = ";".join(cfg["poverty_country_codes"])
    specs.append(dict(path="raw/wdi_poverty_observations.json", kind="poverty", license="CC-BY-4.0",
                      url=f"https://api.worldbank.org/v2/country/{countries}/indicator/SI.POV.DDAY?format=json&per_page=2000&date=2000:{cfg['poverty_cutoff_year']}"))
    specs.append(dict(path="raw/ne_50m_admin_0_countries.zip", kind="countries", license="public-domain",
                      url="https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip"))
    manifest = []
    for spec in specs:
        data = fetch(spec["url"])
        if "bytes" in spec and len(data) != spec["bytes"]:
            raise RuntimeError("Population source size mismatch")
        if "etag" in spec and len(spec["etag"]) == 32 and hashlib.md5(data).hexdigest() != spec["etag"]:
            raise RuntimeError("Population source ETag mismatch")
        if spec["kind"] == "population" and not (data.startswith(b"CDF") or data.startswith(b"\x89HDF")):
            raise RuntimeError("Population response is not NetCDF")
        path = output / spec["path"]
        path.write_bytes(data)
        manifest.append(dict(spec, bytes=len(data), sha256=checksum(path), downloaded_utc=datetime.now(timezone.utc).isoformat()))
        print("Verified " + spec["path"], flush=True)
    observations = json.loads((raw / "wdi_poverty_observations.json").read_text())
    if not isinstance(observations, list) or len(observations) != 2 or int(observations[0]["pages"]) != 1:
        raise RuntimeError("Unexpected World Bank API response or pagination")
    latest = most_recent(observations[1], cfg["poverty_country_codes"], cfg["poverty_cutoff_year"])
    csvpath = output / "national_poverty_latest.csv"
    with csvpath.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=latest[0].keys())
        writer.writeheader()
        writer.writerows(latest)
    manifest.append(dict(path=csvpath.name, kind="derived_poverty_table", bytes=csvpath.stat().st_size,
                         sha256=checksum(csvpath), license="CC-BY-4.0", source="raw/wdi_poverty_observations.json"))
    selection_path.write_text(json.dumps(selection, indent=2))
    manifest_path.write_text(json.dumps(manifest, indent=2))
    print("COMPLETE: " + str(manifest_path), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    run(json.loads(args.config.read_text(encoding="utf-8-sig")))
