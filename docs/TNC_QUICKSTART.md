# TNC analyst quickstart

## First use: 30–45 minutes

Use this guide with a landscape analyst and programme lead. The aim is a transparent shortlist for field and stakeholder assessment, not an automatic funding decision.

1. **Choose the landscape and planning geography.** Select Congo Basin or KAZA, then the TNC interest, influence or operations layer appropriate to the decision. These are overlapping views, not additive reporting units.
2. **Start with pressure.** Open `results/<region>/investment_provinces.gpkg` in a GIS. Filter `classification_status` to `Classified`; inspect NRB magnitude, fNRB, coverage and the province's clipped extent. A Critical province combines high absolute pressure and high depletion intensity. It does not imply that all its pixels are restoration sites.
3. **Look for recovery and pressure together.** Open the landscape PNG, then `recovery_MgDM_ha_mean.tif`, `net_depletion_MgDM_ha_mean.tif` and `screening_class.tif`. Use the supplied legend. Compare with `observed_change_2000_2025_MgDM_ha.tif`; that observed-data context is not independent validation of a model using related inputs.
4. **Check eligibility and ecological context.** Inspect `screening_eligibility.tif`, `eligibility_rules.csv` and `historic_forest_and_woody_savanna_context.tif`. The run's historical land cover cannot establish today's land use or a planting mandate. Native woodland recovery is different from increasing tree cover in natural grassland or savanna.
5. **Check robustness.** Compare the k075, base and k125 recovery maps and `threshold_sensitivity.csv`. A location sensitive to modest assumptions should carry an explicit uncertainty note. Examine both climate pathways, p10/median/p90 and significance; do not use a 0.25-degree value as a parcel-scale forecast.
6. **Bring people and feasibility into the decision.** Open `social/processed/tnc_zone_social_scenarios.csv` and the landscape population/poverty PNG. Compare SSP2/SSP5 population and constant/half national poverty-rate sensitivities. Poverty rates are national observations below $3/day (2021 PPP), with source years retained; multiplying by population does not measure local poverty or count beneficiaries. Verify local livelihoods, rights and priorities, and record why each shortlisted area is worth further work.

The priority classes are relative **within each landscape**. Do not read the same class in Congo and KAZA as equal absolute pressure. Use the reported physical quantities for cross-landscape comparisons.

## From evidence to intervention

| Decision direction | Evidence the tool contributes | Evidence required locally |
| --- | --- | --- |
| RESTORE | Recovery envelope coincides with depletion; historical woody ecosystem context | Present degradation, native regeneration, tenure and consent, manageable fire/grazing/harvest, leakage and costs |
| PROTECT | Current analysis highlights pressure and stock/recovery context | Biodiversity and conservation value, intactness, rights, threats and appropriate management |
| GROW SUPPLY | Large supply-shed pressure with lower depletion intensity | Feasible sustainable yield, demand and displacement, land suitability, safeguards and tenure |
| GOVERN | Spatial pressure helps frame questions | Trade chains, markets, enforcement, institutions and community priorities; biomass cannot establish these |

None of these directions is assigned solely by a province pressure class. The tool supports a reasoned intervention diagnosis, not a fixed one-to-one prescription.

## Shortlist record to retain

For each candidate, record: release version and configuration; geography and coordinates; province pressure class; recovery and depletion quantities with units; valid-data coverage; sensitivity result; climate and social context; current ecosystem and land use; rights/community priorities; proposed intervention; displacement risk; cost/implementation constraints; evidence still required; responsible reviewer and review date.

Do not enter personal household data into the public repository. Aggregate social layers do not establish an individual's poverty, consent or vulnerability.

## Re-run one assumption

Follow [SETUP.md](SETUP.md) and run `python scripts/run_all.py` first without changing the supplied configurations. Then copy the portable configuration to a named scenario, change one parameter, and select a new output directory; the runner's config override options select it. For example, changing `gain_threshold_MgDM_ha` from 10 to 20 changes screening classes, not the underlying growth trajectory. Retain the original and changed configurations and compare the sensitivity table and mapped area.

V1 sets `include_woody_savanna=true` to include native woodland recovery context alongside historical forest. A forest-only sensitivity sets it to `false`. Interpret both as historical ecological screens, never as approval to convert open ecosystems. Neither replaces a current no-go or eligibility assessment.

## Common problems

| Message or symptom | What to do |
| --- | --- |
| Input checksum mismatch | Stop. Check the release version and download integrity. Re-download or intentionally prepare a new version; do not edit hashes to suppress the error. |
| Output destination exists | Choose a fresh output directory. Do not delete delivered results to make room for a rerun. |
| Missing `terra`, `sf`, or `exactextractr` | Restore/install the release dependencies and verify its supported R/system-library combination. |
| Large blank area | Check domain, historical screen and valid-data coverage. Missing does not mean zero. |
| Province unclassified | Inspect coverage and the harvest denominator. The tool deliberately withholds unsupported classifications. |
| Very high pixel ratio | Inspect absolute mass and the review flag. Near-zero denominators and small floating-point residuals can produce large ratios. |
| Different output from a newer release | Compare input hashes, configuration and version before interpreting a scientific change. |

## What constitutes monitoring

A rerun with unchanged inputs demonstrates reproducibility, not restoration success. Monitoring requires independent observations, a defined intervention and counterfactual, and an agreed evaluation design. Do not use the recovery envelope directly for carbon-credit accounting.
