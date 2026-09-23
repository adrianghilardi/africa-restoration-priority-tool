# Methods and interpretation — v1.0.0

## Scope

This is a postprocessor of the supplied Congo Basin capped and KAZA MoFuSS BAU runs at nominal 1 km resolution. Each landscape has two realizations. It combines pressure, conditional recovery, climate exposure and a separate social-context sensitivity for landscape screening; it does not fit a new intervention model or rerun DINAMICA EGO.

The analysis retains physical quantities instead of collapsing unlike evidence into a weighted index. Province pressure classes guide broad investigation; pixel recovery/depletion layers help inspect possible locations; climate and social information qualify the assessment. None alone establishes eligibility, implementation feasibility or causality.

## Dates and accounting

The run's annual index defines the frame-to-year mapping. With a 2000 start, 2030 is frame 31 and 2050 frame 51. `Growth` denotes within-year stock after growth and before harvest; `Growth_less_harv` is post-harvest stock. File labels alone are not treated as sufficient timing evidence.

**Recovery window:** start from post-harvest 2030 and advance 20 years to 2050. Recovery-window BAU harvest sums 2031–2050 inclusive. Net depletion is `max(post2030 − post2050, 0)`; its ratio to this harvest is a screening diagnostic, not the investment fNRB metric.

**Investment window:** 2020–2050, following the inspected MoFuSS postprocessor's v3-window convention: `NRB = max(Growth2020 − post2050, 0)`, with harvest summed over 2020–2050 inclusive. This long-window stock-depletion quantity is not a sum of separately truncated annual deficits. Ratios above one are retained and flagged, not silently capped.

The input audit detected duplicated legacy period NRB files and discrepancies in some legacy stock-year labels. This tool consequently recomputes from dated annual stock/harvest rasters, not inherited result columns. That correction does not assert that every upstream report or simulation product has been revised.

## Mass, density and mapped area

MoFuSS stock and harvest are model-accounting Mg dry biomass per nominal cell. The supplied 1,000 m configurations use a nominal 100 ha density divisor, checked against the run's resolution metadata. EPSG:3395 World Mercator is not equal area. Province NRB/harvest sums retain model cell masses with exact fractional boundary weighting. Recovery densities are separately multiplied by geodesic ground-cell hectares to produce mapped-area recovery totals. These two accounting bases must not be mixed.

The supplied cTrees stock documentation specifies Mg CO2/ha despite `AGC` in filenames. Conversion is `MgCO2/ha × 12/44 ÷ 0.47 = MgDM/ha`. The 2000 and 2025 snapshots are cropped, bilinearly projected to the model grid and masked to its domain; negative stock estimates become missing. Their difference is observed-data context, not independent validation of a model initialized using related data.

The supplied growth readme gives `AGB(age) = A × (1 − exp(−k × age))^m`, with raw A/k/m scale factors 0.1/0.0001/0.001. This tool uses the exact growth grids embedded in each run, including Congo's run-specific capacity treatment, instead of substituting newly supplied global A values. These inputs are not counted twice as independent cTrees and NASA regrowth constraints.

## Conditional recovery

For valid starting biomass B below A, the equivalent-age advancement is:

```text
B(t) = A × [1 − (1 − (B/A)^(1/m)) × exp(−k × t)]^m
recovery = B(20) − B
```

Starting stock at/above A is preserved, not reduced to a fitted capacity. Missing/negative B or invalid A, k or m produces missing recovery. Tests cover zero stock, zero horizon, saturation, monotonicity and sequential/direct equivalence.

Recovery assumes no further harvest, stable land use, no added fire or other mortality, and unchanged growth conditions. It is not an estimated ANR impact, additional carbon benefit or proof that harvest can be displaced without leakage. k multipliers of 0.75 and 1.25 are deterministic sensitivity cases, not climate scenarios or assigned probabilities. Variation across the two BAU realizations changes starting stock while retaining the run-level growth grids; it does not reconstruct every simulator parameter draw.

## Historical ecological screen

