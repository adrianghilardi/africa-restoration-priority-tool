"""Download the provider's CC BY 4.0 RESOLVE 2017 archive without overwriting."""
from pathlib import Path
from urllib.request import urlopen, Request
from datetime import datetime, timezone
import hashlib
import json
import shutil
import zipfile
import argparse
import zlib

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('storage',type=Path)
ROOT = parser.parse_args().storage.resolve()
URL = "https://storage.googleapis.com/teow2016/Ecoregions2017.zip"
DEST = ROOT / "raw" / "Ecoregions2017.zip"
DEST.parent.mkdir(parents=True, exist_ok=True)
if DEST.exists():
    manifest=json.loads((ROOT/'source_manifest.json').read_text(encoding='utf-8'))
    checksum=hashlib.sha256()
    with DEST.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):checksum.update(block)
    actual=checksum.hexdigest()
    if actual!=manifest['sha256']:
        raise SystemExit('Cached archive checksum mismatch')
    extract=ROOT/'raw/extracted'
    if not extract.exists():
        with zipfile.ZipFile(DEST) as archive:
            if archive.testzip() is not None:raise SystemExit('Archive CRC check failed')
            for member in archive.infolist():
                if not (extract/member.filename).resolve().is_relative_to(extract.resolve()):
                    raise SystemExit('Unsafe archive member path')
            archive.extractall(extract)
    with zipfile.ZipFile(DEST) as archive:
        for member in archive.infolist():
            if member.is_dir():continue
            candidate=(extract/member.filename).resolve()
            if not candidate.is_relative_to(extract.resolve()):raise SystemExit('Unsafe archive member path')
            if not candidate.is_file() or candidate.stat().st_size!=member.file_size:
                raise SystemExit('Cached extraction is incomplete: '+member.filename)
            crc=0
            with candidate.open('rb') as stream:
                for block in iter(lambda:stream.read(1024*1024),b''):crc=zlib.crc32(block,crc)
            if crc!=member.CRC:raise SystemExit('Cached extraction differs from archive: '+member.filename)
    print('Verified cached archive and all extracted member CRCs')
    raise SystemExit(0)
part = DEST.with_suffix(".zip.part")
if part.exists():
    raise SystemExit("Partial download exists; inspect before retry")
with urlopen(Request(URL, headers={"User-Agent": "RestorationPriorityTool/1.0.0"}), timeout=180) as response:
    headers = dict(response.headers)
    with part.open("xb") as target:
        shutil.copyfileobj(response, target, 1024 * 1024)
    expected = response.headers.get("Content-Length")
if expected is not None and part.stat().st_size != int(expected):
    raise RuntimeError("Download size mismatch")
with zipfile.ZipFile(part) as archive:
    corrupt = archive.testzip()
    if corrupt:
        raise RuntimeError(f"Corrupt archive member: {corrupt}")
    extract = ROOT / "raw" / "extracted"
    if extract.exists():
        raise RuntimeError("Extraction directory already exists")
    for member in archive.infolist():
        candidate = (extract / member.filename).resolve()
        if not candidate.is_relative_to(extract.resolve()):
            raise RuntimeError("Unsafe archive member path")
    archive.extractall(extract)
part.rename(DEST)
sha = hashlib.sha256()
with DEST.open("rb") as stream:
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        sha.update(block)
manifest = {
    "dataset": "RESOLVE Ecoregions 2017",
    "provider": "RESOLVE Biodiversity and Wildlife Solutions",
    "source_url": URL,
    "provider_page": "https://ecoregions.appspot.com/",
    "license": "CC-BY-4.0",
    "license_url": "https://creativecommons.org/licenses/by/4.0/",
    "citation": "Dinerstein et al. (2017), An Ecoregion-Based Approach to Protecting Half the Terrestrial Realm",
    "citation_doi": "10.1093/biosci/bix014",
    "downloaded_utc": datetime.now(timezone.utc).isoformat(),
    "bytes": DEST.stat().st_size,
    "sha256": sha.hexdigest(),
    "last_modified": headers.get("Last-Modified"),
    "etag": headers.get("ETag"),
    "preparation": "Fresh provider archive; no GADM-derived geometries or legacy analytical attributes used.",
}
(ROOT / "source_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(json.dumps(manifest, indent=2))
