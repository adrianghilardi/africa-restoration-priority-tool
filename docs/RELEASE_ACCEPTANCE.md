# Release verification — v1.0.0

## Accepted scope

The Congo Basin and KAZA prepared-input workflow passed a complete clean-clone reproduction on Windows on 23 September 2026. This release includes the versioned code, required prepared inputs, downloaded climate/social and open-boundary sources, reference outputs, maps, province shortlists, documentation and audit receipts. It reproduces the prioritization analysis from the archived MoFuSS outputs; it does not claim to rerun the upstream MoFuSS simulations from scratch.

## Verification evidence

- **Clean GitHub clone, complete workflow:** the final run completed at 10:27:57 UTC, with every step returning zero. It included dependencies, synthetic tests, restoration, validation, province briefs, climate, social context and reference comparisons. Only portable output destinations were changed; no original drive-D inputs were required.
- **Restoration:** all 84 GeoTIFFs reproduced exactly. All 21 complete CSV products matched, including identifiers, province names, classifications and missing values. All 24 numerical/coverage checks passed.
- **Climate:** all 102 value/significance GeoTIFFs and nodata masks reproduced exactly; all 24 percentile-order checks passed and maximum zonal-mean difference was zero.
- **Social context:** all eight population GeoTIFFs and four CSV tables reproduced byte-for-byte. All 48 zone-scenario and 320 country-context rows passed arithmetic and coverage checks.
- **Presentation products:** the six province brief/map/shortlist products and 14 climate/social tables/maps matched their clean-clone copies byte-for-byte. The two priority maps and two restoration overview maps were visually inspected.
- **Input integrity and provenance:** all 50 prepared-input SHA256 entries passed. Sanitized reporting schemas, open ADM1 boundary coverage, source licences and output classifications were independently checked. Rebuilding the ecoregion layers directly from the checksum-verified provider ZIP reproduced every attribute and geometry coordinate; GeoPackage binary identity is not claimed because container metadata can differ.
- **Windows tests:** 93 synthetic checks/test groups and all 19 exact R package versions passed, using Python 3.12.14, R 4.6.0, GDAL 3.12.1, PROJ 9.7.1 and GEOS 3.14.1.
- **Independent Linux installation:** [GitHub Actions run 35846859099](https://github.com/adrianghilardi/africa-restoration-priority-tool/actions/runs/35846859099) passed from a dependency-cache miss on Ubuntu 24.04 with R 4.6.0 and Python 3.12.14. Fifteen packages built from source and four exact matching R-recommended packages were reused; all 19 locked versions and synthetic tests passed. The Linux spatial runtime was GDAL 3.8.4, PROJ 9.4.0 and GEOS 3.12.1. Full-landscape Linux raster reproduction is not claimed.

Machine-readable evidence is included in the archive's `audit/` directory, especially `final_clean_clone_workflow.json`, `reproduction_check.json`, `climate_reproduction_check.json`, `linux_ci_fresh_install.json`, and the independent science checks. Machine-specific execution paths are replaced with symbolic labels; numerical settings are unchanged. The archive also includes a complete SHA256 payload manifest and an external archive checksum receipt.

## Interpretation and limits

The province screen identifies six Critical and 17 Major Congo Basin intersections, and three Critical and nine Major KAZA intersections. Twenty-seven Congo Basin and three KAZA intersections remain unclassified under the stated coverage/validity rules; these are not automatically low priority. Full criteria and eligible-population denominators are in [METHODS.md](METHODS.md) and [DATA_DICTIONARY.md](DATA_DICTIONARY.md).

Recovery is a conditional, zero-harvest 2030–2050 calculation over a historical forest/woody-savanna screen, not a current site-eligibility map or an intervention effect. Two Monte Carlo realizations do not constitute a probabilistic confidence interval. Climate layers provide scenario context and do not modify biomass growth. National poverty rates are contextual proxies, not local observations, forecasts or beneficiary estimates. Open grasslands and savannas must not be treated as automatic tree-planting opportunities.

No current-land-cover calibration, field ecological validation, intervention-effect validation or carbon-credit certification is claimed. Public release permission for commissioned/TNC/supplied cTrees-derived data was confirmed by the depositor; external data retain their own terms. Canonical MoFuSS source and runs were not modified.

## Release locations

- [Versioned source release](https://github.com/adrianghilardi/africa-restoration-priority-tool/releases/tag/v1.0.0)
- [Complete archived package, DOI 10.5281/zenodo.22914522](https://doi.org/10.5281/zenodo.22914522)
- [TNC quick start](TNC_QUICKSTART.md)
