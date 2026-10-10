# Exhaustive corpus rebuild, 2026-10-09

The original datasets were fetched and all signatures recomputed. The imported
corpora agree with their original source LUTs and signatures. The fresh public
comparison baseline has **3,809,037 distinct signatures**.

The subsequent [literature survey](../reports/literature/LITERATURE.md) found
one further publicly posted quadratic APN representative in Galissant's 2026
slides. It is absent from this baseline and the checked candidates. The
supplement is retained separately; all counts below refer to the original
hash-bound rebuild inputs. The full announced switching results remain an
unresolved literature comparison source.

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
| Search/public matches proved EA-equivalent by explicit maps | **61** |
| Unresolved search/public equivalence checks | 0 |
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
match among the dump records with that signature. **All 61 have now been
proved EA-equivalent to public representatives**, by native partition
refinement followed by independent verification of each explicit map on
all 256 graph points. Each map preserves the output subspace and has
bijective input and output blocks, so it certifies EA equivalence and hence
CCZ equivalence. No check timed out or remained inconclusive. These 61
search records represent previously public classes, despite their absence
from the old index.
The remaining **109,882 search signatures** are absent from the rebuilt
baseline. All 388,343 records tagged `known` match it.

The union of `desk1/found.tsv`, `new_classes_553.tsv`, `new_classes_extra.tsv`
and `new_classes_trial_773.tsv` contains 498,840 distinct signatures, of which
388,404 match the public baseline and 110,436 are absent. There are 787
duplicate records across these input files. The subsequent [consolidated audit](../../../packages/VBFSearch/AUDIT.md) also checked the now-available
463-record hyperplane file. It adds exactly 432 distinct absent signatures,
reconciling the screenshot's **110,868** whole-study total. The four-file numbers
in this report retain their original scope; the updated five-file reconciliation
and verification methods are in `discovery/results/history/history.toml`.
The exact checked input hashes are saved in the corresponding reports.

The verifier independently checks Boolean degree two and rank seven of every
nonzero polar map (the quadratic APN criterion), derives its annihilator, and
computes differential and absolute Walsh spectra. It calls no VBF verification
or signature routines. VBF polynomial/compact decoders and the Taniguchi
constructor remain explicit dependencies. The focused tests also cover
valid affine witnesses, forged maps, singular blocks, an output-subspace
violation and correct handling of interrupted versus exhausted searches.
All **142 focused tests pass**; the standalone verifier also rechecked all
61 saved witnesses without loading VBF.

Different signatures certify CCZ-inequivalence between quadratic APN functions,
using [Yoshiara's equivalence theorem](https://emis.muni.cz/journals/JACO/Volume35_3/p72q12l317124710.fulltext.pdf)
and the EA invariance of the ortho-derivative spectra.
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
- `equivalence_checks.toml`: all 61 explicit EA graph maps, embedded candidate/
  public LUTs and their hashes, source pointers, search budgets and code hashes.
- `equivalence.log`: per-candidate search outcomes. Run `make verify-witnesses`
  in this workflow directory to check every map without loading VBF.
- `tests.log`, `fetch.log`, `stored.log`, `raw.log`, `comparison.log`,
  `candidates.log`: execution logs.

The baseline SQLite SHA-256 is
`0eed9fb5d3a70bd24b8c8c9eefa61b0b882b9cd540dd06cda0cd430444f7b603`.
