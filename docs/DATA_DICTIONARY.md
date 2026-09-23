# Data dictionary

Paths are relative to the delivery root. Region identifiers are `congo` and `kaza`. GeoTIFF NoData is missing/unsupported; it is not zero. CSV missing values likewise must not be filled with zero by default. The model grid is nominal 1 km in EPSG:3395 (World Mercator), not an equal-area grid. Climate products retain a different, native geographic grid.

## Temporal and mass conventions

- **Recovery window:** post-harvest 2030 to 2050; 20 years of conditional growth; BAU harvest summed over 2031–2050 inclusive.
- **Investment pressure window:** within-year pre-harvest `Growth` for 2020 to post-harvest 2050; harvest summed over 2020–2050 inclusive.
- **MgDM:** megagrams of dry biomass. Model mass per nominal cell is distinct from a ground-area-weighted density total. The supplied 1 km run has a nominal 100 ha density divisor.
- **`mc001`/`mc002`:** the two supplied BAU realizations. `mean`, `min`, `max` summarize these, with complete-data semantics; they are not confidence intervals.
- **`k075`/`k100`/`k125`:** 0.75/1.00/1.25 multipliers on growth rate k. They are deterministic sensitivity cases, not climate scenarios.

## Prepared regional inputs: `data/<region>/`

| File family | Meaning and unit |
| --- | --- |
| `mask_c.tif` | Model domain; NoData outside. |
| `A_c.tif`, `k_c.tif`, `m_c.tif` | Exact run-specific Chapman–Richards capacity, rate and shape. A uses model MgDM per nominal cell; divide by 100 ha for the supplied run. k is per year; m is dimensionless. |
| `LULCt1_c.tif`, `landcover_lookup.csv` | Historical model land-cover codes and class interpretation; input configuration indicates MODIS 2001. |
| `stock_2030_mcNNN.tif`, `stock_2050_mcNNN.tif` | Post-harvest stock; model MgDM per nominal cell. |
| `investment_baseline_2020_mcNNN.tif` | Within-year pre-harvest 2020 stock; model MgDM per nominal cell. |
| `harvest_2031_2050_mcNNN.tif`, `harvest_2020_2050_mcNNN.tif` | Harvest summed over the named inclusive window; model MgDM per nominal cell. |
| `observed_2000_MgDM_ha.tif`, `observed_2025_MgDM_ha.tif` | Regional cTrees snapshots converted from documented MgCO2/ha using `(12/44)/0.47`; bilinearly projected; negative estimates become missing. |
| `mofuss_adm1_fr.gpkg`, `mofuss_ecoregions_fr.gpkg` | Province/ecoregion geometry inputs. Only identity and geometry are analytical inputs; inherited result attributes are not current results. |
| `years.txt`, `Resolution.csv`, `InputPara.csv`, `parameters.csv` | Provenance of time indexing and supplied run setup; not a complete upstream simulation environment. |

`data/tnc_zones.gpkg` contains the selected planning-zone geometry inputs. `manifest_sha256.csv` verifies the prepared bundle. A source-provenance table links input roles to source identifiers and hashes; source identifiers in a public release should be portable, not private drive paths.

The default historical screen includes forest and woody savanna. It does not approve tree planting in natural grassland/savanna. Unused upstream protected-area layers are not required by this analysis and are not automatically part of the public bundle.

## Restoration outputs: `results/<region>/`

