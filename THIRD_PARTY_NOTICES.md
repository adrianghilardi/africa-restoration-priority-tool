# Third-party notices and source-specific rights

The tool preserves separate software and dataset rights. New commissioned code is MIT-licensed; the authorized contributed data grant is described in `DATA_LICENSE.md`. The following notices apply independently. Exact downloaded/prepared files, versions and hashes are recorded in the release manifests.

## MoFuSS and software dependencies

MoFuSS source is available at <https://github.com/mofuss/mofuss>. The inspected upstream repository carries the Apache License, Version 2.0. This restoration tool is a separate postprocessor with a new implementation of its screening functions; it does not redistribute the upstream simulator as part of its source package. Any future copied upstream code must preserve the applicable upstream copyright, licence and notice requirements. Scientific lineage and the specific reference files inspected are recorded in `docs/DATA_SOURCES.md`.

R, Python and their packages/system libraries remain under their own licences. Installing them through the documented environment does not relicense them under this project's MIT grant. The environment record identifies tested versions; no bundled dependency is granted different rights by this notice.

## World Bank Climate Change Knowledge Portal

Source: World Bank Climate Change Knowledge Portal (CCKP), CMIP6 `cmip6-x0.25` collection. The provider metadata states CC BY 4.0. Retain the source NetCDF metadata, attribution and the download manifest. This release crops regional windows, converts formats and calculates zonal summaries; it does not create a finer-resolution climate projection.

- Data-use metadata: <https://climateknowledgeportal.worldbank.org/metadata>
- Archive documentation: <https://worldbank.github.io/climateknowledgeportal/README.html>
- Thrasher et al. (2022), NASA Global Daily Downscaled Projections, CMIP6: <https://doi.org/10.1038/s41597-022-01393-4>.

Credit the World Climate Research Programme, participating climate modelling groups and the Earth System Grid Federation, as well as NEX-GDDP-CMIP6 acknowledgements present in the downloaded files. Licence terms for climate do not automatically apply to all other datasets.

## Administrative boundaries: GADM exclusion and replacement rule

Legacy review inputs contained administrative geometry with GADM identifiers. GADM's terms require prior permission for redistribution/commercial use beyond the stated allowed uses: <https://gadm.org/license.html>. The project's permission for its own contributed data does not relicense independently owned GADM content. **GADM geometry is therefore excluded from the public CC BY grant and must not be redistributed without separate compatible permission.** The public-release assembler must replace it with an appropriately licensed source or explicitly establish the applicable permission before publication.

The replacement source is **geoBoundaries gbOpen**: <https://www.geoboundaries.org/index.html>. Preserve country, administrative level, boundary version/date, exact download URL, source metadata and SHA256 for each included object; credit Runfola et al. (2020), <https://doi.org/10.1371/journal.pone.0231866>. Although geoBoundaries distributes gbOpen under CC BY 4.0, country metadata can identify additional upstream terms (including ODbL 1.0 for OpenStreetMap-derived boundaries). Those country-specific source terms and notices are retained in the boundary licence inventory and are not replaced by this project's contributed-data grant. Substituting geometry changes zonal quantities and potentially tercile classes, so release outputs are regenerated with the selected open boundaries.

For OpenStreetMap-derived geometry, credit **OpenStreetMap contributors**, retain <https://www.openstreetmap.org/copyright> and the [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) notice where applicable. Other country metadata specify CC BY-SA, CC BY (including IGO variants) or public-domain sources. Consult `boundaries/manifest_adm1.csv` and its country metadata before reuse; do not treat the combined boundary collection as wholly subject to the project's new CC BY 4.0 grant.

## Historical land cover and ecoregions

The supplied MoFuSS run configuration identifies its historical land cover as MODIS, year 2001. The inspected preprocessing code identifies the MCD12Q1.061 product family, but this is not independent proof of the exact collection used in every supplied run; retain that lineage distinction instead of labelling the inherited grid as newly downloaded current data. NASA MODIS/LP DAAC data are unrestricted for subsequent use/redistribution as stated in the [official Earth Engine catalogue terms](https://developers.google.com/earth-engine/datasets/catalog/MODIS_061_MCD12Q1). Credit NASA MODIS/LP DAAC; product reference for that documented family is <https://doi.org/10.5067/MODIS/MCD12Q1.061>. The inherited land-cover grid is historical, not present-day eligibility.

Ecoregions use **RESOLVE Ecoregions 2017**, supplied by RESOLVE Biodiversity and Wildlife Solutions under CC BY 4.0 at <https://ecoregions.appspot.com/>. Credit Dinerstein et al. (2017), *An Ecoregion-Based Approach to Protecting Half the Terrestrial Realm*, <https://doi.org/10.1093/biosci/bix014>. The original provider archive is <https://storage.googleapis.com/teow2016/Ecoregions2017.zip>. Fresh provider geometry is selected/cropped to the model rectangle and reprojected, then intersected with authorized TNC interest zones by the analysis. This replaces inherited country-split ecoregion geometries; no GADM geometry is introduced through the ecoregion input. Exact source/output hashes and transformations are recorded in the ecoregion manifests.

## Social-context module

The module-specific source manifest and `docs/SOCIAL_CONTEXT.md` identify the actual provider, version, definitions and modifications. National poverty comes from World Bank WDI `SI.POV.DDAY`, below $3/person/day in 2021 PPP, under CC BY 4.0: <https://data.worldbank.org/indicator/SI.POV.DDAY>. Population comes through the CCKP `pop-x0.25` collection, derived from Jones and O'Neill (2020), NASA SEDAC, <https://doi.org/10.7927/m30p-j498>, and Jones and O'Neill (2016), <https://doi.org/10.1088/1748-9326/11/8/084003>; preserve CCKP and NASA attribution/redistribution notices. Country outlines are Natural Earth 1:50m admin-0 v5.1.1, public domain: <https://www.naturalearthdata.com/about/terms-of-use/>. These notices accompany redistributed social inputs. Aggregate context does not establish household-level poverty, vulnerability or consent.

## No endorsement or trademark grant

Scientific acknowledgement and source identification do not imply that upstream providers endorse the derived tool, its assumptions or the shortlisted locations. No licence to provider logos, institutional marks or personal data is granted by this repository.
