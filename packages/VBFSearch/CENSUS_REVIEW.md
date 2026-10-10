# Census implementation review and consolidation

Review date: 2026-10-10. Original tree: `census/quadratic_apn8/` at commit
`2f989a9`. The review inventories all 71 Julia scripts (9,385 lines), the Python
survey helpers, tests, Makefiles, configurations and scientific artifacts. About
13 GB of data moved to `data/apn/archive/census/`; 55,003 relocated files were
checked by SHA-256. The root `census/` folder is removed.

## Ownership and decisions

| Original component | Current owner | Decision |
|---|---|---|
| `qknuth.jl` | `VBF.QuadraticAPNTree` | Polar images, coefficient representation, bounded exact tree counts and Knuth probes are reusable mathematics. Shared GF(2) basis computation replaces another elimination implementation. |
| `fastlast.jl` | `VBF.QuadraticAPNTree` | Keep the fail-first counter and its coset preparation. Remove two superseded fast counters. Keep plain unsymmetrized backtracking as a reference. Validate dimensions, coefficients, symmetry and zero diagonal; budget stops supply no exact count. |
| Mathematical part of `sampler.jl` | `VBF.QuadraticAPNTree` | Promote the penultimate-node probe. TSV writing, deterministic stream scheduling and sampling configurations remain a research consumer. |
| `helpers.jl` | `VBFSearch/experiments/census` | Replace coefficient decoding with the core representation. Retain compact sample I/O, study constants and statistical diagnostics; retain zero-weight dead ends. Batch diagnostics now include the remainder and reject undersized/invalid samples. |
| `reports/properties/profiles_lib.jl` | `VBF.QuadraticProfiles` | Component ranks, ordered flag profiles and bent-subspace calculations are mathematics. Reuse core rank and coefficient APIs; reject unsupported dimensions/depths and bound enumeration. Preserve the explicit `:lex` and `:bminK` orders. |
| Mathematical part of `theory/check_uniqueness.jl` | `VBF.QuadraticRestrictions` | Promote restriction coefficients, hyperplane bases, polar annihilators, kernel dimensions and restriction comparisons. Reject nonquadratic LUTs and dependent/out-of-domain bases. Catalog selection and experiment reporting remain consumers. |
| Mathematical part of `hyperplane_theory/admissible.jl` | `VBF.QuadraticRestrictions` | Promote radical options, node-capped exact-cover counts and relation dimensions. Capped results remain lower bounds. The assumption-based sampler remains research code and now checks its whole-radical pruning premise. |
| `rebuild_corpus/` | `VBFCatalog/tools/reference` | Keep independently verified, hash-bound rebuilds and comparisons as catalog-consuming tools. They produce a separate reference and never curate catalog entries. |
| Original record decoding in `crosscheck_raw/crosscheck.jl` | `VBFCatalog/tools/reference/raw_readers.jl` | Extract only record decoding; stop including the complete old fast audit engine to obtain a parser. Negative decimal LUT values and unsupported high binary-mask bits are rejected. |
| `reports/literature/`, historical input reconciliation | `VBFSearch/tools/literature` | Retain finite construction-domain audits, download manifests, evidence replay and digest-bound candidate reconciliation. Formula enumeration belongs to research orchestration until a general, documented construction API is justified. |
| `web/` | `docs/inspector` | Make the frontend an explicit package consumer with its own HTTP environment. Use the core coefficient representation, archived input lists and `data/apn/runs/web/` certificates. |
| B52 and old switching runners; ad hoc index, properties and export probes | Historical source snapshot and Git | Retire duplicate search/checkpoint/oracle implementations and broken one-off probes. Supported discovery remains `bin/vbf`; existing profile/reference/evidence APIs provide their reusable capabilities. |
| Hyperplane scan TSV runner and analysis | Historical source snapshot and Git | Preserve the complete algorithm and results. Its traversal is a distinct construction; it has not been integrated into the production checkpoint driver. Restriction/extension primitives are now available for that future driver. |
| Kasami/power and explicit control exporters | `VBFSearch/experiments` | Keep scientifically specific consumer scripts using existing constructions and equivalence primitives. Avoid promoting catalog IDs and historical report formatting into VBF. |