| File family | Meaning / unit / interpretation |
| --- | --- |
| `recovery*_MgDM_ha*.tif` | Conditional aboveground dry-biomass gain over 20 years. Zero further harvest, stable land use and unchanged growth conditions are assumed. Only the selected historical screen has values. |
| `net_depletion*_MgDM_ha*.tif` | Positive part of post2030 minus post2050 BAU stock, expressed per nominal hectare. This is not the investment-window NRB. |
| `harvest*_MgDM_ha*.tif` | BAU harvest over 2031–2050, per nominal hectare. |
| `net_depletion_share_of_harvest.tif` | Recovery-window net depletion divided by harvest, using the mean surfaces. Dimensionless diagnostic; undefined when harvest is not positive. |
| `investment_nrb*_MgDM_cell*.tif` | Positive part of `Growth2020 − post2050`; model MgDM per nominal cell. |
| `investment_harvest*_MgDM_cell*.tif` | Harvest summed over 2020–2050; model MgDM per nominal cell. |
| `investment_fNRB_ratio_of_MC_means.tif` | Investment NRB divided by investment harvest after cellwise realization averaging; dimensionless. Unsupported ratios are retained/flagged rather than silently capped. |
| `observed_change_2000_2025_MgDM_ha.tif` | 2025 snapshot minus 2000 snapshot; positive means increased observed-data biomass estimate. Not a causal restoration effect. |
| `screening_eligibility.tif` | Selected historical land-cover screen, 1 included / 0 outside selected classes / NoData unknown or outside model domain. Not present-day eligibility. |
| `historic_forest_and_woody_savanna_context.tif` | Broader historical woody-ecosystem context, same coding convention. |
| `ground_cell_area_ha.tif` | Geodesic ground-cell area in hectares; used for mapped-area recovery totals. |
| `screening_class.tif`, `screening_class_legend.csv` | Diagnostic pixel class 0–5; not the four province investment classes. |
| `investment_provinces.gpkg` | Province geometry clipped to TNC interest zone, recomputed quantities, coverage and landscape-relative pressure class. |
| `summary_adm1.csv`, `summary_ecoregions.csv`, `summary_zone_*.csv` | Exact fractional-cell zonal summaries. Overlapping zone sets must not be added. |
| `threshold_sensitivity.csv` | Candidate area under 5/10/20 MgDM/ha recovery and 0.15/0.25/0.35 depletion-share thresholds. These are screening choices, not fitted ecological thresholds. |
| `<region>_restoration_screen.png` | Overview for discussion. Full-resolution quantitative values remain in the GeoTIFFs. |

### Pixel class codes

| Code | Meaning |
| --- | --- |
| 0 | Other historical land cover; separate assessment |
| 1 | Below the configured conditional recovery threshold |
| 2 | Recovery potential; no net BAU depletion |
| 3 | Recovery potential with BAU depletion |
| 4 | Recovery potential with high depletion share |
| 5 | Mass-balance or attribution review |

### Zonal summary fields

| Field | Definition |
| --- | --- |
| `model_domain_ground_ha` | Zone area supported by the model-domain grid. |
| `zone_ground_ha` | Full polygon ground area. |
| `screening_eligible_ground_ha` | Area included by the selected historical screen. |
| `recovery_covered_ground_ha` | Area with valid recovery values. |
| `conditional_recovery_MgDM` | Sum of conditional recovery density × geodesic area × polygon coverage. Not a carbon credit quantity. |
| `area_weighted_recovery_MgDM_ha` | Previous total divided by valid recovery area. |
| `high_pressure_recovery_ground_ha` | Area in pixel screening class 4 for the configured thresholds. |
| `NRB_2020_2050_model_MgDM` | Investment NRB model masses summed with fractional polygon coverage. |
| `harvest_2020_2050_model_MgDM` | Investment harvest model masses summed with the same coverage. |
| `investment_covered_ground_ha` | Area with paired valid NRB and harvest values. |
| `investment_coverage_fraction` | Paired valid area / model-domain area within the zone. |
| `domain_coverage_fraction` | Model-domain area / full polygon area. |
| `fNRB_2020_2050` | Ratio of aggregated NRB to aggregated harvest, not a mean of pixel ratios. |
| `investment_class` | Critical (high/high); Major supply-shed (high NRB/low fNRB); Fragile/local (low NRB/high fNRB); Lower priority (low/low). |
| `NRB_landscape_tercile_cutpoint`, `fNRB_landscape_tercile_cutpoint` | Separate within-landscape top-tercile thresholds among valid provinces; R quantile type 7. Equality is high; zero pressure is not high. |
| `classification_status` | Indicates whether coverage and ratio requirements permit classification. Minimum coverage is 99% in both checks. |

Province identity fields include country/province names and identifiers. The compatibility field `GID_1` in v1 contains the geoBoundaries `shapeID`, not an inherited GADM province identifier; use its source manifest when joining. Counts refer to clipped province intersections, not necessarily whole provinces. Mean/min/max of two realizations must not be labelled a statistically established uncertainty interval.

## Climate outputs

Original NetCDFs, a download manifest, regional value/significance GeoTIFFs, overview maps and a zonal CSV are retained under `climate/`. Consult the portable climate configuration for the exact processed subdirectory.

