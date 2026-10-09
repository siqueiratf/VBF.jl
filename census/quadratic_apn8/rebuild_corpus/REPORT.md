# Exhaustive corpus rebuild, 2026-10-09

The original datasets were fetched and all signatures recomputed. The imported
corpora agree with their original source LUTs and signatures. The fresh public
comparison baseline has **3,809,037 distinct signatures**.

| Check | Result |
|---|---:|
| Stored quadratic APN records independently recomputed | 4,005,445 |
| Original-file/constructor records scanned | 15,893,418 |
| Original quadratic APN records verified | 15,893,417 |
| Explicitly excluded nonquadratic records | 1 |
| Changed, missing, or orphan old-index rows | 0 |
| Imported corpus LUT/signature set differences from originals | 0 |
| Public signatures added beyond the old index | 546 |
| Candidate records independently verified | 499,627 |
| Candidate stored-signature mismatches | 0 |
| Distinct candidate signatures absent from the fresh baseline | **110,436** |

All nine imported corpus LUT sets match their original data. The one excluded
record is a degree-four entry in `firstQAM.py`; its input position and LUT hash
are retained in the raw QAM database. The Simon-Berg SQLite file has a stale
descriptor checksum, but all 196,863 decoded LUTs match the fetched thesis
files exactly. That metadata discrepancy was recorded without changing the
catalog.

The search's `desk1/found.tsv` contains 498,300 distinct signatures. Of its
109,943 records tagged `search`, **61 have a matching signature in the public
May 2025 dump**; all 61 are absent from the old index. None has an exact LUT
match among the dump records with that signature. Their novelty requires
equivalence testing; a matching signature alone does not prove equivalence.
The remaining **109,882 search signatures** are absent from the rebuilt
baseline. All 388,343 records tagged `known` match it.

The union of `desk1/found.tsv`, `new_classes_553.tsv`, `new_classes_extra.tsv`
and `new_classes_trial_773.tsv` contains 498,840 distinct signatures, of which
388,404 match the public baseline and 110,436 are absent. There are 787
duplicate records across these input files. This checkout's candidate inputs
do not reproduce the screenshot's whole-study count of 110,868; the screenshot's
independent audit/input manifest is unavailable. The exact checked input hashes
are saved in the candidate report.

The verifier independently checks Boolean degree two and rank seven of every
nonzero polar map (the quadratic APN criterion), derives its annihilator, and
computes differential and absolute Walsh spectra. It calls no VBF verification
or signature routines. VBF polynomial/compact decoders and the Taniguchi
constructor remain explicit dependencies. All **121 focused tests pass**.

Different signatures certify CCZ-inequivalence between quadratic APN functions.
The 110,436 absence results therefore separate those candidates from every
quadratic APN represented by this rebuilt baseline and from each other. This
is a certificate against the specified datasets, with the dependencies above;
it is not a claim to have covered all literature or justified census estimators.

Reproduce with the commands in [README.md](README.md). The generated evidence
is under `../results/signature_rebuild/`:

- `sources/provenance.toml`: download URLs, pinned Git revisions, sizes and hashes.
- `stored_*.toml`, `raw_*.toml`, and the corresponding SQLite databases:
  exhaustive coverage, independently verified signatures, LUT hashes and exclusions.
- `comparison.toml`: old-index and original-import comparisons.
- `fresh_union.sqlite`: the rebuilt baseline (`signatures(sigma_hash)`).
- `candidate_comparison.toml` and `.tsv`: all candidate verdicts and input hashes.
- `search_public_matches.tsv`: public record pointers for the 61 signature matches.
- `tests.log`, `fetch.log`, `stored.log`, `raw.log`, `comparison.log`,
  `candidates.log`: execution logs.

The baseline SQLite SHA-256 is
`0eed9fb5d3a70bd24b8c8c9eefa61b0b882b9cd540dd06cda0cd430444f7b603`.
