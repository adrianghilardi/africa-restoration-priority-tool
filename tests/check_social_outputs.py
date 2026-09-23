"""Independent CSV algebra and repeat-output verification; optional second directory."""
import csv
import hashlib
from pathlib import Path
import sys

root = Path(sys.argv[1])
rows = list(csv.DictReader((root/"tnc_zone_social_scenarios.csv").open(encoding="utf-8-sig")))
assert len(rows) == 48, "Expected 2 regions x3 zones x2 periods x2 population x2 poverty cases"
keycols = ["region","zone_layer","zone_name","population_scenario","population_period"]
index = {tuple(r[k] for k in keycols)+(r["poverty_sensitivity"],):r for r in rows}
assert len(index) == len(rows), "Duplicate output keys"
for row in rows:
    assert float(row["modelled_population"]) > 0
    assert .99 <= float(row["national_context_population_coverage"]) <= 1.00001
    if row["poverty_sensitivity"] == "half_national_rate":
        base=index[tuple(row[k] for k in keycols)+("constant_national_rate",)]
        assert float(row["modelled_population"]) == float(base["modelled_population"])
        for field in ["population_weighted_national_poverty_context_pct","poverty_exposure_proxy_not_beneficiaries"]:
            assert abs(float(row[field])-.5*float(base[field])) <= 1e-12*max(1,abs(float(base[field])))
print("48 summary rows: population, coverage, unique keys, half-rate algebra passed")
detail=list(csv.DictReader((root/"tnc_zone_country_social_context.csv").open(encoding="utf-8-sig")))
assert all(r["national_poverty_pct"] and r["national_observation_year"] for r in detail), "Unmatched country poverty context"
for r in detail:
    expected=float(r["modelled_population"])*float(r["national_poverty_pct"])/100*float(r["rate_multiplier"])
    assert abs(float(r["poverty_exposure_proxy_not_beneficiaries"])-expected) <= 1e-12*max(1,abs(expected))
print(f"{len(detail)} country rows: observation coverage and proxy algebra passed")
if len(sys.argv) > 2:
    other=Path(sys.argv[2])
    selected=sorted(root.glob("*/*.tif"))+[root/x for x in ["tnc_zone_social_scenarios.csv","tnc_zone_country_social_context.csv","social_quality_checks.csv","layer_inventory.csv"]]
    assert len(selected)==12
    for p in selected:
        q=other/p.relative_to(root)
        assert hashlib.sha256(p.read_bytes()).hexdigest()==hashlib.sha256(q.read_bytes()).hexdigest(), str(p)
    print("8 population rasters and 4 data/QA tables reproduce byte-for-byte")
