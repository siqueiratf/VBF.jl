# Test report

Julia 1.13.1, 9 October 2026. Tests run from the repository root project;
no sboxU, Python or Magma runtime participates in the implementation.

## Completed automated tests

`julia --threads=16 --project=. papers/2025/Baudrin_202509/test/runtests.jl`
passed **255 assertions**:

| Test set | Assertions | Checks |
|---|---:|---|
| Section 3.1 | 18 | Complete small orbit census, native/legacy agreement, graph certificates, budget outcomes, saved witness round trip |
| Section 3.2 | 15 | Fourteen distinct lookup tables, thirteen quadratic APN inputs, exact four-bit sample, root distinctness, invalid full-search requests |
| Conjecture 1 | 31 | Switching supports and APN checks, partial outcomes, undecided EA/CCZ comparisons, bounded novelty semantics |
| Independent evidence | 68 | Raw certificate/rank checks, corrupted/singular certificate rejection, zero node/subspace/memory budgets, TOML round trips, source hashes, stage completeness, shared native/legacy node accounting and Theorem 2 bounds |
| Resumable census drivers | 18 | Validated input coverage, budgets and checkpoint round trips |
| Switching checkpoint audit | 44 | Independently recomputed kernel/coset coverage, corrupt evidence rejection and deadline-aware resume |
| Parallel switching | 15 | Serial/parallel deterministic candidate and witness outcomes |
| Seven-bit checkpoint audit | 28 | Raw maps, Walsh spans, group actions, orbit coverage and corrupt evidence rejection |
| Parallel census | 18 | Serial/parallel root parity, independent task state, zero budgets and invalid cache rejection |

The test-only `certificate_oracle.jl` applies saved affine columns using packed
integer XOR and independently checks binary rank. It checks EA block structure
when applicable. It does not call `ccz_equivalent_function`, apply a VBF map,
or rerun the search that produced a certificate. Witness snapshot tests use unique filenames. The Section 3.1 payload test
preserves and restores any prior `section31.toml`; neither test writes the
expensive census or saved six-bit switching filenames.

## Completed small computations

`make -C papers/2025/Baudrin_202509 report` completed successfully. Four-bit
Gold has sixteen Walsh-zero subspaces, two EA classes with degrees two and
three, and identical complete native and ortho-derivative orbit partitions.
The bounded switching demonstration examined fifteen candidates, made 34
equivalence decisions and retained 32 independently checked graph witnesses.
Its frontier remained incomplete because of the parent-expansion limit;
the reported result remained bounded, with Conjecture 1 unproved.

The reusable bounded switching API additionally passed 246 assertions, with
complete four-/five-bit Gold enumeration matching the legacy API exactly
(75/31 neighbours). A constructed 63-vector Boolean kernel checks that large
candidate masks do not overflow into an empty enumeration. Deadlines cover
construction as well as candidate enumeration, and reentrant observers keep
independent invocation state.

## Larger saved experiments

The explicit `census6 save_results=true` run completed all fourteen known
CCZ roots: **691 EA classes** in thirteen quadratic classes, plus **25** in
the nonquadratic class, totaling **716**. The degree histogram is
`{2:13, 3:521, 4:182}`. Every quadratic native orbit partition agrees with
the complete ortho-derivative backend.

The standalone `test/audit_saved_evidence.jl` passed **2,596 assertions**
against the saved census. It independently checked all 716 invertible affine
matrices point by point, source dataset hashes, APN status, distinct target
lookup tables, per-root representative indices and the degree histogram using
raw Möbius transforms. Of the 91 root-pair records, 78 ortho-derivative
Walsh/DDT mismatches and one absolute Walsh mismatch were independently
recomputed with direct integer arithmetic. The remaining twelve records are
native exhaustive CCZ searches; a snapshot's node count cannot independently
prove their negative conclusion.

Those twelve negative comparisons were additionally replayed from the saved
lookup tables **without supplied automorphism groups**. All twelve exhausted
with 65 search nodes each; the replay took about 3.2 seconds after package
loading. This is a separate execution of the same validated solver, not an
independent negative-equivalence oracle.

The final census was computed before the metadata expansion to schema v2.
Its supplementary `section32_run_provenance.toml` binds the saved artifact to
87 source hashes and the PDF hash captured while the run was active, before
those metadata edits; it does not claim process-start provenance. Later v2
snapshots capture source hashes when helpers are loaded and record individual
stage-completeness flags.

Two bounded six-bit switching runs were independently audited:

| Run | Parents expanded | Verified APN neighbours | Equivalence decisions | Verified graph witnesses |
|---|---:|---:|---:|---:|
| Gold and Kim initial roots | 2 | 4 | 14 | 27 |
| Dedicated Kim root | 1 | 2 | 79 | 200 |

The combined run actually expanded two EA representatives in Gold's CCZ
class; Kim's closure was initialized but no Kim switching parent was expanded.
The dedicated run expanded a Kim-class parent. Its two neighbours matched
existing classes `reprs6_8` and `reprs6_11`, with checked CCZ and EA witnesses.
Both runs stopped at the neighbour cap, retained incomplete frontiers, and
reported zero undecided comparisons and zero relative new CCZ classes. The
raw audit checked every saved graph witness, independently recomputed APN
DDTs and reconstructed each candidate from its recorded switching support.
The switching snapshot audit sets passed 12 and 8 assertions respectively.

## Complete switching closure and seven-bit census

The full serial and 16-worker switching runs completed all 716 parents,
45,108 directions and 20,674 APN neighbours. They produced exactly the same
candidate LUTs, checked target roots and two-component graph. The independent
parallel artifact audit and cross-run comparison passed **109,814 assertions**.
The independent kernel census agrees with all fourteen Gillot–Langevin kernel
histogram and weighted basis-vector columns (11,598 basis vectors).

Full closure wall times were **497.57 seconds serial** and **96.45 seconds with
16 workers**. Kernel/candidate generation alone took **35.97/3.89 seconds**.
The full seven-bit census took **384.13 seconds**, completing 488 roots with
82,409 representatives and degree counts `{2:488,3:60302,4:21619}`. A fresh
standalone audit completed all 488 checkpoints in **23.77 seconds**, checking
raw affine maps/ranks, direct Walsh coefficients, APN and degree of witnesses,
subspace spans and orbit partition coverage/connectivity. Exhaustion is
recorded by the tested producer rather than independently replayed by this
artifact audit. The source collection supplies root distinctness.

The VBF regression suite passed **143,086 assertions in 100 test items**,
excluding the previously known failures `linear_backtracking` and `extensions`.
The documentation build and doctests passed. The subsequent unsigned-span
API extension additionally passed six focused type/range assertions.

## Limits

The known-class census establishes EA classes inside the recorded CCZ roots;
it does not prove that those roots include every six-bit APN function. The
82,409-class seven-bit census completed for all 488 pinned roots; their mutual
CCZ distinctness is inherited from the source collection. Finite switching-frontier
exhaustion cannot establish that every APN function is reachable by switching,
and these tests do not prove Conjecture 1 or the paper's universal theorems.
No speed or memory superiority over the authors' sboxU implementation is
measured. Memory limits use estimated allocation rather than measured RSS.
An individual APN test, linear-algebra primitive or legacy automorphism call
cannot be interrupted midway; elapsed time is charged before further work.
