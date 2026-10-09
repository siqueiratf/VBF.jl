# Gillot and Langevin (2026): Observation of known APNs

Independent Julia experiments for [Valérie Gillot and Philippe Langevin, *Observation of known APNs*, arXiv:2601.11247v1](https://arxiv.org/abs/2601.11247v1), submitted 16 January 2026. The ignored TeX source is the mathematical ground truth. [EXPERIMENTS.md](EXPERIMENTS.md) inventories every claim; [TEST_REPORT.md](TEST_REPORT.md) records validation and [REVIEW.md](REVIEW.md) records independent review.

The practical six-bit component and one-coordinate switching computations are complete. Two-coordinate, bihomogeneous and bent-extension searches were run with measured limits. This is a reproduction of those completed computations and an implementation of the remaining bounded searches; it does not reproduce every published table or prove either global conjecture.

## Completed computations

The input census contains 716 certified, distinct EA representatives from 14 known CCZ classes. Its generation is documented in [Baudrin_202509](../../2025/Baudrin_202509/README.md). These scripts consume portable LUTs and independently check the supplied graph maps; they never include another paper's implementation.

| Claim | Observed result | Measured seconds |
|---|---|---:|
| Table 1 | All 150,356 author Boolean representatives; all 15 printed bins agree | 2.72 |
| Table 2 | All 14 printed Code64 functions are APN and match known CCZ roots; degree/Γ columns have a cyclic row displacement | 23.90 |
| Fact 1 / Table 4 | All 45,108 nonzero components occupy 37 Boolean EA classes and eight moment levels; no inconclusive decisions | 157.02 |
| Fact 2 / Table 5 | All 716 inputs have an affine counting function; full degree histograms saved | 0.62 |
| Table 7 | All author inputs examined; three configurations agree, one seed-count convention differs | 2.28 |
| Table 8 | All 716 inputs; 3,455 bent three-spaces, all 11 printed bins agree | 0.38 |
| Lemma 1 / Proposition 1 | Exact moment identities and the stated implication checked on all 716 finite inputs | 0.68 / 0.69 |
| Fact 3 / Section 6 | All 716 parents, 45,108 projections and 20,674 nontrivial completions; two connected CCZ components | 497.57 generation; 1.40 audit |

Section 6 audits the complete saved switching construction, independently verifies every graph witness and APN LUT, and regenerates selected parity systems. Its coverage relies on the saved full-constructor metadata; it does not rerun every flat matrix. The quotient-dimension-weighted basis count is 11,598. The published basis-dependent class column has not been reproduced. The two graph components contain roots `reprs6_0, reprs6_1` and the other twelve roots.

The Table 4 independent audit checked 44,314 raw EA certificates and reconstructed all component multiplicities. Exact LUT-cache matches account for the remaining components. Times describe this local Julia run, including driver work but excluding separately loaded input validation; they establish neither a language advantage nor a comparison against author C code.

## Measured bounded computations

| Driver | Coverage and result | Limits and elapsed time |
|---|---|---|
| Table 6 | Two projections from each of 14 CCZ seeds: 28 of 9,114 seed projections; 48 APN completions, 46 certified known-root matches, one inconclusive and one unclassified at the deadline | 1,000,000 nodes/search, two solutions/search; separate 120-second cohorts, 120.01 + 17.54 seconds |
| Table 9 | All 13 primary bent seeds; four completions with certified known CCZ matches | 1,000,000 nodes/search, two solutions/search, 120 seconds overall; 42.99 seconds measured |
| Section 8 | All eight quartic and six cubic seed types; 30,128 finite orbit-prefix evaluations, no extension candidates | 56,000 evaluations, 1,000,000 nodes/search, 120 seconds overall; 4.97 seconds measured |
| Table 3 | All 14 roots: specified quadratic graph-annihilator, Γ/Δ and selected valuation computations | 0.98 seconds; unresolved author parameters keep `complete=false` |

Table 6 did not enumerate all 466,116 projections of the 716 EA inputs. Table 9 did not establish the paper's eight empty extension sets or its union of 150 EA classes. Residual output-linear duplicates may remain in three-output normalization. Section 8's zero candidates concern finite prefixes and do not establish nonexistence. The two Table 6 completions without completed classification have no claimed novelty. Current snapshots retain every completion LUT, including those whose classification stops; the older measured profile predates that addition and retains only its classified witnesses.

## Running

Requires the root project and Julia ≥1.12. From the repository root:

```sh
make -C papers/2026/Gillot_202601 test report
make -C papers/2026/Gillot_202601 fetch_inputs
make -C papers/2026/Gillot_202601 table1 table7 full_search=true save_results=true
make -C papers/2026/Gillot_202601 table4 full_search=true \
  input_path="$PWD/papers/2025/Baudrin_202509/results/section32.toml" \
  max_evaluations=500000 max_nodes=100000 timeout_seconds=300 save_results=true
make -C papers/2026/Gillot_202601 section6 full_search=true \
  input_path="$PWD/papers/2025/Baudrin_202509/results/section32.toml" \
  switching_path="$PWD/papers/2025/Baudrin_202509/results/switching_closure6.toml" \
  max_evaluations=30000 timeout_seconds=120 save_results=true
```

`make help` lists targets and limits. `all_tables` uses bounded defaults. `full_search=true` selects the full input list; node, solution, comparison and time limits still apply. The Table 6 Julia function also accepts `max_subfunctions_per_parent` to distribute bounded work across roots. Each claim file runs independently. Results are optional TOML files under ignored `results/`; inputs and downloaded copyrighted sources remain ignored.

Snapshots include limits, input hashes, witnesses, stop reasons, elapsed time, paper-source hashes and hashes of all VBF source files plus paper runtime files captured once when helpers load. Earlier expensive runs retain their original captured source hashes. `results/run_parameters_manifest.toml` supplies explicitly post-execution limits bound to the original artifact hashes; it does not replace process-captured metadata. `results/bounded_execution_calls.txt` preserves the bounded profile invocations.

## Algorithms, integration and credits

The reusable `apn_extension_space`, `apn_extensions` and `apn_extension_tests` APIs live in VBF, independently of VBFCatalog. They implement the paper's affine parity equations for one added output, exact zero-flat backtracking for multiple outputs, and the necessary differential/GF(4) linearized obstructions. Search outcomes distinguish exhaustion from a budget hit; inconsistency proves nonexistence, consistency does not prove extendability. Paper helpers handle source parsing, orchestration and independent certificate checks. `catalog_validation.jl` is the sole catalog import.

EA/CCZ decisions use the independent native Julia implementation of [Nikolay Kaleyski and Joakim Sunde, *Efficiently deciding and recovering CCZ and EA equivalence for arbitrary vectorial Boolean functions using the partition refinement framework*, ePrint 2026/940](https://eprint.iacr.org/2026/940). This backend replaces the paper's sboxU usage. The input EA-orbit census follows Jules Baudrin, Pierre Galissant and Léo Perrin, *Exploring the Set of APN Functions* (BFA 2025, HAL hal-05376704v2), and Anne Canteaut and Léo Perrin, *On CCZ-equivalence, extended-affine equivalence, and function twisting* (2019). Existing sboxU already provides automorphism-generator and orbit routines; no novelty is claimed for using generators. The inspected current reference is [sboxU commit bedb6d1](https://github.com/lpp-crypto/sboxU/tree/bedb6d1a796c3c582572393a91270b6fd15dc9e1), which is not asserted to be the authors' 2025 version.

The 13 bent ANFs are mathematical representatives from [Alexandr Polujan and Alexander Pott, *On design-theoretic aspects of Boolean and vectorial bent functions*, arXiv:2003.12308v3, Appendix A](https://arxiv.org/abs/2003.12308v3). All nonzero components are independently verified bent. The author Boolean artifact is [class-2-6.txt](https://langevin.univ-tln.fr/data/bst/class-2-6.txt), pinned by SHA-256 in `fetch_inputs.jl`. The raw 240-function bent batch is not substituted for the 13 representatives.

`section2.jl` supplies a precise instantiation of the paper's invariant-lifting construction, following Eric Brier and Philippe Langevin, *The classification of boolean cubics of nine variables* (IEEE Information Theory Workshop, 2003): the multiset of unordered pairs of exact κ values on complementary affine hyperplanes. Its literal backend remains the default. A separately committed spectral backend computes the same invariant and is selected explicitly by Table 4; exhaustive and randomized tests establish parity. This does not claim to reproduce the underspecified invariant reported to distinguish 150,355 author classes.

## Source and convention differences

- Section 7 prints 615 codimension-two subspaces; the correct value is 651 and gives 716×651=466,116.
- Table 2 Code64 rows are cyclically displaced by five from their degree/Γ columns. Functions are matched using certified equivalence, not row identity.
- Table 4 contains header counts inconsistent with its listed 37 IDs. Table 5's printed multiplicities sum to 503 and its cubic count conflicts with the independently reproduced census.
- Table 7's second degree-2-or-3 β=4 seed count is seven in the primary artifact, versus six printed. Six counts the cubic seeds alone; the intended convention remains ambiguous.
- Section 6's APN column counts quotient-basis directions, while full enumeration counts all nonzero quotient combinations. Basis and particular-solution choices can change the basis-dependent class column.
- Table 3's RM arguments, base invariant and transvection/stabilizer specification do not determine all reported values. Section 9's filtration parameters are also unspecified.
- Table 9's row counts overlap and therefore cannot be summed to obtain the union of 150 EA classes. Its “8 of 14” sentence conflicts with thirteen bent roots.

These differences remain visible in saved results. Finite known-input closure does not establish that all six-bit APNs are known.
