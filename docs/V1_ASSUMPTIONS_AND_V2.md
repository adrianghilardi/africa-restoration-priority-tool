# Version 1 scope, assumptions and next development

Version 1 is a **reproducible landscape-screening release** for Congo Basin and KAZA. It answers a bounded planning question: where do woodfuel pressure, conditional woody-biomass recovery and contextual risks justify closer restoration assessment? Its scope is complete when the documented inputs, calculations, outputs, examples and rerun checks are delivered. Field-level approval and causal intervention forecasting are different tasks, not claims made by this release.

## Explicit v1 assumptions

| Choice | V1 treatment | Consequence for interpretation |
| --- | --- | --- |
| Upstream baseline | Supplied capped Congo and KAZA MoFuSS BAU runs; two realizations each | Results inherit those demand, land-use and model assumptions. The tool does not rerun the simulator. |
| Recovery start/end | Post-harvest 2030, advanced 20 years to 2050 | A conditional future-state envelope, not recovery observed since 2000. |
| Recovery mechanism | Run-specific Chapman–Richards A/k/m; zero subsequent harvest, stable land use, no added mortality | Not a calibrated ANR intervention or realizable carbon credit benefit. |
| Growth uncertainty | k multipliers 0.75 and 1.25; two supplied BAU realizations | Deterministic sensitivity and small-ensemble range, not probability bounds. |
| Ecological screen | Historical 2001 forest and woody-savanna classes included by default; `include_woody_savanna=true` | Native woodland recovery is visible, but this is neither present-day eligibility nor permission to afforest natural open ecosystems. A forest-only sensitivity remains available. |
| Screening thresholds | Recovery 10 MgDM/ha and depletion share 0.25; alternatives 5/10/20 and 0.15/0.25/0.35 reported | Transparent operational cut-offs, not fitted ecological constants. |
| Province pressure classes | Landscape-specific top-tercile NRB magnitude and fNRB, 2020–2050 | Relative within-landscape priorities; incomplete/invalid cases remain unclassified. |
| Climate | SSP2-4.5 and SSP5-8.5; native 0.25-degree CCKP ensemble data | Exposure context, not parcel-scale forecasts or uncalibrated growth corrections. |
| People and livelihoods | Native 0.25-degree SSP2/SSP5 population crossed with latest observed national poverty below $3/day (2021 PPP), under constant-rate and half-rate sensitivities | Uniform national-rate screening proxy, not local poverty measurement, beneficiary counts or a calibrated well-being forecast. Observation years differ. |
| Implementation | No costs, consent, tenure, displacement or governance inferred from biomass | A shortlisted area requires a separate feasibility and safeguards assessment. |

The user authorized best-judgment choices for version 1. These choices are stated in the configuration and methods so the next version can change them transparently. They are not described as TNC field validation or approval.

## Prioritized v2 work

1. **Current ecological eligibility and safeguards.** Agree landscape-specific degraded-ecosystem definitions, native woodland/open-system treatment and no-go rules; add dated evidence with explicit uncertainty. Preserve separate conservation, tenure and consent checks.
2. **Locally relevant livelihoods and well-being.** Replace or supplement public screening proxies with TNC-preferred indicators and agreed scenario narratives; establish whether the information supports province or finer-scale inference.
3. **Feasible intervention scenarios.** Simulate partial harvest reductions, demand displacement, leakage and management constraints rather than treating the no-harvest envelope as an expected effect. Add costs where defensible.
4. **Growth and climate response.** Confirm supplied growth lineage and evaluate independent evidence. Calibrate any climate–growth relationship before coupling it; expand uncertainty where supporting data exist.
5. **Participatory evaluation and monitoring.** Review sample candidate areas with landscape teams and communities; define independent validation and an intervention/counterfactual monitoring design.
6. **Hydrology and wildfire.** Add these as explicitly scoped modules after their ecological mechanism, source rights and decision use have been agreed.

Each new version should retain the input manifest, configuration, methods changes, tests and comparison with the preceding release. A change in defaults should never silently replace the archived v1 evidence.
