import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location("runner",Path(__file__).resolve().parents[1]/"scripts/run_all.py")
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def test_spaced_windows_executable_is_one_argument(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            args=runner.cli(["--tests-only","--rscript",r"C:\Program Files\R\R-4.6.0\bin\Rscript.exe"])
            plan,_,_=runner.build_plan(args,root)
            self.assertEqual(plan[0][1][0],r"C:\Program Files\R\R-4.6.0\bin\Rscript.exe")
            self.assertEqual(plan[0][1][1],"scripts/install_dependencies.R")
    def test_tests_only_does_not_require_datasets(self):
        with tempfile.TemporaryDirectory() as temp:
            plan,_,outputs=runner.build_plan(runner.cli(["--tests-only"]),Path(temp))
            self.assertEqual(outputs,[])
            self.assertEqual(len(plan),7)
    def test_dry_run_does_not_execute_or_write(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(runner.subprocess,"run",side_effect=AssertionError("Must not execute")):
                self.assertEqual(runner.main(["--tests-only","--dry-run"],root=temp),0)
            self.assertEqual(list(Path(temp).iterdir()),[])
    def test_existing_output_fails_before_execution(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/"config").mkdir();(root/"results").mkdir()
            configs={"portable.json":{"output_dir":"results","data_dir":"data"},
                     "climate_portable.json":{"storage_dir":"climate"},"social.json":{"storage_dir":"social"}}
            for name,data in configs.items():(root/"config"/name).write_text(json.dumps(data))
            with self.assertRaises(FileExistsError):runner.build_plan(runner.cli([]),root)
    def test_full_plan_has_all_modules_and_no_download(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for folder in ["config","data","climate","social"]:(root/folder).mkdir()
            for file in ["data/manifest_sha256.csv","data/tnc_zones.gpkg","climate/download_manifest.json","social/download_manifest.json"]:(root/file).touch()
            configs={"portable.json":{"output_dir":"results_new","data_dir":"data"},
                     "climate_portable.json":{"storage_dir":"climate","tnc_zones":"data/tnc_zones.gpkg"},
                     "social.json":{"storage_dir":"social","tnc_zones":"data/tnc_zones.gpkg"}}
            for name,data in configs.items():(root/"config"/name).write_text(json.dumps(data))
            plan,_,outputs=runner.build_plan(runner.cli([]),root)
            self.assertEqual([x[0] for x in plan][-6:],["restoration","restoration_validation","priority_brief","climate","social","social_validation"])
            self.assertEqual(len(outputs),3)
            self.assertFalse(any("download" in str(cmd) for _,cmd in plan))
    def test_failed_step_writes_failure_and_stops(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(runner.shutil,"which",return_value="Rscript"),patch.object(runner.subprocess,"run") as run:
                run.return_value.returncode=3
                with self.assertRaises(RuntimeError):runner.main(["--tests-only","--report","failure.json"],root=temp)
                self.assertEqual(run.call_count,1)
            report=json.loads((Path(temp)/"failure.json").read_text())
            self.assertEqual(report["status"],"failed")
            self.assertEqual(report["steps"][0]["returncode"],3)


if __name__=="__main__":unittest.main()
