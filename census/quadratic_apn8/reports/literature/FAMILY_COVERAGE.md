# Dimension-eight family coverage and candidate confirmation

Literature cutoff: 2026-10-09. This extends [LITERATURE.md](LITERATURE.md),
the original-source [corpus rebuild](../../rebuild_corpus/REPORT.md), and the
[discovery audit](../../../../packages/VBFSearch/AUDIT.md). It is an evidence report for
**VBFCatalog**, not a second curated catalog.

## Confirmed computational result

The complete finite audit checked **72,281 parameter choices**, representing
**59,768 different exact LUTs**. Of these LUTs, **3,280 are APN**. The parameter
rows contain 3,563 APN occurrences, including eight occurrences of nonquadratic
power functions. Counts of occurrences, exact LUTs, signatures and equivalence
classes are different quantities.

Every quadratic APN produced by the audited domains has one of **21 signatures
already present in the source-rebuilt reference**. Reconciliation with the five
historical candidate lists recomputed the absence count as **110,868 distinct
signatures** and found **zero overlaps** with these 21 family signatures.

Therefore, the 110,868 verified quadratic APNs are pairwise CCZ-inequivalent and
CCZ-inequivalent to every quadratic member of the audited domains. This is a
finite computational result using a mathematically justified separating
invariant. It is **not a blanket assertion of historical novelty**.

| Executable domain | Parameter choices | APN occurrences | Quadratic signatures |
|---|---:|---:|---:|
| All powers x^d, d=1..255 | 255 | 24 | 2 |
| Absolute-trace cubic, all nonzero a | 255 | 255 | 2 |
| Zhou–Pott, all coprime i, all j and nonzero alpha | 120 | 40 | 2 |
| Taniguchi, all coprime i, all a and nonzero b | 480 | 170 | 3 |
| Carlet, all monic projective coefficients | 8,192 | 2,720 | 1 |
| Göloğlu F1, both admissible indices | 2 | 2 | 1 |
| Calderini–Li–Villa F1, all indices and alpha | 32 | 10 | 1 |
| Calderini–Li–Villa F2, all alpha | 16 | 5 | 1 |
| Li–Zhou–Li–Qu bivariate formula | 1 | 1 | 1 |
| Shi–Peng–Zheng, complete parameter period | 4 | 4 | 2 |
| Calderini et al. Theorem 6.2 formula | 512 | 20 | 1 |
| Calderini et al. normalized F1 grid | 61,440 | 280 | 4 |
| Calderini et al. normalized F2 grid | 960 | 20 | 3 |
| Generalized isotopic shift, published Table 1 | 12 | 12 | 12 |

The 21 signatures are a **union**, not the sum of the final column. Equal
signatures do not prove equivalence or justify merging classes. Here equality
is used only to establish that the family signature is already in the
reference. A candidate whose signature is absent from that reference then has
a different signature from every audited family member. No converse is used.

