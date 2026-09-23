"""Verify every archived payload file against its release SHA256 manifest."""
import argparse,hashlib,json
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path,help='Extracted release root containing release_manifest.json')
    args=parser.parse_args();root=args.root.resolve()
    manifest=json.loads((root/'release_manifest.json').read_text(encoding='utf-8'))
    seen=set()
    for entry in manifest['files']:
        p=(root/entry['path']).resolve()
        if not p.is_relative_to(root) or p in seen:raise SystemExit('Unsafe or duplicated manifest path')
        seen.add(p)
        if not p.is_file() or p.stat().st_size!=entry['bytes']:raise SystemExit('Missing/size mismatch: '+entry['path'])
        h=hashlib.sha256()
        with p.open('rb') as f:
            for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
        if h.hexdigest()!=entry['sha256']:raise SystemExit('Checksum mismatch: '+entry['path'])
    print('PASS:',len(seen),'payload files verified for release',manifest['version'])

if __name__=='__main__':main()
