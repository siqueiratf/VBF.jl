# Independent final review

Reviewed 9 October 2026 against the supplied PDF, its extracted text,
`EXPERIMENTS.md`, `PLAN.md`, the paper implementation, and the reusable VBF
orbit, bounded subspace, switching and automorphism-provenance integration.
The PDF remains an ignored private input. This review edits only this file.

### Critical (must fix before merging)

None.

### Important (should fix)

None remaining in reviewed code. The original schema-v1 census artifact has a
clearly labeled supplemental manifest; it is not represented as process-emitted
schema-v2 evidence. Its artifact/PDF SHA256 hashes and 87 recorded source hashes
were checked.

Resolved during review: the legacy comparison now uses the remaining per-root
node budget; saved metadata records source hashes and stage completeness;
Theorem 2's finite APN bounds are explicitly checked; the broader regression
passed after its completion test received an adequate discovery deadline.

### Minor (nice to have)

None. The report heading now includes the selected dimension.

### Passed checks

- Extended review covered the reusable rectangular APN-extension solver,
  optimized subspace extraction, parallel switching/seven-bit producers and
  saved-checkpoint auditors. The parity constraints enumerate precisely the
  vanishing projected two-flats; normalization removes affine and existing
  component additions. Multiple-coordinate backtracking enforces a nonzero
  output sum on each constrained flat. The GF(4) linearized test is reported
  as a necessary obstruction, never as a sufficient extension certificate.
- The optimized subspace search intersects candidates with translated
  candidates and preserves canonical basis enumeration. Histogram pruning is
  a necessary cardinality bound. Dense and sparse membership representations
  preserve the same mathematical search; bounded prefixes may differ.
- Parallel tasks own their search state, random generators and result slots.
  Shared target automorphism discovery and progress output use locks; the
  immutable reference data and verified groups are borrowed without mutation.
  Per-parent limits and aggregate wall-clock limits are distinguished from
  sums of worker time. Atomic checkpoints bind the source census, parent/root
  indices, code snapshot and algorithm parameters before reuse.
- Resume paths audit completed checkpoints before accepting them. Switching
  checkpoint audits share the search deadline; expiration leaves the checkpoint
  untouched and cannot accept a partially checked parent. Seven-bit partial
  checkpoints are recomputed. Corrupted graphs, orbit assignments, degrees,
  source identities and algorithm settings cannot silently retain exactness.
- The completed six-bit one-coordinate switching closure processes all 716
  parents and all 45,108 output directions. It covers 20,674 normalized APN
  neighbours, with no unresolved comparisons or relative new CCZ classes,
  and recovers two components: roots 1–2 and roots 3–14. The serial run took
  497.569 seconds; the separate sixteen-worker run took 96.455 seconds and
  reproduced these coverage totals and components. This is a comparison of
  these two VBF runs, not a benchmark against the authors' implementation.
  The separate auditor checks raw two-flat systems, quotient dimensions,
  distinct switching cosets, APN properties and all positive graph witnesses;
  it rebuilds the reported components from the verified edges.
- The seven-bit producer completed all 488 pinned quadratic roots in 384.131
  seconds and reproduced 82,409 classes with degree histogram
  `{2:488, 3:60302, 4:21619}`. Its separate raw checkpoint audit completed in
  23.775 seconds: it checks Walsh-zero subspaces, generator graph maps, dual
  actions, orbit connectivity, representative maps, APN properties and degrees.
  Full group discovery and subspace exhaustion are recorded by the producer
  and are not independently replayed by that audit. Pairwise root distinction
  is inherited from the pinned input collection, not independently established
  by this seven-bit run; summing its closures is conditional on that input fact.
- The selected extended VBF regression passed 143,086 assertions across 100
  items, excluding the same two identified pre-existing failures. The dedicated
  seven-bit checkpoint fixture audit passed 28 assertions and exercised an
  actual saved-root round trip. These checks supplement the earlier evidence
  below; the earlier test totals describe the earlier implementation stage.
- Proposition 2's group-orbit classification is implemented through verified
  graph automorphism generators. The inverse-transpose action generates the
  same orbits as the paper's transpose action; neither translation constants
  nor a generator count are mistaken for the acting linear-group order.
- Representative construction puts the selected Walsh-zero basis in the high
  input rows of the admissible map. Core tests compare its full span directly
  with the selected orbit basis and check APN, graph maps and EA distinction.
- Exactness requires a complete group bound to the source graph, complete
  subspace extraction and completed orbit actions/construction. Unbound or
  other-source group results remain verified subgroups. The legacy route
  correctly retains subgroup status below Proposition 3's dimension-four
  hypothesis.
- Native and legacy APIs share deterministic subspace mathematics. Candidate,
  time and output bounds stop actual work and retain partial results; zero
  bounds and interrupted actions cannot certify a census. Allocation limits
  are explicitly estimates and legacy automorphism enumeration is documented
  as uninterruptible.
