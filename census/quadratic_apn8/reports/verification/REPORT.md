# Verification of the 553 new quadratic APN class claims (n = 8)

Date: 2026-10-08. Scripts and logs are in this directory. The original working
directory was `papers/2025/Beierle_202508/results/class_count/verification/`.
The commands below run from that directory (or from a directory that holds
`s1.tsv`, `chunks/` and `all40_new.tsv`).

## Claim and logic

Each function in `../../new_classes_553.tsv` is CCZ-inequivalent to every
known quadratic APN function on F_2^8, because its σ signature is absent from
`ccz_sigma_index.sqlite`.

- σ(F) = (differential spectrum, absolute Walsh spectrum) of the
  ortho-derivative π_F.
- σ is an EA invariant (Canteaut–Couvreur–Perrin). EA = CCZ for quadratic APN
  functions (Yoshiara). Thus an absent σ proves inequivalence to every indexed
  function.
- A σ match proves nothing. A match needs an exact test (Task 4).

## Task 1 — full index integrity (`verify_index.jl`, 3,401 s, 6 threads)

For every member of every n = 8 source, the script decodes the function,
calculates σ again, finds the exact row (hash, source, member_idx) in the index,
and calculates the differential uniformity. Per source, it compares the counts
of store, catalog and index, the index continuity, duplicates, orphans and the
store SHA-256.

| Source | Count (store = catalog = index) | Rows matched | Problems |
|---|---:|---:|---|
| beierle2025_n8 | 3,775,599 | 3,775,599 | 0 |
| simonberg_gf4_n8 | 196,863 | 196,863 | 0 (store file SHA differs, see below) |
| beierleleander2022_n8 | 12,923 | 12,923 | 0 |
| yuwangli2014_qam_n8 | 8,179 | 8,179 | 0 |
| beierleleanderperrin2022_n8 | 6,368 | 6,368 | 0 |
| yuperrin2022_qam_n8 | 5,412 | 5,412 | 0 |
| edelpott2009_n8 | 22 | 22 | 0 |
| wengtangong2013_n8 | 10 | 10 | 0 |
| taniguchi2019_n8 | 2 | 2 | 0 |
| functions table (n = 8, quadratic APN) | 67 | 67 | 0 |
| **Total** | **4,005,445** | **4,005,445** | **0** |

- All 4,005,445 members are APN.
- The recalculated hashes have 3,808,491 distinct values. This number is equal
  to the index value and to Beierle et al. 2025, Theorem 5.1.
- None of the 553 new hashes is in the recalculated set (0 / 553). This check
  does not use the index file.

**simonberg_gf4_n8 store SHA** (`rebuild_store_sha.jl`): the file SHA-256 is
716e469d…, and the catalog value is 07fc9575…. SQLite 3.51.2 wrote the file;
SQLite 3.53.2 wrote the other stores. A rebuild of the store from the same
196,863 encodings, with the statements of `build_corpus_store!`, gives
07fc9575…. Thus the member data is identical, and only the catalog hash is out
of date.

**Raw published file** (`verify_raw_beierle.jl`, 599 s): all 3,775,599 lines
of the Zenodo file `new_apns.txt` (3,395,265,744 bytes) have a LUT identical to
the decoded corpus member (0 mismatches). This check is necessary, because the
importer used `encode_quadratic(...; verify = false)`.

## Task 2 — non-quadratic rows (`nonquad_relations.jl`, `verify_nonquadratic.jl`)

The catalog has three non-quadratic n = 8 APN rows (ids 43, 581, 634). All
three are x^57 or x^228 under one of the two field moduli. Thus they are one
CCZ class (the Kasami class).

`ccz_equivalent_quadratic_function` (via `enumerate_ccz_class`) did not finish
in 57 minutes. **Status: open.** The literature states that this class contains
no quadratic function. A separate task closes this gap with sboxU.

## Task 3 — the 553 functions (`verify_new553.jl`, 5 s)

- Two independent decoders agree on 553 / 553.
- 553 / 553 have degree 2 and differential uniformity 2.
- 553 / 553 recalculated hashes are equal to the stored hashes.
- A direct SQL count gives 0 rows for 553 / 553 hashes (at any n). The same
  query finds 5 / 5 random indexed hashes (positive control).
- The 553 hashes are pairwise distinct. Thus the 553 functions are pairwise
  CCZ-inequivalent.

## Task 4 — positive control for the "known" direction (`ea_check.jl`)

`analyze_known.jl` regenerates the 1,108 known hits, and it reproduces
`all40_new.tsv` byte for byte. Of a random sample of 30 known hits, 10 pairs
were completed before the stop request. All 10 are EA-equivalent to the matched
member (256 mappings each, 446–613 s for each pair). No σ match was
inequivalent.

## Verdicts

- **(a) The index is complete and consistent for the data in the repository.**
- **(b) The 553 novelty claims hold against all 10 indexed sources.**
- **(c) Caveats:**
  1. Novelty is relative to the indexed sources. These sources agree with the
     published total of known classes.
  2. The raw files of the 8 smaller corpora are not in the repository.
  3. The x^57 class is not decided by computation (Task 2).
  4. The EA control covers 10 pairs, not 30.

## Commands

```
julia -t 6 --project=$ROOT verification/verify_index.jl full du            # 3,401 s
julia --project=$ROOT verification/rebuild_store_sha.jl simonberg_gf4_n8
julia -t 3 --project=$ROOT verification/verify_raw_beierle.jl              # 599 s
julia --project=$ROOT verification/nonquad_relations.jl
julia --project=$ROOT verification/verify_new553.jl                        # 5 s
julia --project=$ROOT verification/analyze_known.jl verification/regen s1.tsv chunks/c1*.tsv
for s in 0 1 2 3; do julia --project=$ROOT verification/ea_check.jl $s 4 & done  # 8–10 min per pair
```
