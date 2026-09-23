# Climate exposure context

This module places future temperature, rainfall and dry-spell exposure alongside restoration recovery and woodfuel pressure. It retains physical quantities and ensemble spread. It does not modify growth using an uncalibrated climate multiplier.

## Source and selection

Source: World Bank Climate Change Knowledge Portal (CCKP), public `cmip6-x0.25` archive. Selection comprises `tas`, `pr` and `cdd`; SSP2-4.5 and SSP5-8.5; future 2020–2039 and 2040–2059; provider p10/median/p90 anomaly grids; and historical median climatology for 1995–2014. These make 39 original NetCDF files. Exact object URLs, download time, size, modification date, ETag and SHA256 are preserved in the download manifest.

Archive documentation: <https://worldbank.github.io/climateknowledgeportal/README.html>  
Structure example: <https://worldbank.github.io/climateknowledgeportal/notebooks/cmip6-x0.25.html>

| Variable | Future anomaly quantity | Unit verified in source files |
| --- | --- | --- |
| `tas` | Annual mean near-surface air temperature change | degrees Celsius |
| `pr` | Annual precipitation change | millimetres, not percent |
| `cdd` | Change in the longest annual sequence with daily precipitation below 1 mm | days |

CCKP supplies the anomalies relative to 1995–2014; the tool does not manufacture them by subtracting independently calculated ensemble percentiles. It selects the exact named data variable rather than accidentally reading the separate significance variable.

## Spatial and scenario interpretation

Numerical products retain the native 0.25-degree grid, roughly 25–28 km across the landscapes. Resampling to 1 km would not create 1 km climate information. Mid-century values represent the 2040–2059 average, not a single-year 2050 forecast.

SSP2-4.5 is the intermediate-forcing pathway; SSP5-8.5 is a high-forcing sensitivity. No probability is assigned to either. Provider ensemble percentiles express grid-cell model spread, not confidence bounds for a restoration project's carbon benefit. A spatial mean of the p10 grid is not the p10 of a landscape-wide ensemble mean.

## Reproduce

From `code/`, using the portable archive:

```text
Rscript scripts/03_prepare_climate.R config/climate_portable.json
```

The config uses `../climate` and packaged TNC zones, stored geographic bounds and `../scratch/climate`; no original model-drive paths are required. Reprocessing writes `climate/processed_reproduced/` and refuses to overwrite an existing directory. To verify/download the original source snapshot again:

```text
python scripts/00_download_climate.py config/climate_portable.json
```

Python uses only its standard library. R uses terra, jsonlite and digest. An existing download is reused only after manifest and checksum verification. To refresh sources, choose a new storage/version directory rather than changing a frozen release in place.

## Processing and checks

Each regional window covers the documented model/TNC extent. Zonal means use geodesic cell area and exact polygon coverage. Missing values contribute neither a climate value nor its area weight; covered area and coverage fraction are reported. Interest, influence and operations zones overlap and must not be summed.

Checks cover source hashes, units, CRS, native resolution and p10 ≤ median ≤ p90 at valid cells. The global source grid has latitude centres at the poles with cell edges beyond ±90 degrees, which can trigger a geographic-range warning in terra. The regional African windows exclude those cells. Polygon Z coordinates are ignored for two-dimensional area summaries.

For these source files, CCKP encodes robust change as missing in the significance variable. The output assigns significance code 3 only where the corresponding anomaly is valid; 1 denotes no significant change, 2 conflicting model signals and 0 no data. Missing anomalies remain missing. Thus provider missing significance is not automatically interpreted as missing climate or as robust change over no-data cells.

Delivered products include native regional value and significance GeoTIFFs, a six-panel climate PNG for each landscape, `tnc_zone_climate_summary.csv`, inventory, significance legend and quality checks. Actual v1 rerun/comparison evidence is recorded in the release acceptance report; it is not assumed from prior review-run results.

## Attribution and rights

The [CCKP metadata](https://climateknowledgeportal.worldbank.org/metadata) states CC BY 4.0. Credit World Bank CCKP, the World Climate Research Programme, participating climate modelling groups and the Earth System Grid Federation; preserve NEX-GDDP-CMIP6 acknowledgements in the NetCDF metadata. Identify cropping, format conversion and zonal aggregation as modifications.

Methodology: Thrasher et al. (2022), *NASA Global Daily Downscaled Projections, CMIP6*, <https://doi.org/10.1038/s41597-022-01393-4>.

Climate terms do not replace other datasets' rights. Climate context does not establish future tenure, governance, well-being, wildfire risk or a complete drought assessment. The separate social module supplies its own transparent population/poverty-context sensitivities.