| Variable / field | Meaning |
| --- | --- |
| `tas` anomaly | Change in annual mean near-surface temperature; degrees Celsius. |
| `pr` anomaly | Change in annual precipitation; millimetres, **not percent**. |
| `cdd` anomaly | Change in longest annual dry spell (precipitation <1 mm/day); days. |
| `period` | Historical 1995–2014 or future 2020–2039 / 2040–2059. Future anomaly reference is 1995–2014. |
| `scenario` | SSP2-4.5 or SSP5-8.5 (plus historical). No scenario probability is implied. |
| `gridcell_ensemble_statistic` | Provider p10, median or p90 at individual grid cells. |
| `area_weighted_mean` | Geodesic-area-weighted zonal mean of the named grid. A mean of a percentile grid is not the corresponding percentile of a zone-wide ensemble. |
| `climate_covered_km2`, `zone_km2`, `coverage_fraction` | Valid-data area, polygon area and their ratio. Small numerical differences around 1 can reflect polygon/raster area calculations. |
| Significance codes | 0 no data; 1 no significant change; 2 conflicting model signals; 3 robust change, recoded only where the anomaly is valid. Missing anomaly stays missing. |

The grid is 0.25 degrees, about 25–28 km in these landscapes. Numerical outputs do not imply 1 km climate information or a single-year 2050 forecast. Climate is not used to rescale growth parameters.

## Quality and provenance

`quality_checks.csv` reports diagnostics, including flagged ratios. `validation_checks.csv` reports pass/fail invariants. `analysis_config.json`, session information and geospatial-library versions record how a run was made. Checksums establish byte integrity of inputs; reproduced raster comparisons establish numerical consistency for the tested environment, not ecological validation.

## Social-context outputs

Full methods and source attributions are in `docs/SOCIAL_CONTEXT.md`. Delivered outputs are in `social/processed/`; the portable rerun writes `social/processed_reproduced/`.

| File / field | Meaning |
| --- | --- |
| `<region>/population_density_<scenario>_<period>_persons_km2.tif` | Native 0.25-degree period-mean population density, persons/km2; SSP2 or SSP5 pathway under provider labels `ssp245`/`ssp585`. Not a 1 km or single-year census surface. |
| `<region>/<region>_population_and_poverty_context.png` | Population map with log10(density + 1) display scale plus national poverty bars and source observation years; underlying TIFF values remain untransformed. |
| `tnc_zone_social_scenarios.csv` | TNC-zone population/poverty-context combinations across two population pathways, two periods and two poverty sensitivities. |
| `tnc_zone_country_social_context.csv` | Country-component details, preserving national rate/year and missing values. Country geometry is Natural Earth 1:50m v5.1.1. |
| `social_quality_checks.csv` | Native area coverage and country-intersection versus direct-zone population discrepancy. Maximum allowed discrepancy is 2%. |
| `modelled_population` | Population density × geodesic area × exact polygon coverage, summed. An approximate period-mean scenario count. |
| `national_poverty_pct` | Latest available national poverty headcount rate below $3/person/day in 2021 PPP, WDI `SI.POV.DDAY`; not a measured TNC-zone rate. |
| `national_observation_year` | Source year selected from available 2000–2026 observations; can predate the release substantially. Latest available is not a 2026 observation. |
| `poverty_sensitivity`, `rate_multiplier` | `constant_national_rate` = 1.0; `half_national_rate` = 0.5. The second is a 50% relative reduction, not 50 percentage points. Each is crossed with both population pathways; neither is an SSP-calibrated poverty forecast. |
| `poverty_exposure_proxy_not_beneficiaries` | Modelled population × national poverty fraction × sensitivity multiplier. Assumes a uniform country rate; not actual local people in poverty or restoration beneficiaries. Aggregate withheld below 99% valid national-context population coverage. |
| `national_context_population_coverage` | Population with valid national poverty context / independently calculated zone population. |
| `population_weighted_national_poverty_context_pct` | Covered-population-weighted national rate under the named sensitivity. Not a local poverty measurement. |
| `oldest_national_observation`, `newest_national_observation` | Range of source years informing the zone context. |

The social module is an independent screening view. It does not change growth, pressure classes or eligibility, or imply poverty reduction caused by restoration. No local poverty raster or household-level inference is produced.
