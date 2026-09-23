"""Download the exact public CCKP climate selections; Python standard library only.

Usage: python scripts/00_download_climate.py config/climate_portable.json
Files are verified, manifested with SHA256, and never fetched from private prefixes.
Anomalies are supplied by CCKP, not differences between ensemble percentiles.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

NS = {"s": "http://s3.amazonaws.com/doc/2006-03-01/"}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as src:
        for part in iter(lambda: src.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()


def list_objects(endpoint, prefix):
    token = None
    result = []
    while True:
        params = {"list-type": "2", "prefix": prefix, "max-keys": "1000"}
        if token:
            params["continuation-token"] = token
        with urlopen(endpoint + "/?" + urlencode(params), timeout=60) as stream:
            root = ET.fromstring(stream.read())
        for entry in root.findall("s:Contents", NS):
            result.append({
                "key": entry.findtext("s:Key", namespaces=NS),
                "bytes": int(entry.findtext("s:Size", namespaces=NS)),
                "etag": entry.findtext("s:ETag", namespaces=NS).strip('"'),
                "last_modified": entry.findtext("s:LastModified", namespaces=NS),
            })
        if root.findtext("s:IsTruncated", namespaces=NS) != "true":
            return result
        token = root.findtext("s:NextContinuationToken", namespaces=NS)
        if not token:
            raise RuntimeError("Truncated S3 listing without continuation token")


def select_entries(cfg):
    selected = []
    for variable in cfg["variables"]:
        for scenario in ["historical"] + cfg["scenarios"]:
            prefix = f'{cfg["s3_prefix"]}/{cfg["collection"]}/{variable}/ensemble-all-{scenario}/'
            objects = list_objects(cfg["s3_endpoint"], prefix)
            index = {Path(x["key"]).name: x for x in objects}
            periods = [cfg["baseline"]] if scenario == "historical" else cfg["periods"]
            percentiles = ["median"] if scenario == "historical" else cfg["percentiles"]
            product = "climatology" if scenario == "historical" else "anomaly"
            for period in periods:
                for percentile in percentiles:
                    name = (f'{product}-{variable}-annual-mean_{cfg["collection"]}_'
                            f'ensemble-all-{scenario}_climatology_{percentile}_{period}.nc')
                    if name not in index:
                        raise RuntimeError(f"Required climate file absent from public listing: {name}")
                    row = dict(index[name], variable=variable, scenario=scenario,
                               period=period, percentile=percentile, product=product,
                               url=cfg["s3_endpoint"] + "/" + index[name]["key"])
                    selected.append(row)
    return selected


def download(row, output, old):
    name = Path(row["key"]).name
    target = output / "raw" / name
    expected = old.get(name)
    if target.exists() and target.stat().st_size == row["bytes"]:
        checksum = sha256(target)
        if expected and checksum == expected["sha256"] and row["etag"] == expected["etag"]:
            return dict(row, path="raw/" + name, sha256=checksum,
                        downloaded_utc=expected["downloaded_utc"])
        raise RuntimeError(f"Existing file lacks matching provenance: {target}")
    if target.exists():
        raise RuntimeError(f"Refusing to overwrite unexpected existing file: {target}")
    part = target.with_suffix(".nc.part")
    for attempt in range(3):
        try:
            request = Request(row["url"], headers={"User-Agent": "TNC-restoration-reproducible-download/0.1"})
            with urlopen(request, timeout=60) as response, part.open("wb") as stream:
                for block in iter(lambda: response.read(1024 * 1024), b""):
                    stream.write(block)
            if part.stat().st_size != row["bytes"]:
                raise RuntimeError("Downloaded size differs from S3 listing")
            with part.open("rb") as stream:
                magic = stream.read(8)
            if not (magic.startswith(b"CDF") or magic == b"\x89HDF\r\n\x1a\n"):
                raise RuntimeError("Response is not a NetCDF/HDF file")
            # A single-part S3 ETag is checked when it has MD5 format.
            if re.fullmatch(r"[a-fA-F0-9]{32}", row["etag"]):
                h = hashlib.md5()
                with part.open("rb") as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        h.update(block)
                if h.hexdigest() != row["etag"].lower():
                    raise RuntimeError("Downloaded MD5 differs from S3 ETag")
            checksum = sha256(part)
            part.rename(target)
            return dict(row, path="raw/" + name, sha256=checksum,
                        downloaded_utc=datetime.now(timezone.utc).isoformat())
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--list-only", action="store_true")
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text(encoding="utf-8-sig"))
    rows = select_entries(cfg)
    print(f'Selected {len(rows)} files, {sum(x["bytes"] for x in rows)/1e6:.1f} MB', flush=True)
    if args.list_only:
        print(json.dumps(rows, indent=2))
        return
    output = Path(cfg["storage_dir"])
    (output / "raw").mkdir(parents=True, exist_ok=True)
    manifest = output / "download_manifest.json"
    previous = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else []
    old = {Path(x["path"]).name: x for x in previous}
    completed = {x["key"]: x for x in previous}
    (output / "download_config.json").write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    with ThreadPoolExecutor(max_workers=cfg.get("workers", 2)) as executor:
        futures = [executor.submit(download, row, output, old) for row in rows]
        for future in as_completed(futures):
            row = future.result()
            completed[row["key"]] = row
            manifest.write_text(json.dumps(sorted(completed.values(), key=lambda x: x["key"]),
                                           indent=2), encoding="utf-8")
            print(f'Verified {row["variable"]} {row["scenario"]} {row["period"]} {row["percentile"]}', flush=True)
    requested = {x["key"] for x in rows}
    if set(completed) != requested:
        raise RuntimeError("Manifest contains a different selection; use a separate output directory")
    print(f"COMPLETE: {manifest}", flush=True)


if __name__ == "__main__":
    main()
