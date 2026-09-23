# Restoration Priority Tool — Congo Basin and KAZA

A reproducible, MoFuSS-based decision-support tool for **landscape restoration screening**. Version 1.0.0 combines woodfuel pressure, conditional biomass recovery, and climate exposure without hiding their different meanings in a single weighted score. It helps a landscape team choose where to investigate restoration and sustainable woodfuel interventions; it does not approve sites or estimate credited carbon benefits.

Code: [africa-restoration-priority-tool](https://github.com/adrianghilardi/africa-restoration-priority-tool) · Version archive and regional data: [10.5281/zenodo.22914522](https://doi.org/10.5281/zenodo.22914522)

## What the tool delivers

- Province pressure priorities: **Critical**, **Major supply-shed**, **Fragile/local**, and **Lower priority**, using separately calculated landscape cut-points.
- Ready-to-read province priority maps, short landscape briefs and CSV investigation shortlists in `results/priority_brief/`.
- Nominal 1 km maps of conditional recovery from post-harvest 2030 to 2050, woodfuel-related BAU depletion, observed biomass change, and explicit screening classes.
- Province, ecoregion and TNC planning-zone summaries with valid-data coverage; two landscape overview maps.
- Native 0.25-degree climate context for SSP2-4.5 and SSP5-8.5, retaining model spread, significance and the 2040–2059 time window.
- Population pathways and national poverty context, with explicit constant-rate/half-rate sensitivities rather than a claimed local poverty forecast.
- Checksummed inputs, runnable source, tests, configuration, output validation and documented assumptions.

[TNC_QUICKSTART.md](docs/TNC_QUICKSTART.md) explains how to use the outputs. [METHODS.md](docs/METHODS.md) explains the calculations. [DATA_DICTIONARY.md](docs/DATA_DICTIONARY.md) explains files, units and missing values. [V1_ASSUMPTIONS_AND_V2.md](docs/V1_ASSUMPTIONS_AND_V2.md) states the scope of the release.

[View the two province-priority maps and example results](docs/EXAMPLE_OUTPUTS.md).

## Reproduce the delivered analysis

Download the versioned data archive from the Zenodo record above and extract the supplied directory layout. Use the code from the matching release tag, not a moving default branch. A complete local delivery has this structure:

```text
delivery/
  code/                 # this repository, or the matching archived source
  data/                 # prepared regional model inputs and SHA256 manifest
  results/              # delivered restoration outputs
  climate/              # downloaded climate sources and regional outputs
  social/               # social-context sources, scenarios and summaries
  boundaries/           # open administrative sources and per-country licences
  ecoregions/           # original RESOLVE source archive and provenance
  audit/                # release-specific validation evidence
```

Use R 4.6.0 and Python 3.10 or newer. `dependencies.lock.csv` pins 19 direct/transitive non-base R packages with source hashes; `environment.json` is a runtime record, not the lockfile. Spatial packages also require compatible GDAL, PROJ, GEOS and build tools. See [SETUP.md](docs/SETUP.md) for installation and platform details. This is an R/Python pipeline, not a web application; a GIS such as QGIS is useful for inspecting the results.

From the `code` directory, run:

```text
Rscript scripts/install_dependencies.R
python scripts/run_all.py --tests-only
python scripts/run_all.py --compare-reference
```

The installer uses a local `code/.r-library`, not global R libraries, and the runner makes that library available to all modules. The runner checks dependencies, runs synthetic tests, executes restoration/climate/social analysis from the frozen bundled inputs and validates outputs. It does not redownload sources or rerun MoFuSS. With a spaced Windows path, use `python scripts/run_all.py --rscript "C:\Program Files\R\R-4.6.0\bin\Rscript.exe"`.

Portable configurations use the sibling data directories above. Restoration results are written to `results_reproduced/`; climate and social reruns use their respective `processed_reproduced/` directories. Existing result directories are never overwritten: give a subsequent run a different output path. The runner writes `audit/run_all_report.json`. Retain the configuration/session reports and use `--compare-reference` for explicit same-environment comparison with delivered results; differences on other platforms require inspection.

To refresh sources or run components separately, follow [SETUP.md](docs/SETUP.md), [CLIMATE.md](docs/CLIMATE.md) and [SOCIAL_CONTEXT.md](docs/SOCIAL_CONTEXT.md). Downloading current data is a new version, not silently reproducing the frozen snapshot.

Reproducing this tool means regenerating the delivered **postprocessing analysis from its prepared regional inputs**. It does not mean recreating the upstream MoFuSS/DINAMICA EGO BAU simulations or downloading every original global source raster. Their lineage and the input-preparation step are documented separately in [DATA_SOURCES.md](docs/DATA_SOURCES.md).

## Use the results for a prioritization discussion

1. Identify high-pressure province intersections in `results/<region>/investment_provinces.gpkg`, checking the coverage and classification status first.
2. Within those areas, compare conditional recovery with depletion and observed-change layers. Keep the physical quantities visible.
3. Compare growth and screening sensitivities and the climate context; then record current ecosystem, tenure, livelihoods and implementation evidence for a shortlist.

`congo` and `kaza` are the region identifiers. TNC interest, influence and operations zones overlap: do not add their totals together. A missing value or unclassified province is not a zero opportunity.

## Interpretation boundaries

Recovery assumes zero further harvest, unchanged growth conditions and stable land use. It is a biophysical envelope, not an ANR impact estimate. V1 includes historical forest and woody-savanna classes by default (`include_woody_savanna=true`) so native woodland recovery is visible in KAZA. This does not establish current ecological eligibility or authorize afforestation of natural open ecosystems. Climate anomalies are contextual exposures, not uncalibrated growth multipliers. Two existing BAU realizations and deterministic sensitivity cases are not probabilistic confidence intervals.

See [TNC_QUICKSTART.md](docs/TNC_QUICKSTART.md) for a safeguards and feasibility checklist. The [social module](docs/SOCIAL_CONTEXT.md) combines native 0.25-degree SSP population with observed national poverty below $3/day (2021 PPP). It compares the latest observed national rate with half that rate, crossed with both population pathways. These are transparent social-context sensitivities, not measured local poverty, restoration beneficiaries or causal well-being benefits.

## Citation, rights and support

Cite the version-specific Zenodo DOI and the upstream sources listed in [DATA_SOURCES.md](docs/DATA_SOURCES.md). `CITATION.cff` records the software citation. New commissioned software is released under the [MIT licence](LICENSE), copyright The Nature Conservancy. Authorized contributed data are released under [CC BY 4.0](DATA_LICENSE.md); external datasets retain their source-specific terms in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). A code licence does not replace those dataset terms. The repository does not include private contracts or correspondence. Report reproducibility issues through the repository issue tracker, including the release tag, command, configuration and error message, without credentials or private source data.