No catalog entries or corpus records were added. Runtime dependencies remain
`VBFCatalog -> VBF` and `VBFSearch -> {VBF, VBFCatalog}`. Independent verifiers
stay separately implemented and standard-library-only. Reference tools reuse
those verifier sources without adding a runtime dependency from VBFCatalog to
VBFSearch. Downloaded inputs and generated source archives are data, not another
maintained implementation.

## Mathematical guarantees and limits

`QuadraticAPNTree.images` checks the rank of every nonzero polar direction.
For a homogeneous quadratic function this is equivalent to the full APN
condition. It does not check arbitrary higher-degree functions. The optimized
extension counter enumerates a finite space of linear maps and multiplies its
canonical count by the size of a proved free polar-translation action. Its
representatives are not necessarily distinct EA or CCZ classes. The reference
counter does not apply this symmetry reduction.

Exact tree and extension counts have explicit node budgets. Reaching a budget
throws `EnumerationLimitError`; no partial answer is labeled exact. These bounded
mathematical routines have no persistent frontier. Production checkpointing
continues to belong to VBFSearch's existing V5/switching drivers. A future tree
or hyperplane driver must expose and persist its own finite cursor before claiming
resumability or complete coverage through `bin/vbf`.

Restriction coefficient extraction explicitly removes affine terms after
checking degree. Reconstructed homogeneous LUTs therefore need not equal the
original LUT byte-for-byte. Their degree-two coefficients agree; polar ranks
and the documented quadratic invariants ignore those affine terms.

Admissible radical selections give necessary combinatorial conditions. Their
exact count can exceed the number of realizable APN extensions. Node-capped
admissible counts return `exact=false` and a lower bound. Optional whole-radical
pruning in the research estimator is allowed only when the sum of minimum
option sizes forces every selected option to have minimum size.

Component profiles retain their mathematical ordering convention. They are
invariant filters, not complete equivalence classifiers. Signature equality in
the exploratory neighbour scripts labels a bucket. Different separating
signatures prove quadratic CCZ inequivalence; equality needs a witness or a
complete equivalence algorithm. A signature graph alone is not a classification
of all APN functions.

Knuth weights count coefficient tuples. Converting them to orbit mass needs the
specified action and stabilizers; converting mass to class counts needs further
arguments. Historical coverage formulas depend on their original reference and
sampling assumptions. This refactor does not certify those estimates. The
[scientific assessment](AUDIT.md) remains the source for the verified candidate
counts and the unresolved scope of literature-wide novelty.

## Reproducibility and evidence

All historical data, report contents, frozen manifests, original downloads and
captured executable sources remain byte-preserved. Their embedded paths and
source hashes are historical evidence. The ignored migration manifest records
old-to-new locations and digests; `VBFCatalog/tools/reference/paths.jl` resolves
only the retired census prefix for digest-checked input reads. It never rewrites
old reports or bypasses computation-identity checks.

New output defaults are `data/apn/runs/` and `data/apn/rebuilds/`; archived evidence
is an input. Original-source readers, candidate decoding and independent APN /
signature verification remain separate responsibilities. The rebuilt reference
still describes a specific finite set of quadratic APNs, with explicit original
sources and exclusions. Reference completeness throughout the literature is not
established by moving or consolidating files.

The full VBF suite passed 145,458 assertions across 97 items. Additional
bent-subspace/budget checks passed in the final focused run. The sampling/compact
consumer passed 1,706 assertions, the inspector passed 93, and construction-domain
fixtures and forged-certificate replay passed 173. The production VBFSearch suite
passed its checkpoint/replay checks. Reference-tool fixtures passed, including all
four source formats and malformed/truncated input handling.

Validation for this consolidation includes:

- All 512 three-bit quadratic coefficient tuples against full DDT verification;
  the exact APN count is 168. Closed-form three-variable counts and the
  four-variable count 1,128,960 are checked.