V1 includes historical forest and woody-savanna classes from the run's 2001 MODIS-based lookup (`include_woody_savanna=true`). This makes native woodland recovery context visible in KAZA. A forest-only sensitivity is available. Natural grassland and other open ecosystems are not automatically targets for tree planting; neither screen establishes current ecosystem condition, tenure, no-go rules or community agreement.

Six pixel classes distinguish other historical land cover, low recovery, recovery without BAU depletion, recovery with depletion, high-depletion-share recovery, and mass-balance/attribution review. Default screening cut-offs are 10 MgDM/ha recovery and 0.25 depletion share. They are transparent operational choices, not fitted ecological constants. The tool reports 5/10/20 MgDM/ha crossed with 0.15/0.25/0.35 for threshold sensitivity. These classes differ from the four province pressure classes.

## Province pressure typology and spatial summaries

Administrative geometry is intersected with the relevant TNC interest zone. Each landscape separately uses the top-tercile cut-point (R quantile type 7) for cumulative NRB and fNRB among valid province intersections. Values equal to a cut-point are high; zero burden/intensity is never high. High/high = Critical; high NRB/low fNRB = Major supply-shed; low NRB/high fNRB = Fragile/local; low/low = Lower priority. This retains the rule in the linked charcoal strategy; ties can place more than one third above the cut-point.

fNRB is aggregated NRB divided by aggregated harvest, not a mean of pixel ratios. Realizations are first averaged cellwise with complete-data semantics. Classification is withheld for undefined/out-of-range ratios or less than 99% coverage in the investment-data and model-domain checks. Missing data are not zero opportunity. Large pixel ratios over tiny denominators require inspection of absolute mass and numerical residuals, not automatic ecological interpretation.

Exact fractional-cell coverage is used for province, ecoregion and TNC-zone summaries. The compiled exactextractr `sum` operation is checked against known spatial examples; see <https://isciences.gitlab.io/exactextractr/>. Zone sets overlap and must not be added together. Recovery total is withheld when no valid recovery area exists. Coverage and source boundaries remain visible.

V1 replaces inherited administrative geometry with geoBoundaries gbOpen country datasets and inherited country-split ecoregions with fresh RESOLVE 2017 geometry. The ecoregions are selected/cropped to the model rectangle without GADM country boundaries. Recomputed summaries therefore must not be expected to exactly equal legacy-GADM province or country-split ecoregion summaries. Country-specific boundary source licences are retained.

## Climate context

`CLIMATE.md` specifies the CCKP CMIP6 selection: SSP2-4.5/SSP5-8.5, 2020–2039 and 2040–2059 relative to 1995–2014, ensemble p10/median/p90 and historical medians. Native 0.25-degree temperature, precipitation and consecutive-dry-day grids remain contextual exposures; no uncalibrated climate multiplier changes growth. Rainfall anomalies are millimetres, not percentages. A spatial mean of a percentile grid is not a percentile of a landscape-wide ensemble mean. Neither pathway is assigned a probability.

## Population well-being sensitivity

`SOCIAL_CONTEXT.md` documents a deliberately simple, separate view: native CCKP/SEDAC SSP2 and SSP5 population density, two period means, and latest available national World Bank WDI poverty below $3/person/day in 2021 PPP. Country reference years remain explicit. The module crosses each population pathway/period with the last observed national rate and half that rate, independently of climate forcing.

Population is density × geodesic area × exact polygon coverage. The poverty exposure proxy is scenario population × national poverty fraction × 1 or 0.5. It assumes uniform national rates; it is not observed local poverty, expected beneficiaries, an SSP-calibrated poverty forecast or a causal restoration effect. Aggregate proxy results require 99% national-context population coverage; missing rates never become zero. Natural Earth country geometry is used independently of province ranking.

## Reproducibility versus validation

Input hashes, tests, invariants and portable reruns establish computational reproducibility for the tested environment. They do not establish ecological performance, local eligibility or intervention impacts. Actual v1 verification evidence belongs in the release acceptance report, not inferred from a preceding review run. Field validation, feasible harvest/displacement scenarios, locally preferred well-being data, current land-use/no-go evidence, hydrology and wildfire are prioritized next developments.
