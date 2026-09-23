"""Create a checked, allowlisted release archive; never includes scratch or credentials."""
import argparse, hashlib, json, zipfile
from pathlib import Path

def sha256(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()

def payload(root):
    allowed={'code','data','results','boundaries','ecoregions','climate','social','audit'}
    excluded={'.git','__pycache__','.r-library','.package-cache','scratch','extracted','processed_reproduced'}
    for p in sorted(root.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(root)
        if rel.parts[0] not in allowed and rel.as_posix() not in {'START_HERE.md','DATA_LICENSE.md','THIRD_PARTY_NOTICES.md'}:continue
        if any(x in excluded for x in rel.parts) or p.suffix in {'.pyc','.part'}:continue
        if any('PRIVATE' in x or x.startswith('processed_acceptance') for x in rel.parts):continue
        yield p,rel.as_posix()

def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('root',type=Path);a.add_argument('archive',type=Path)
    a.add_argument('--version',default='1.0.0');args=a.parse_args()
    root=args.root.resolve();archive=args.archive.resolve()
    if archive.exists():raise SystemExit('Archive exists; refusing to overwrite')
    if archive.is_relative_to(root):raise SystemExit('Archive must be outside the payload root')
    files=list(payload(root))
    if not files:raise SystemExit('Empty payload')
    manifest={'version':args.version,'checksum':'SHA256','files':[{'path':r,'bytes':p.stat().st_size,'sha256':sha256(p)} for p,r in files]}
    manifest_path=root/'release_manifest.json'
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    files.append((manifest_path,'release_manifest.json'))
    prefix='restoration-priority-tool-v'+args.version+'/'
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=2,allowZip64=True) as z:
        for p,rel in files:z.write(p,prefix+rel)
    with zipfile.ZipFile(archive) as z:
        bad=z.testzip()
        if bad:raise RuntimeError('Archive CRC check failed: '+bad)
    receipt={'archive':archive.name,'version':args.version,'bytes':archive.stat().st_size,'sha256':sha256(archive),'payload_files':len(files),'zip_crc':'PASS'}
    archive.with_suffix('.sha256.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt))

if __name__=='__main__':main()
