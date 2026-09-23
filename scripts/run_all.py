"""Portable orchestration, Python standard library only. No shell interpolation.

Default: tests + frozen-input restoration/climate/social reruns + validation.
No raw-global input preparation or Internet refresh occurs in the default run.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def cli(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rscript",default="Rscript",help="Rscript executable; quote a Windows path containing spaces")
    parser.add_argument("--r-library",type=Path,help="Optional additional R library; defaults to code/.r-library")
    parser.add_argument("--restoration-config",default="config/portable.json")
    parser.add_argument("--climate-config",default="config/climate_portable.json")
    parser.add_argument("--social-config",default="config/social.json")
    parser.add_argument("--tests-only",action="store_true",help="No datasets or network needed")
    parser.add_argument("--dry-run",action="store_true",help="Print commands without executing or writing")
    parser.add_argument("--install-deps",action="store_true",help="First install exact pinned R packages into the selected local library")
    parser.add_argument("--allow-r-version-difference",action="store_true",help="Explicitly accept an R version other than reference 4.6.0; package pins still enforced")
    parser.add_argument("--compare-reference",action="store_true",help="Additionally compare reruns against bundled reference results; same-platform exact comparison")
    parser.add_argument("--report",default="../audit/run_all_report.json",help="JSON execution evidence (never written for --dry-run)")
    return parser.parse_args(argv)


def resolve(root,path):
    p=Path(path)
    return p.resolve() if p.is_absolute() else (root/p).resolve()


def load_config(root,path):
    p=resolve(root,path)
    with p.open(encoding="utf-8-sig") as stream:return p,json.load(stream)


def build_plan(args,root):
    r=[args.rscript]
    py=[sys.executable]
    library=resolve(root,args.r_library or ".r-library")
    dep=["scripts/install_dependencies.R","--library",str(library)]
    if args.allow_r_version_difference:dep.append("--allow-r-version-difference")
    plan=[]
    if args.install_deps:plan.append(("install_dependencies",r+dep))
    plan.append(("check_dependencies",r+dep+["--check"]))
    for script in ["test_core.R","test_spatial.R","test_social.R","test_social_spatial.R","test_reproduction_comparison.R"]:
        plan.append((script,r+["tests/"+script]))
    plan.append(("python_unit_tests",py+["-m","unittest","discover","-s","tests","-p","test_*.py"]))
    output_paths=[]
    if not args.tests_only:
        rc,restoration=load_config(root,args.restoration_config)
        cc,climate=load_config(root,args.climate_config)
        sc,social=load_config(root,args.social_config)
        rout=resolve(root,restoration["output_dir"])
        cout=resolve(root,Path(climate["storage_dir"])/climate.get("processed_subdir","processed"))
        sout=resolve(root,Path(social["storage_dir"])/social.get("processed_subdir","processed"))
        output_paths=[rout,cout,sout]
        if len(set(output_paths))!=3:raise ValueError("Module output directories must be distinct")
        for directory in output_paths:
            if directory.exists():raise FileExistsError(f"Refusing to overwrite existing output: {directory}. Choose a new output path in its config.")
        needed=[resolve(root,Path(restoration["data_dir"])/"manifest_sha256.csv"),
                resolve(root,Path(climate["storage_dir"])/"download_manifest.json"),
                resolve(root,Path(social["storage_dir"])/"download_manifest.json"),
                resolve(root,climate["tnc_zones"]),resolve(root,social["tnc_zones"])]
        for p in needed:
            if not p.is_file():raise FileNotFoundError(f"Missing bundled input: {p}. Extract the Zenodo data beside code/ first.")
        plan.extend([
            ("restoration",r+["scripts/02_analyze.R",str(rc)]),
            ("restoration_validation",r+["scripts/04_validate_results.R",str(rc)]),
            ("climate",r+["scripts/03_prepare_climate.R",str(cc)]),
            ("social",r+["scripts/06_prepare_social.R",str(sc)]),
            ("social_validation",py+["tests/check_social_outputs.py",str(sout)])])
        if args.compare_reference:
            plan.extend([
                ("compare_restoration",r+["tests/compare_restoration.R",str(resolve(root,"../results")),str(rout)]),
                ("compare_climate",r+["tests/compare_climate.R",str(resolve(root,Path(climate["storage_dir"])/"processed")),str(cout)]),
                ("compare_social",py+["tests/check_social_outputs.py",str(sout),str(resolve(root,Path(social["storage_dir"])/"processed"))])])
    return plan,library,output_paths


def main(argv=None,root=None):
    args=cli(argv)
    root=Path(root) if root else Path(__file__).resolve().parents[1]
    if sys.version_info<(3,10):raise RuntimeError("Python 3.10 or newer is required")
    plan,library,outputs=build_plan(args,root)
    if args.dry_run:
        for name,cmd in plan:print(json.dumps({"step":name,"argv":cmd}))
        return 0
    if not (Path(args.rscript).is_file() or shutil.which(args.rscript)):
        raise FileNotFoundError("Rscript not found; use --rscript with its full executable path")
    env=os.environ.copy()
    extra=str(library)
    if env.get("R_LIBS"):extra+=os.pathsep+env["R_LIBS"]
    env["R_LIBS"]=extra
    report={"started_utc":datetime.now(timezone.utc).isoformat(),"python":sys.version,
            "rscript":args.rscript,"r_library":str(library),"tests_only":args.tests_only,
            "outputs":[str(p) for p in outputs],"steps":[],"status":"running"}
    report_path=resolve(root,args.report)
    report_path.parent.mkdir(parents=True,exist_ok=True)
    try:
        for name,cmd in plan:
            print("\nRunning "+name,flush=True)
            step={"name":name,"argv":cmd,"started_utc":datetime.now(timezone.utc).isoformat()}
            report["steps"].append(step)
            completed=subprocess.run(cmd,cwd=root,env=env,check=False)
            step["returncode"]=completed.returncode
            step["finished_utc"]=datetime.now(timezone.utc).isoformat()
            if completed.returncode:raise RuntimeError(f"Step {name} failed with exit code {completed.returncode}")
        report["status"]="passed"
    except Exception as exc:
        report["status"]="failed";report["error"]=str(exc)
        raise
    finally:
        report["finished_utc"]=datetime.now(timezone.utc).isoformat()
        report_path.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("Complete: "+str(report_path),flush=True)
    return 0


if __name__=="__main__":
    try:sys.exit(main())
    except Exception as exc:
        print("ERROR: "+str(exc),file=sys.stderr);sys.exit(1)
