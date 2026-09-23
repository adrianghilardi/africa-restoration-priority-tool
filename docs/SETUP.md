# Reproducible setup and one-command execution

## Reference environment

The delivery was tested on Windows with **R 4.6.0** and Python 3.10 or newer. Python uses only its standard library. `dependencies.lock.csv` pins **19 direct and transitive non-base R packages**, including recommended packages used transitively. Base-package versions are pinned by R 4.6.0. The lock includes exact CRAN source URLs, MD5 and SHA256 hashes; source availability and tarball DESCRIPTION versions were checked when generating it. Rcpp `1.1.1-1.1` is an actual archived CRAN version, not a typographical normalization to `1.1.1`.

This is an explicit package lock, not a container or a lock on every OS library. GDAL, GEOS, PROJ, compilers and numerical libraries remain platform-specific; the workflow records their versions. Exact package pins improve repeatability but do not establish bit-for-bit cross-platform equivalence.

## Install without changing global R libraries

From the repository's code directory:

```text
Rscript scripts/install_dependencies.R
python scripts/run_all.py --tests-only
```

The installer uses base R and installs missing/mismatched versions into `code/.r-library`, never into a global R library. It verifies locked source MD5 hashes and installed versions; it will not silently substitute latest packages. Matching packages already visible in the R library search path can be reused. `code/.package-cache` contains downloaded source archives. Both directories should be ignored by Git. An alternative writable local location is supported by `--library PATH` on the installer and `--r-library PATH` on the runner.

Archived versions may require compilation. On **Windows**, install matching Rtools for R 4.6 and its spatial build prerequisites. On **Ubuntu 24.04**, install `libgdal-dev libgeos-dev libproj-dev libudunits2-dev libssl-dev libabsl-dev libnetcdf-dev libtbb-dev cmake` and a C/C++/Fortran build toolchain. On macOS, suitable compiler and geospatial development libraries are required; macOS setup has not been tested for this release. Package setup may take tens of minutes. See [R package installation documentation](https://cran.r-project.org/doc/manuals/r-release/R-admin.html#Installing-packages) for platform requirements.

The checker normally requires R 4.6.0. For an explicit compatibility trial, `--allow-r-version-difference` permits another R version while still enforcing package pins. Treat that as a new environment and inspect validation results; it is not an assertion of compatibility.

## Reproduce the delivery

A desktop with 16 GB RAM and at least 20 GB of free working space is recommended for comfortable source installation, extraction and separate rerun outputs. These are practical allowances, not measured hard minimums. Runtime varies with disk speed and geospatial-library builds; keep temporary files on a local drive with enough space.

Extract the Zenodo data archive so that `code`, `data`, `results`, `climate` and `social` are siblings. Then:

```text
python scripts/run_all.py
```

The runner checks pinned dependencies, runs synthetic R/Python tests, reproduces restoration and validates it, processes climate with its built-in checks, processes social context and checks all social summary calculations. It uses bundled frozen inputs; it does **not** prepare original global MoFuSS inputs, download new climate data, or refresh poverty observations. No Internet connection is needed once dependencies and the data package are present.

On Windows, a full Rscript path containing spaces is safe:

```powershell
python scripts/run_all.py --rscript "C:\Program Files\R\R-4.6.0\bin\Rscript.exe"
```

Arguments are passed as a list to the process API, not assembled into a shell command. The runner sets its working directory to the code root, so relative paths in the supplied configs resolve consistently. `--restoration-config`, `--climate-config` and `--social-config` select alternative configs; relative config paths are relative to the code root.

Default outputs are `results_reproduced`, `climate/processed_reproduced` and `social/processed_reproduced`. Existing output directories cause a preflight failure before analysis; edit the configs to use fresh destinations for another run. Partial outputs from a failed run are preserved for diagnosis, never automatically deleted. The runner writes an execution report at `audit/run_all_report.json`; use `--report` to choose a distinct report for another attempt.

Optional checks:

```text
python scripts/run_all.py --tests-only --dry-run
python scripts/run_all.py --install-deps --tests-only
python scripts/run_all.py --compare-reference
```

`--compare-reference` adds the existing exact reference comparisons and is intended for the same tested software/platform environment. Differences on another platform require examination rather than automatic claims of scientific disagreement. `--dry-run` prints the planned argument lists without executing commands or writing files, while still performing input/output preflight for a full-data plan.

## Continuous integration

`.github/workflows/tests.yml` installs the same package pins on Ubuntu and runs synthetic tests without downloading the large data bundle. It tests code and invariants, not full landscape replication. Its presence alone is not proof of a passing Linux run: check the actual GitHub Actions status after publication. Full delivery reproduction was tested separately on Windows; do not infer Linux/macOS validation from that result.
