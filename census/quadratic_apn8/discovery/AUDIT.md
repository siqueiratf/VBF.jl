# Scientific audit and research status

Audit date: 2026-10-09/10 UTC. Implementation branch:
`feat/apn-class-orbit-exploration`. This assessment supersedes historical uses
of “new” that meant absent from the old signature index. It does not certify
literature-wide novelty or a classification of all eight-bit APNs.

## What the existing results establish

The original-source rebuild independently checked 4,005,445 stored records
and scanned 15,893,418 original-file/constructor records, with one explicitly
excluded nonquadratic occurrence. The quadratic reference contains **3,809,037
distinct signatures**, including the 546 public signatures omitted from the
old index. Its database SHA256 is
`0eed9fb5d3a70bd24b8c8c9eefa61b0b882b9cd540dd06cda0cd430444f7b603`.
The [literature survey](../reports/literature/LITERATURE.md) adds one public
quadratic representative from Galissant's 2026 slides, held as a separate
hash-bound supplement.

Reconciliation of all five historical inputs gives:

| Input | Records | Additional absent signatures in this input order |
|---|---:|---:|
| Framework `desk1/found.tsv` | 498,300 | 109,896 |
| Census coefficients | 553 | 539 |
| Extra construction | 1 | 1 |
| B52 trial | 773 | 0 |
| Hyperplane scan | 463 | 432 |
| **Union** | **500,090 records; 499,272 distinct signatures** | **110,868** |

The first four files reuse the completed independent audit at matching file
and reference digests; the 463 hyperplane records were independently checked
again by full DDT, degree, polar ranks and signature. The previously unexplained
432-record discrepancy is therefore resolved. The report is
`discovery/results/history/history.toml`, reproducible with
`review_history.jl`; `--full true` rechecks every record without reuse.

These **110,868** functions are verified quadratic APNs with pairwise different
signatures. They are mutually CCZ-inequivalent and CCZ-inequivalent to every
quadratic APN represented by the rebuilt reference and the public supplement.
This statement is mathematically justified by the invariant and equivalence
theorems, with exhaustive finite verification of their inputs. It does not
depend on a statistical census estimate. In contrast, **61** Framework search
records absent from the old index are already public classes: each now has an
independently verified EA graph witness. They must not be counted as novel.

The Framework results combine a small test, approximately two interrupted
hours and an eight-hour segment, approximately ten hours overall. The eight-hour
segment reports approximately 11,500 first-seen signatures per hour, not a
uniform sample of all classes. Its queue grew from 6,530 to 42,280 parents;
there is no evidence of exhaustion or saturation. The old runners' caps,
profile restrictions and histogram pruning further prevent a completeness
claim for that experiment.

A frozen snapshot taken during the ongoing two-hour switching run contains
19 additional signatures, plus the prior pilot's one signature. All **20**
exact LUTs were independently validated by the new importer, are quadratic APN,
and have distinct signatures absent from the reference and supplement. Evidence,
the snapshot timestamp/digests, CSV/LaTeX tables and SVG/PDF figures are under
`discovery/results/validated_search_snapshot/`. This is a partial run snapshot,
not the final two-hour result. The historical input hashes are separate from
these functions; the subsequent exact signature-set intersection with all 499,272 historical
values was empty. The combined reference-plus-study-plus-snapshot class lower
bound is therefore **3,919,926**. `classification.toml` independently rechecked
the snapshot and established exactly 20 CCZ classes within that finite set;
that exact snapshot count is not an exact count of all APN classes.

## Mathematical guarantees and limits

