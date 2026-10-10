# Hyperplane studies

These bounded consumers sample catalog functions, enumerate hyperplanes, compare
admissible radical selections and inspect neighbour signatures. Restriction,
extension and admissible-count mathematics lives in VBF.QuadraticRestrictions
and VBF.QuadraticAPNTree. Optional historical inputs remain under data/apn/archive;
generated outputs go under data/working-paper/hyperplanes.

```sh
julia --project=packages/VBFWorkingPaper -e '
include("packages/VBFWorkingPaper/src/hyperplanes/check_uniqueness.jl")
check_uniqueness(n=4,samples=10,hpf=3,exhaustive=false)'
```

A neighbour graph identified through signatures describes signature buckets.
Equal signatures do not identify an equivalence class without an equivalence
check. Node-limited counts and estimates must retain their partial or statistical
status. Catalog representative queries remain consumer code pending the catalog
API consolidation.