- Catalog access is isolated in `catalog_validation.jl`: thirteen APN-rep
  roots plus Kim, fourteen APN lookup tables and thirteen quadratic roots.
  Census exactness additionally requires pairwise CCZ root distinction;
  quadratic invariant mismatches use the stated CCZ=EA hypothesis.
- The final saved schema-v1 census completed all fourteen rows and all 91
  pairwise root comparisons, with thirteen complete native/legacy comparisons.
  Its 716 certificates passed the independent raw integer-XOR/rank oracle;
  all 716 target lookup tables are distinct. A separate raw Möbius transform
  of the saved lookup tables reproduced the ANF degree histogram
  `{2:13, 3:521, 4:182}`, alongside the recorded 691+25 closure totals.
  Root distinction uses 78 ortho-derivative invariant mismatches, one absolute
  Walsh-spectrum mismatch and twelve exhausted native CCZ searches. Inspecting
  those negative search records is not an independent inequivalence proof;
  their completeness relies on the tested native solver. The independent raw
  certificate/ANF audit verifies positive graph maps and degree totals.
  Stage 5 additionally derived all 79 invariant rejections directly from the
  saved lookup tables. It replayed the other twelve pairs without supplied
  automorphism groups: each native search exhausted after 65 nodes. These
  replays corroborate the saved decisions using the same solver, rather than
  an independent negative-equivalence algorithm.
- Switching retains search budget hits as undecided, caches each class closure
  once, records the frontier and compares matched candidates against EA
  representatives. Novelty is described relative to the recorded reference
  collection. Finite frontier exhaustion cannot prove global reachability.
- The saved six-bit switching run is bounded: two parent expansions, four
  candidates, fourteen comparisons, twenty-seven graph certificates, no
  undecided comparisons and no relative new CCZ seeds. Both processed parents
  came from the cube closure; the Kim closure was constructed but its parents
  were not expanded. An independent integer-XOR/rank oracle validated all
  twenty-seven saved certificates without applying VBF maps.
  The repeated run's schema-v2 snapshot preserves these counts and adds source
  hashes, elapsed time and cached-closure completeness; all twenty-seven maps
  were independently checked again.
- A separate Kim-root schema-v2 run expanded one Kim-class parent, returned
  two candidates, made 79 comparisons and retained 200 graph witnesses. Both
  candidates matched known EA representatives, with no undecided comparisons
  or relative new CCZ seeds. All 200 saved maps independently passed the raw
  certificate oracle; the run remains bounded by its neighbour cap.
- Stage 5's initial suite passed 132 assertions; the extended suite now passes
  255 assertions, including a test-only raw
  certificate oracle, deliberate certificate corruption, budget semantics,
  switching-support checks, the corrected shared node budget, Theorem 2 bounds,
  schema-v2 source/closure metadata and TOML round trips. Witness snapshots use
  unique filenames; the Section 3.1 payload test preserves/restores its previous
  snapshot. Neither writes the census or saved six-bit switching artifacts.
  Its separate saved-census audit passed 2,596 checks covering raw graph maps,
  APN properties, ANF degrees, lookup-table distinction, root indices and the
  79 independent invariant rejections. Dedicated switching audits also checked
  the four combined-run and two Kim-run switching supports directly.
- The final broader VBF regression passed 143,086 assertions across 100 test
  items. Its two excluded items, `linear_backtracking` and `extensions`, are
  separately identified as pre-existing failures; this is not presented as an
  unfiltered package-suite pass. The earlier timing failure was an undecided
  outcome under an inadequate discovery deadline, and the completed rerun
  retains explicit uncertainty/budget tests.
- Default reports complete on four-bit examples and state bounded switching
  scope. `make help` lists the runnable targets and resource controls. No
  outside-paper includes, hard-coded runtime paths or VBF dependency on
  VBFCatalog were found. Generated TOML/PDF files are ignored and README is
  available for tracking.
- Source snapshots now record paper/VBF SHA256 hashes at helper load, private
  PDF availability/hash, Julia version, algorithm profile, deterministic seed,
  lookup tables, limits and stage completeness. Runs launched before those
  metadata additions require the separately captured manifest to be identified
  as supplemental provenance.
- Attribution distinguishes the BFA 2025 orbit workflow, Canteaut–Perrin's
  framework, Edel–Pott switching and the Kaleyski–Sunde 2026 native discovery
  substitution. The pinned current sboxU source is not claimed to be the
  original paper revision, and generator use is not claimed as algorithmic
  novelty.

### Summary

The scoped implementation is ready for merging: it is mathematically coherent
and safely reports incomplete work. The known-class six-bit census and complete
one-coordinate switching closure are reproduced and independently audited.
All 488 seven-bit closures reproduce the paper's 82,409 degree totals, conditional
on the pinned collection's inherited root distinction and the producer's tested
exhaustion decisions. The selected extended regression passes. No Critical or
Important code issue remains. The authors' exact switching traversal/database is
not reconstructed; finite closure does not prove Conjecture 1, that every APN
function belongs to the input collections, or the paper's universal theorems.