| Check | Valid conclusion | Limitation |
|---|---|---|
| Full DDT: every nonzero input difference has at most two solutions | APN for this exact LUT | Finite computation and exact representation must be preserved |
| Independent Boolean ANF and every polar rank seven | Quadratic APN, with a second APN criterion | Criterion applies to quadratic maps |
| Different ortho-derivative signatures, both verified quadratic APN | EA and CCZ inequivalence | Equal signatures prove neither equivalence nor identity |
| Independently verified invertible affine graph map | CCZ equivalence to its explicit target | Output-subspace preservation is additionally required for EA |
| Correct complete graph solver returns Exhausted | Computational proof of pairwise inequivalence | Solver completeness is a trusted algorithmic dependency; no short independent negative certificate is supplied |
| Time/node/memory budget stop | Unresolved equivalence | Must never be reported as false |
| Signature absent from hash-bound quadratic reference | Inequivalence to every represented quadratic class | Depends on reference provenance; does not prove literature completeness |
| Different signatures from all Gold exponents at n = 8 | Inequivalence to **every APN power function** | Uses Yoshiara 2016, not a claim that the reference contains all power functions |

[Yoshiara 2012, Theorem 1](https://emis.muni.cz/journals/JACO/Volume35_3/p72q12l317124710.fulltext.pdf)
identifies EA and CCZ equivalence for two quadratic APNs, without an extra
group-theoretic hypothesis. The ortho-derivative spectra used here are EA
invariants; [Canteaut, Couvreur and Perrin](https://arxiv.org/abs/2103.00078)
also make clear that their discriminating strength is not a converse theorem.
Hashing introduces no assumption in a separation: different deterministic
hashes imply different underlying signatures. Exact LUT deduplication checks
literal equality when a digest matches, and rejects a collision.

[Yoshiara 2016, Theorem 2](https://link.springer.com/article/10.1007/s10801-016-0680-z)
states that a quadratic APN in dimension n >= 3 can be CCZ-equivalent to a power
APN only if it is EA-equivalent to a Gold function. At n = 8 the possible Gold
parameters are k = 1, 3, 5, 7. The workflow constructs and independently verifies
all four, checks their reference membership and records their signatures. Every
corpus-absent candidate excludes all four signatures, hence all APN power
functions. This also closes the Kasami concern theoretically. The existing
[Kasami computation](../kasami_x57/REPORT.md) supplies further evidence, subject
to the documented sboxU dependency and thread bug. It is unnecessary to
enumerate the Kasami CCZ class again for this power-function exclusion.

Algebraic degree is not generally CCZ invariant. Arbitrary nonquadratic,
non-power references therefore require a general CCZ comparison, a verified
quadratic representative, or an applicable theorem/invariant. A bounded native
Gold/Kasami comparison attempted in this audit stopped after twenty seconds;
its result was correctly inconclusive. That does not undermine the separate
theoretical exclusion above. Positive graph witnesses are checked without VBF
by `verify_certificate.jl`; independent negative solver-tree certification and
proof-assistant formalization are not implemented.

## Implementation gaps found and addressed

The old web page labelled signature hits “KNOWN”, and absences “NEW”, and its
EA check could run without an explicit resource bound. The old fast runner
recorded completed parents but had no real resume cursor. The B52 runner could
replay interrupted work and skip spaces using histogram keys not proved to
characterize equivalence. Committed historical READMEs also presented
capture–recapture and mass-to-class estimates too strongly.

The consolidated workflow now provides exact LUT storage, independent APN and
signature evidence, corpus provenance checks, explicit Gold coverage,
bounded ternary equivalence outcomes, persisted witnesses, atomic candidate /
cursor checkpoints, interrupted-work recovery, deterministic finite plans,
untruncated V5 coset chunks, execution/source archives, database audits,
publication exports and a shared frontend evidence layer. It preserves existing
mathematical implementations instead of replacing them with another APN or
equivalence library. Tests cover forged/singular witnesses, real solver
recovery, budget stops, interruption/resume, rollback, concurrent-writer
rejection and chunk equivalence. The switching core's optimized constraint
assembly still matches the original ordered equations in pivot rows and
kernels, including nonquadratic controls.

Checkpointing does not serialize every partially reduced matrix or a partial
Fourier coset. It repeats only interrupted preprocessing/uncommitted work;
committed candidate evaluations are skipped. Audit verifies candidate
properties, stored graph maps and ledger coverage. It does not independently
recompute every nullspace or replay every rejected Fourier extension. Finite
exhaustion therefore remains conditional on the tested construction algorithms'
correctness, rather than a separate formal proof certificate.

## Is exhaustive enumeration realistic?

All normalized quadratic maps F2^8 -> F2^8 have 28 eight-bit coefficients:
**2^224** possibilities. Including affine terms gives **2^296** degree-at-most-two
maps; arbitrary maps number **2^2048**. Naive exhaustive enumeration is
infeasible. An APN-pruned extension tree can be smaller, but no observed discovery
count or eight-hour yield provides a bound on its total size or proves all
equivalence orbits have representatives in our restricted constructions.

A frozen switching plan is assessable: its exact remaining evaluation count
is the sum of 2^d - 1 over uncompleted direction kernels, accounting for the
cursor. Large d can make one parent infeasible. Completing selected parents
does not show that the full switching graph is connected or exhausted. A V5
unit starts in a 23-dimensional quotient (up to 2^23 - 1 nonzero cosets), then
enumerates only the selected bent-count cosets and their admissible extensions.
Each affine kernel may itself contain up to 2^23 choices. The exact coset count,
processed chunks and truncation flags are recorded; per-unit rates must be
measured without heuristic skips before projecting completion time.

The Framework queue's continued growth argues against assuming an eight-hour
closure will finish. A rigorous global classification would require a proved
complete construction/reduction, exhaustive enumeration with certified symmetry
reductions, or a full canonical classification algorithm and complete finite
coverage. A closed restricted graph is still a restricted graph unless such a
coverage theorem connects it to all APNs. The current census estimates orbit
mass; unknown stabilizers prevent identifying mass with the class count.
Uniformity and independence needed for capture–recapture have not been
established. Its intervals are exploratory estimates, not global guarantees.

## Requirements before a novelty publication

1. Obtain and compare the complete announced Baudrin–Galissant–Perrin 2026
   switching output; one slide LUT does not represent that dataset. Record
   any unavailable sources and the literature cutoff date. Author contact
   and data release cannot be replaced by a mathematical signature check.
2. Maintain a construction coverage ledger with parameter domains, field
   moduli/bases, source versions, exclusions and explicit maps where claimed
   equivalences reduce a family to representatives. The existing survey covers
   several additional releases, but is not proof of completeness of all
   parameterized/non-power constructions.
3. Resolve every signature collision relevant to exact class counting using
   bounded EA/CCZ checks, complete canonicalization or an equivalent exact
   method. Unresolved buckets give lower bounds, not an exact census. `classify.jl` now resolves equal-signature
   candidate buckets incrementally, reuses verified decisive results and
   preserves unresolved pairs when its explicit limits stop.
4. Archive frozen discovery/validation inputs, code, environment, reference
   provenance, graphs/witnesses, logs and coverage audits. Have another
   implementation or researcher reproduce the important finite computations.
5. Publish scoped claims: verified APN functions and pairwise CCZ-separated
   examples absent from explicitly documented references; restricted construction
   completion if achieved. Use “previously unknown in the literature” only
   after the comparison gaps are resolved. A new infinite family or new
   mathematical construction needs an additional proof, beyond finite LUTs.

The focused switching core tests pass 1,397 assertions; the original rebuild
verification tests pass 142. The new discovery/classification suite passes 55
and the frontend suite passes 93, for 1,687 focused assertions in total
(their execution logs are local artifacts). End-to-end
verification stopped after ten committed combinations, resumed to all 255
without duplicates, and audited all 256 exact LUTs. A deliberately corrupted
terminal cursor was rejected. A two-worker search and an n = 8 Fourier run
also preserved state correctly at their time bounds. A cooperative STOP request
was acknowledged with an explicitly incomplete plan; workers poll directly so
CPU-bound work cannot starve a timer-based stop request.

The defensible current result is substantial computational evidence backed by
exact finite verification and established equivalence theorems. The framework
is suitable for preparing a reproducible computational study. Literature-wide
novelty, an exact total number of eight-bit APN classes and complete enumeration
of the unrestricted problem remain unresolved.