- Optimized and unsymmetrized extension counts against independent direct
  enumeration; representative counts satisfy the free-action factor.
- Hyperplane annihilator/kernel identities and admissible lower bounds;
  component ranks against directly computed Walsh amplitudes, and two-level
  profiles against direct flag enumeration.
- Sampling and compact-data tests, including the committed legacy sample hit;
  production stop/resume and independently revalidated stored candidates;
  reference rebuild fixtures, malformed readers and graph-witness rejection;
  frontend request-handler tests and family-evidence replay.

The 15.9-million-record original-source computation is not rerun as part of this
refactor. Its databases and previous verification evidence are preserved. A new
end-to-end run with the current executable sources requires a fresh rebuild
identity, the ignored originals/private formula inputs and the time/disk budget
specified in the [reference guide](../VBFCatalog/tools/reference/README.md).

## Complete Julia source inventory

Paths in the first column are relative to the former census study root.
All originals are available in the ignored historical source snapshot.

| Original script | Active destination or decision |
|---|---|
| `analyze.jl` | `packages/VBFSearch/experiments/census/analyze.jl` |
| `crosscheck_raw/crosscheck.jl` | Retired; historical snapshot and Git |
| `crosscheck_raw/export_raw_only.jl` | Retired; historical snapshot and Git |
| `crosscheck_raw/selftest.jl` | Retired; historical snapshot and Git |
| `diagnostics.jl` | `packages/VBFSearch/experiments/census/diagnostics.jl` |
| `exact_masses.jl` | `packages/VBFSearch/experiments/census/exact_masses.jl` |
| `fast_switching/benchmark.jl` | Retired; historical snapshot and Git |
| `fast_switching/search.jl` | Retired; historical snapshot and Git |
| `fast_switching/test/runtests.jl` | Retired; historical snapshot and Git |
| `fastlast.jl` | VBF.QuadraticAPNTree (consolidated) |
| `helpers.jl` | `packages/VBFSearch/experiments/census/helpers.jl` |
| `kasami_x57/export_luts.jl` | `packages/VBFSearch/experiments/power_ccz/export_luts.jl` |
| `kasami_x57/sigma_check.jl` | `packages/VBFSearch/experiments/power_ccz/sigma_check.jl` |
| `kasami_x57/vbf_subspace_count.jl` | `packages/VBFSearch/experiments/power_ccz/vbf_subspace_count.jl` |
| `permutation/export_controls.jl` | `packages/VBFSearch/experiments/controls/export_controls.jl` |
| `qknuth.jl` | VBF.QuadraticAPNTree (consolidated) |
| `rebuild_corpus/check_candidates.jl` | `packages/VBFCatalog/tools/reference/check_candidates.jl` |
| `rebuild_corpus/check_equivalence.jl` | `packages/VBFCatalog/tools/reference/check_equivalence.jl` |
| `rebuild_corpus/compare.jl` | `packages/VBFCatalog/tools/reference/compare.jl` |
| `rebuild_corpus/fetch.jl` | `packages/VBFCatalog/tools/reference/fetch.jl` |
| `rebuild_corpus/rebuild.jl` | `packages/VBFCatalog/tools/reference/rebuild.jl` |
| `rebuild_corpus/test/candidates.jl` | `packages/VBFCatalog/tools/reference/test/candidates.jl` |
| `rebuild_corpus/test/comparison.jl` | `packages/VBFCatalog/tools/reference/test/comparison.jl` |
| `rebuild_corpus/test/equivalence.jl` | `packages/VBFCatalog/tools/reference/test/equivalence.jl` |
| `rebuild_corpus/test/runtests.jl` | `packages/VBFCatalog/tools/reference/test/runtests.jl` |
| `report.jl` | `packages/VBFSearch/experiments/census/report.jl` |
| `reports/literature/check_families.jl` | `packages/VBFSearch/tools/literature/check_families.jl` |
| `reports/literature/check_sources.jl` | `packages/VBFSearch/tools/literature/check_sources.jl` |
| `reports/literature/confirm_history.jl` | `packages/VBFSearch/tools/literature/confirm_history.jl` |
| `reports/literature/test_families.jl` | `packages/VBFSearch/tools/literature/test_families.jl` |
| `reports/literature/test_verify_families.jl` | `packages/VBFSearch/tools/literature/test_verify_families.jl` |
| `reports/literature/verify_evidence.jl` | `packages/VBFSearch/tools/literature/verify_evidence.jl` |
| `reports/literature/verify_families.jl` | `packages/VBFSearch/tools/literature/verify_families.jl` |
| `reports/properties/analyze_hits.jl` | Retired; historical snapshot and Git |
| `reports/properties/aut_perm.jl` | Retired; historical snapshot and Git |
| `reports/properties/compute.jl` | Retired; historical snapshot and Git |
| `reports/properties/corpus_profiles.jl` | Retired; historical snapshot and Git |
| `reports/properties/profiles_lib.jl` | VBF.QuadraticProfiles (consolidated) |
| `reports/properties/tabulate.jl` | Retired; historical snapshot and Git |
| `reports/properties/validate.jl` | Retired; historical snapshot and Git |
| `reports/verification/analyze_known.jl` | Retired; historical snapshot and Git |
| `reports/verification/ea_check.jl` | Retired; historical snapshot and Git |
| `reports/verification/nonquad_relations.jl` | Retired; historical snapshot and Git |
| `reports/verification/probe0.jl` | Retired; historical snapshot and Git |
| `reports/verification/rebuild_store_sha.jl` | Retired; historical snapshot and Git |
| `reports/verification/review_history.jl` | `packages/VBFSearch/tools/literature/review_history.jl` |
| `reports/verification/verify_index.jl` | Retired; historical snapshot and Git |
| `reports/verification/verify_new553.jl` | Retired; historical snapshot and Git |
| `reports/verification/verify_nonquadratic.jl` | Retired; historical snapshot and Git |
| `reports/verification/verify_raw_beierle.jl` | Retired; historical snapshot and Git |
| `sampler.jl` | `packages/VBFSearch/experiments/census/sampler.jl` |
| `search_b52/common.jl` | Retired; historical snapshot and Git |
| `search_b52/framework_b6_sample.jl` | Retired; historical snapshot and Git |
| `search_b52/report.jl` | Retired; historical snapshot and Git |
| `search_b52/search.jl` | Retired; historical snapshot and Git |
| `search_b52/table.jl` | Retired; historical snapshot and Git |
| `search_b52/validate.jl` | Retired; historical snapshot and Git |
| `test/runtests.jl` | `packages/VBFSearch/experiments/census/test/runtests.jl` |
| `test/test_compact.jl` | `packages/VBFSearch/experiments/census/test/test_compact.jl` |
| `test/test_counters.jl` | Core exhaustive/reference tests replace the old harness |
| `test/test_exact_counts.jl` | Core exhaustive/reference tests replace the old harness |
| `test/test_pipeline.jl` | `packages/VBFSearch/experiments/census/test/test_pipeline.jl` |
| `test/test_reproducibility.jl` | `packages/VBFSearch/experiments/census/test/test_reproducibility.jl` |
| `theory/check_uniqueness.jl` | `packages/VBFSearch/experiments/hyperplanes/check_uniqueness.jl` |
| `theory/hyperplane_scan/analyze.jl` | Retired; historical snapshot and Git |
| `theory/hyperplane_scan/scan.jl` | Retired; historical snapshot and Git |
| `theory/hyperplane_theory/admissible.jl` | `packages/VBFSearch/experiments/hyperplanes/admissible.jl` |
| `theory/hyperplane_theory/neighbours.jl` | `packages/VBFSearch/experiments/hyperplanes/neighbours.jl` |
| `validate.jl` | `packages/VBFSearch/experiments/census/validate.jl` |
| `web/server.jl` | `docs/inspector/server.jl` |
| `web/test/runtests.jl` | `docs/inspector/test/runtests.jl` |
