# Cross-check of the raw APN files of the project page

Date: 2026-10-08. Source: https://langevin.univ-tln.fr/data/apns/ (the data
page of Beierle, Langevin, Leander, Polujan and Rasoolzadeh). The downloads are
in `~/.cache/bfa-data/langevin/`, outside the repository. `files.tsv` gives the
size, date and SHA-256 of each file.

## Question

Does any public n = 8 data file of the authors hold a quadratic APN function
whose CCZ class is absent from the local σ index? In particular, does any
record have the σ of one of the 553 census classes?

## Method (`crosscheck.jl`)

For each record of each file, the script builds `SBox{8}`, checks the APN
property and the degree, calculates `VBFCatalog.sigma_hash`, and looks the hash
up in the set of all n = 8 index hashes (3,808,491 distinct) and in the 553
census hashes. A spot check compares the fast σ path with the reference
`sigma_hash` on about 0.1% of the records. The run is threaded and resumable.
The full run took 82 minutes with 5 threads.

`new_apns.txt.gz` was not downloaded again. Its gzip trailer has the same CRC-32
and size as the already verified `new_apns.txt`.

## Results (`results/summary.tsv`)

| File | Records | Distinct σ | σ not in index (records) | σ in the 553 |
|---|---:|---:|---:|---:|
| apn-11888039-may-2025-8.out | 11,888,039 | 3,770,201 | 546 (596) | 0 |
| apn-11888039-may-2025-8.txt.gz | 11,888,039 | 3,770,201 | 546 (596) | 0 |
| sage-02-11.tar | 715,672 | 715,672 | 0 | 0 |
| sage-10-01.tar | 845,458 | 845,458 | 0 | 0 |
| sage-10-10.tar | 766,233 | 766,233 | 0 | 0 |
| sage-18-09.tar | 681,211 | 681,211 | 0 | 0 |
| sage-25-08.tar | 783,637 | 783,637 | 0 | 0 |
| sage-29-03.tar | 1,361,417 | 1,361,417 | 0 | 0 |
| sage-30-11.tar | 680,623 | 680,623 | 0 | 0 |
| sage-31-01.tar | 1,063,658 | 1,063,658 | 0 | 0 |
| sage.tar | 716,376 | 716,376 | 0 | 0 |

- All 31,390,363 records parse. All are quadratic APN functions.
- The spot checks found 0 mismatches in 31,478 checks.
- The union of all files has 3,770,201 distinct σ. The sage snapshots are
  subsets of the raw file.
- The raw file has fewer distinct σ (3,770,201) than the published list
  (3,775,599). Thus it is older than the published list. 38,836 index σ do not
  occur in any of these files.

## Verdicts

1. **The 553 census classes: 0 coincidences in all files.** The novelty of the
   553 holds also against the authors' raw data.
2. **546 classes are public but absent from the published list.** The May 2025
   raw file holds 546 distinct σ (596 records) that are absent from the index,
   that is, from the published 3,775,599 list and from every other corpus. A σ
   that is absent proves CCZ-inequivalence to every indexed function. These 546
   classes are in `raw_only_546.tsv` (σ, first record number, LUT). Checks:
   - σ recalculated for all 546 and equal to the stored value;
   - all have differential uniformity 2 and degree 2;
   - pairwise distinct σ;
   - 0 index rows by direct SQL;
   - disjoint from the 553.

Thus the number of publicly available known classes is at least
3,808,491 + 546 = 3,809,037. These 546 classes are not in the catalog. To add
them is a catalog change, and it must go through the catalog gate.

## Commands

```
make -C census/quadratic_apn8/crosscheck_raw help
make -C census/quadratic_apn8/crosscheck_raw download            # several GB to ~/.cache/bfa-data/langevin/
make -C census/quadratic_apn8/crosscheck_raw check threads=5     # about 82 min
make -C census/quadratic_apn8/crosscheck_raw check limit=2000 threads=5   # quick test
julia --project=$ROOT census/quadratic_apn8/crosscheck_raw/export_raw_only.jl
```