For quadratic APNs, [Yoshiara 2012](https://emis.muni.cz/journals/JACO/Volume35_3/p72q12l317124710.fulltext.pdf)
proves that CCZ equivalence coincides with EA equivalence. The ortho-derivative
differential and absolute-Walsh spectra are EA invariants. Their differing
digests imply differing serialized invariants; no hash-collision assumption
is needed in this direction.

[Yoshiara 2016, Theorem 2](https://link.springer.com/article/10.1007/s10801-016-0680-z)
also proves that a quadratic APN CCZ-equivalent to an APN power function must
be EA-equivalent to a Gold function. Gold indices k=1,3,5,7 are independently
verified in the reference comparison. This excludes **all APN power functions**
for these corpus-absent candidates, including nonquadratic powers.

## Scope of the parameter coverage

[family_coverage.toml](family_coverage.toml) records the applicable families,
dimension restrictions, reduction arguments, general search methods and
remaining data gaps. Its numbering is explicit: F1–F15 refer to the 2021 survey;
other papers reuse these names.

The finite checks include invalid parameter choices, tested directly against
the APN definition. All bivariate maps use GF(16), modulus x^4+x+1 (`0x13`),
with `(x,y)` packed as `x | (y << 4)` except the existing Shi constructor,
which packs the coordinates in the reverse order. This basis change preserves
EA equivalence. Univariate formulas use GF(256), modulus `0x11d`.
Frobenius indices run through a complete residue period. The normalized F1/F2
grids additionally include non-coprime indices studied in the 2026 criteria
paper. Zero c would make all points `(0,y)` have the same image, so cannot be
APN; it is omitted from those grids.

Two useful published reductions extend the finite coverage:

- [Göloğlu–Kölsch, Theorem B.3](https://escholarship.org/content/qt8h67z6mh/qt8h67z6mh_noSplash_724b3bafc5bc02dd37a7ae506d09ef41.pdf)
  makes every even-m Carlet function EA-equivalent to Zhou–Pott. Together with
  the 2021 survey's section 4, this covers the hexanomial/pentanomial family
  without enumerating every literal coefficient and basis presentation.
- [Kölsch 2024, Theorem 2.4](https://arxiv.org/html/2402.11329v2)
  reduces Calderini–Li–Villa F1 to Göloğlu's original family when 3 does not
  divide m. Here m=4. The direct finite checks provide additional verification.

Most remaining named families in the ledger require n divisible by three,
odd m=n/2, m=2 modulo four, or a different sporadic dimension. Those exclusions
are theorem-domain arguments, not sampled searches.

## Relationship to the existing library and catalog

The audit **reuses** VBF finite-field and construction APIs, the existing paper
constructors, VBFCatalog's registered corpora, and the earlier independent
source rebuild. It adds only missing CLV evaluation and evidence accounting.
The original independent verifier is intentionally separate from VBF's APN
and signature routines so an implementation error is not checked by itself.

`confirm_history.jl` also uses **VBFCatalog.sigma_hash** and
**VBFCatalog.classify_ccz**, with catalog coverage checks enabled, to resolve
each audited family signature to its existing catalog source/member. These
results are saved as `catalog_crosscheck.toml`. A `:sigma_match` retains its
existing meaning: an invariant match awaiting an equivalence witness.
The completed crosscheck matched **21/21** audited signatures to existing
catalog source/member locations. No duplicate family rows are imported.

VBFCatalog's `sigma_coverage` already tracks whether registered corpora were
indexed. The family ledger answers the additional question of whether all
parameters of a published formula have been audited. It does not replace that
table, the corpus registry, the catalog's content addressing, or its update
and reconciliation APIs. The rebuilt reference remains immutable to preserve
the earlier experiment certificates; updating a working catalog and retaining
a historical comparison snapshot serve different purposes.

The independently found 546 omissions from the older signature index and the
one public Galissant representative remain explicit catalog/index maintenance
items. Catalog imports must use the existing declarative sources/importers,
update the tracked database and expected counts together, and pass the catalog
rebuild/check gate. Research candidates should enter through that same path
with evidence and provenance, not through another ad hoc catalog.

## Reproduce and verify

Run from the repository root; Julia >=1.12:

```bash
julia --compiled-modules=no --startup-file=no --project=. \
  census/quadratic_apn8/reports/literature/test_families.jl
julia --compiled-modules=no --startup-file=no --project=. \
  census/quadratic_apn8/reports/literature/test_verify_families.jl

julia --compiled-modules=no --startup-file=no --project=. \
  census/quadratic_apn8/reports/literature/check_families.jl /tmp/apn-family-check
julia --startup-file=no \
  census/quadratic_apn8/reports/literature/verify_families.jl /tmp/apn-family-check
julia --compiled-modules=no --startup-file=no --project=. \
  census/quadratic_apn8/reports/literature/confirm_history.jl /tmp/apn-family-check
```

The checker expects the source-rebuilt reference at
`census/quadratic_apn8/results/signature_rebuild/`, its public supplement, the
private paper inputs already used for formula review, and these two additional
papers under `census/quadratic_apn8/results/literature_family_coverage/sources/`:

```bash
curl -fL https://dergipark.org.tr/en/download/article-file/5480102 -o carlet_2026.pdf
curl -fL https://arxiv.org/pdf/2402.11329v2 -o kolsch_2024_v2.pdf
```

Their expected hashes are in the ledger. Download into the stated sources
directory. Paper contents and generated outputs are ignored; only code,
descriptive coverage and digests are tracked. Missing copyrighted inputs must
be obtained from their primary sources, not reconstructed from hashes.
The catalog crosscheck additionally needs the catalog's existing sigma index;
if absent, build it using `VBFCatalog.build_sigma_index!(VBFCatalog.load_catalog())`.

The completed local run is at
`census/quadratic_apn8/results/literature_family_coverage/finite_domains/`:

- `parameters.tsv`: every parameter tuple and its exact LUT/evidence key;
- `luts.tsv`: every different LUT, accepted properties or a four-solution
  non-APN witness, recomputed signature and reference membership;
- `report.toml`: completion, counts, dependency/input hashes and reference scope;
- `candidate_separation.toml`: exact candidate inputs, reused independent
  verification digests and the recomputed candidate/family separation;
- `catalog_crosscheck.toml`: existing catalog API results and catalog/index hashes.

The standard-library verifier replays **every accepted APN**, recomputes its
degree and quadratic signature, verifies **every rejection witness**, and
crosschecks parameter accounting. It does not independently rederive formulas
from publications or query SQLite membership; those are distinct audit steps.
`confirm_history.jl` rechecks membership in SQLite and reuses the earlier
500,090-record candidate verification only at matching digests, independently
rechecking the 463 inputs not covered by that older report.
The focused tests passed **173 assertions**, including formula special cases,
root criteria, rejection witnesses and tampered evidence.

The finite check itself took approximately five seconds after package loading
on this machine, using one thread. Large corpus rebuilding and checking newly
obtained datasets are separate costs that scale with the supplied records.
The ongoing 30-thread V5 search and its frozen executable sources were unchanged.

## What still prevents an unconditional novelty claim?

1. **The full Baudrin–Galissant–Perrin 2026 switching output is unavailable to
   this audit.** The published example is included. Obtain the complete list,
   or an author-supplied comparison with adequate provenance, and independently
   recompute it before claiming separation from that work. The
   [announced results](https://314gali.github.io/files/2026-04-03_APN_exploration_C2.pdf)
   explicitly fall within quadratic CCZ scope.
2. **The literature ledger is a reviewed scope, not a proof that every
   publication was found.** Additional published concrete representatives must
   be added through the existing catalog/source workflow and checked. A
   nonquadratic non-power target requires general CCZ testing, a verified
   quadratic representative, or an appropriate theorem; degree alone cannot
   exclude CCZ equivalence.
3. **General search criteria are not classified families.** Arbitrary QAM,
   switching, extension and linearized-polynomial coefficient spaces have not
   been exhausted. Generating a new class with an old search method does not
   invalidate novelty of the individual class. Do not claim a new infinite
   family or exhaustion of such a method without additional arguments.

A defensible current statement is: **110,868 pairwise CCZ-inequivalent
quadratic APN representatives are absent from the specified source-rebuilt
reference and excluded from the documented audited construction families and
all APN power functions. Historical novelty remains conditional on the
remaining literature/data coverage.** This is stronger than catalog absence
alone and does not purport to classify all dimension-eight APNs.
