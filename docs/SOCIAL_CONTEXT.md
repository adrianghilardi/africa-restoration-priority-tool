# Population pathways and poverty context

## Purpose for TNC

Use this module alongside the restoration, investment and climate results to ask whether candidate landscapes also face demographic pressure and national poverty concerns. It is a separate social-context view. It does not alter biomass growth, identify individual households, create a composite ranking, measure local poverty, estimate beneficiaries or claim poverty reduction caused by restoration.

The v1 default combines observed national poverty with published population scenarios. This is a deliberately simple population well-being sensitivity, not a calibrated forecast of local livelihoods. Current local poverty, tenure, access, gender, distributional effects and consultation still require project-level evidence.

## Sources and reuse

1. **Population:** [World Bank CCKP public population collection](https://worldbank.github.io/climateknowledgeportal/docs/collections/pop-x0.25.html), native 0.25-degree population density in persons/km2. The four files are period means for 2020–2039 and 2040–2059 under the provider's `ssp245` and `ssp585` labels. These contain SSP2 and SSP5 demographic pathways; the radiative-forcing suffix does not itself drive population. The NetCDF metadata identifies Jones, B. and B. C. O'Neill (2020), *Global One-Eighth Degree Population Base Year and Projection Grids Based on the Shared Socioeconomic Pathways, Revision 01*, NASA SEDAC, [doi:10.7927/m30p-j498](https://doi.org/10.7927/m30p-j498), and Jones and O'Neill (2016), [doi:10.1088/1748-9326/11/8/084003](https://doi.org/10.1088/1748-9326/11/8/084003). CCKP standardizes these at 0.25 degrees. Its general source label GPWv4 does not turn future SSP projections into census observations. [NASA's published terms](https://gis.earthdata.nasa.gov/portal/home/item.html?id=cc1d5a32e81241e98a16b24e6e75195d) permit copying, adaptation and redistribution with clear attribution. The [CCKP metadata](https://climateknowledgeportal.worldbank.org/metadata) states CC BY 4.0 for portal data. Retain both source attributions.
2. **Poverty:** [World Bank WDI indicator SI.POV.DDAY](https://data.worldbank.org/indicator/SI.POV.DDAY), poverty headcount below **$3.00/person/day in 2021 PPP**, percent of national population; original source World Bank Poverty and Inequality Platform and household surveys. The indicator page states **CC BY 4.0**. The downloader saves the API response and selects each country's latest non-missing observation from 2000 through the configured cutoff (2026 in this release). It checks the indicator definition, rejects duplicate latest observations and preserves missing rates. Survey/reference years differ and can be old. “Latest available” does not mean a 2026 estimate. The legacy CCKP $1.90 poverty grid is not used.
3. **Country geometry:** [Natural Earth 1:50m admin-0 countries, version 5.1.1](https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/), [public domain](https://www.naturalearthdata.com/about/terms-of-use/). Country outlines are generalized broad-context boundaries, not legal or cadastral evidence. They may differ slightly from TNC boundaries and model geometries.
4. **TNC planning geometries:** the same packaged `data/tnc_zones.gpkg` used by the main workflow. Their original source/reuse conditions continue to apply separately.

The source manifest records exact URLs, download timestamps, byte sizes and SHA256 hashes. CCKP file sizes and single-part MD5 ETags are checked when downloading. Analysis can then run offline. A downloader rerun verifies the frozen snapshot; it does not silently replace poverty observations with newly revised data. Refresh into a new storage directory and version the results.

## Transparent calculations

For each native population cell, population within a polygon is `density × geodesic cell area in km2 × exact cell coverage fraction`. This assumes uniform density within the coarse cell. Regional rasters are cropped only, never sharpened to 1 km. Totals are approximate scenario population, not official census totals, and period means are not exact counts for 2030 or 2050.

The module intersects each TNC planning zone with Natural Earth countries, retaining the national observation year and rate for each country component. No local poverty raster is produced. For a country component, the **poverty exposure proxy** is `modelled population × national poverty percentage / 100 × sensitivity multiplier`. The sum is a what-if quantity assuming uniform national rates within countries, not the number of people actually living in poverty inside the zone.

Two independently configurable poverty sensitivities are crossed with both population pathways and both periods:

- `constant_national_rate`, multiplier 1.0: retain the last observed national rate.
- `half_national_rate`, multiplier 0.5: apply half that rate as an illustrative improvement sensitivity.

The second case is a **50% relative reduction**, not a 50-percentage-point reduction. It is applied at each selected period as a comparison condition; no annual transition, probability, SSP-specific poverty trajectory or restoration causality is implied. It is intentionally not assigned only to SSP5 or only to SSP2. A scenario label is not evidence that growth or restoration delivers that improvement.

National-context coverage is the population covered by non-missing national rates divided by independently computed zone population. The aggregate exposure proxy is withheld below 99% coverage; available-country details remain visible. Missing rates never become zero. The population-weighted national poverty context percentage is reported on the covered population only. Country-intersection population versus direct-zone population is checked with a 2% maximum geographic discrepancy; actual differences are retained in the QA table. Nested TNC interest, influence and operations zones overlap and must not be added together.

## Run and inspect

From the code directory, with Python 3 and R packages `terra`, `jsonlite`, `digest`:

```text
python scripts/05_download_social.py config/social.json
Rscript tests/test_social.R
python tests/test_social_download.py
Rscript tests/test_social_spatial.R
Rscript scripts/06_prepare_social.R config/social.json
```

Paths in the portable config are relative to the code working directory, consistent with the main workflow. The source snapshot lives at `../social`. `processed_subdir` defaults to `processed`; choose `processed_reproduced` for a verification rerun, because outputs are never overwritten.

Main outputs are `tnc_zone_social_scenarios.csv`, detailed `tnc_zone_country_social_context.csv`, `social_quality_checks.csv`, eight native population-density GeoTIFFs and one population/poverty context PNG per landscape. The maps use a log10(density + 1) display scale only; GeoTIFF values remain persons/km2. National poverty bars show country codes and observation years. Refer to the country table for full names.

When interpreting a high-restoration/high-poverty-context location, use it to prioritize equitable feasibility assessment, livelihood alternatives and consultation. Do not infer that harvest restrictions are socially acceptable, that residents are the woodfuel harvesters, or that restoration will improve their incomes.
