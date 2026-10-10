# Experiment inventory: Gillot and Langevin (2026)

## Paper metadata

*Observation of known APNs*, Valérie Gillot and Philippe Langevin, arXiv:2601.11247v1 (submitted 16 January 2026), cs.DM. The TeX uses `\today`; the later HTML rendering date is not a publication date. Ground truth: ignored `input/tex_source/knownapn.tex` and `input/paper.pdf`.

Source SHA-256: TeX `66331a357233486164932a3adfad7aa74fe85d580ad9b1621f432d3e22fc6753`; PDF `d09cca1f7f0fcec991d00b53e4c5ec030fb6625a57a1ffc81a676a601b657eec`.

## Mathematical setting

Boolean and vectorial functions over F₂, principally m=6. Components are taken modulo affine functions. Exact normalized fourth moment is κ(f)=Σa Wf(a)^4/2^(3m). A zero-image two-flat is four distinct points x,y,z,t with x⊕y⊕z⊕t=0 and G(x)⊕G(y)⊕G(z)⊕G(t)=0. Its added coordinates must XOR to a nonzero value. A one-coordinate extension is an affine F₂ system; a two-coordinate extension uses GF(4) nonzero constraints. Native equivalence uses Kaleyski–Sunde (2026/940), independently implemented; this changes the backend, not the GL mathematical extension method.

## Claims inventory

### lifted-moment-invariant

- **ID:** lifted-moment-invariant
- **Type:** Algorithm
- **Section + number:** 2; invariant lifting construction
- **Statement:** Compute the EA-invariant multiset of unordered κ-value pairs on complementary affine hyperplanes, a precise instantiation of the paper's general lift.
- **Reproducibility:** Exact instantiation; the unspecified 150355-value author invariant is not claimed reproduced
- **VBF APIs used:** walsh_hadamard, parity
- **Estimated cost:** Fast
- **Julia file / Makefile target:** `section2.jl` / `section2`
- **Implementation distinction:** Literal baseline and separately committed equivalent spectral backend; Table 4 explicitly selects spectral.

### boolean-classification

- **ID:** boolean-classification
- **Type:** Experiment
- **Section + number:** 2; Table 1
- **Statement:** Recompute the 15 degree/fourth-moment bins below 2 from 150356 author Boolean representatives.
- **Reproducibility:** Author-artifact
- **VBF APIs likely needed:** walsh_hadamard, algebraic_degree
- **Estimated cost:** Medium
- **Proposed Julia file:** `table1.jl`
- **Proposed Makefile target:** `table1`

### counting-functions

- **ID:** counting-functions
- **Type:** Algorithm
- **Section + number:** 3
- **Statement:** Build derivative-support Boolean counting functions and verify their autocorrelation identity.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** walsh_hadamard, differential_uniformity
- **Estimated cost:** Fast
- **Proposed Julia file:** `section3.jl`
- **Proposed Makefile target:** `section3`

### even-moment-levels

- **ID:** even-moment-levels
- **Type:** Lemma
- **Section + number:** 4; Lemma 1
- **Statement:** Every even-dimensional APN has at least two component fourth-moment levels; test the exact identity on finite inputs.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** walsh_hadamard, differential_uniformity
- **Estimated cost:** Fast
- **Proposed Julia file:** `lemma1.jl`
- **Proposed Makefile target:** `lemma1`

### known-six-representatives

- **ID:** known-six-representatives
- **Type:** Experiment
- **Section + number:** 5.1; Table 2
- **Statement:** Validate 14 printed Code64 roots and recover their EA closures and degree counts.
- **Reproducibility:** Bounded
- **VBF APIs likely needed:** ea_class_representatives, gamma_rank
- **Estimated cost:** Slow
- **Proposed Julia file:** `table2.jl`
- **Proposed Makefile target:** `table2`

### ccz-invariants

- **ID:** ccz-invariants
- **Type:** Experiment
- **Section + number:** 5.2; Table 3; Invariants 1–3
- **Statement:** Compare the multiplicative, valuation, gamma/delta-rank and transvection invariants on the 14 roots.
- **Reproducibility:** Bounded
- **VBF APIs likely needed:** gamma_rank, delta_rank, anf, walsh_hadamard
- **Estimated cost:** Slow
- **Proposed Julia file:** `table3.jl`
- **Proposed Makefile target:** `table3`

### component-classification

- **ID:** component-classification
- **Type:** Fact
- **Section + number:** 5.3; Fact 1; Table 4
- **Statement:** The 45108 nonzero components of 716 known EA classes occupy 37 Boolean classes and eight moment levels.
- **Reproducibility:** Author-artifact
- **VBF APIs likely needed:** partition_refinement_equivalence, algebraic_degree, walsh_hadamard
- **Estimated cost:** Slow
- **Proposed Julia file:** `table4.jl`
- **Proposed Makefile target:** `table4`

### affine-counting

- **ID:** affine-counting
- **Type:** Fact
- **Section + number:** 5.4; Fact 2; Table 5
- **Statement:** Each known six-bit APN admits an affine counting function; measure the degree distribution.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** algebraic_degree, differential_uniformity
- **Estimated cost:** Medium
- **Proposed Julia file:** `table5.jl`
- **Proposed Makefile target:** `table5`

### type-one-four

- **ID:** type-one-four
- **Type:** Proposition
- **Section + number:** 5.5; Proposition 1
- **Statement:** Every six-bit APN of fourth-moment type (1,4) is quadratic; finite known-input checking accompanies the stated theoretical proof.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** algebraic_degree, walsh_hadamard
- **Estimated cost:** Medium
- **Proposed Julia file:** `proposition1.jl`
- **Proposed Makefile target:** `proposition1`

### one-coordinate-kernel

- **ID:** one-coordinate-kernel
- **Type:** Lemma
- **Section + number:** 6; Lemma 2
- **Statement:** The nontrivial one-coordinate switching quotient has dimension dim K(G)−2m for an APN projection.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** apn_extension_space, switching_neighbors_bounded
- **Estimated cost:** Fast
- **Proposed Julia file:** `lemma2.jl`
- **Proposed Makefile target:** `lemma2`

### one-coordinate-closure

- **ID:** one-coordinate-closure
- **Type:** Fact
- **Section + number:** 6; Fact 3
- **Statement:** Enumerate 45108 codimension-one projections, classify all nontrivial completions, and check two connected CCZ components.
- **Reproducibility:** Bounded
- **VBF APIs likely needed:** switching_neighbors_bounded, partition_refinement_equivalence
- **Estimated cost:** Slow
- **Proposed Julia file:** `section6.jl`
- **Proposed Makefile target:** `section6`

### two-coordinate-closure

- **ID:** two-coordinate-closure
- **Type:** Fact
- **Section + number:** 7; Fact 4; Table 6
- **Statement:** Enumerate 466116 codimension-two projections, apply necessary tests and bounded normalized two-output extension searches.
- **Reproducibility:** Bounded
- **VBF APIs likely needed:** apn_extension_tests, apn_extensions, partition_refinement_equivalence
- **Estimated cost:** Slow
- **Proposed Julia file:** `table6.jl`
- **Proposed Makefile target:** `table6`

### two-level-configurations

- **ID:** two-level-configurations
- **Type:** Experiment
- **Section + number:** 8; Table 7
- **Statement:** Recover the four arithmetic moment/multiplicity configurations and their author Boolean seed counts.
- **Reproducibility:** Author-artifact
- **VBF APIs likely needed:** walsh_hadamard, algebraic_degree
- **Estimated cost:** Medium
- **Proposed Julia file:** `table7.jl`
- **Proposed Makefile target:** `table7`

### two-level-search

- **ID:** two-level-search
- **Type:** Fact
- **Section + number:** 8; Fact 5
- **Statement:** Build compatible cubic/quartic subspaces and extend them; classify any type (1.75,4) completions against Dublin.
- **Reproducibility:** Bounded
- **VBF APIs likely needed:** apn_extension_tests, apn_extensions, partition_refinement_equivalence
- **Estimated cost:** Slow
- **Proposed Julia file:** `section8.jl`
- **Proposed Makefile target:** `section8`

### derivative-bound

- **ID:** derivative-bound
- **Type:** Lemma
- **Section + number:** 8; Lemma 3
- **Statement:** An (m,n) function with a square APN extension must have differential uniformity at most 2^(m−n+1).
- **Reproducibility:** Exact
- **VBF APIs likely needed:** differential_uniformity, apn_extension_tests
- **Estimated cost:** Fast
- **Proposed Julia file:** `lemma3.jl`
- **Proposed Makefile target:** `lemma3`

### linearized-obstruction

- **ID:** linearized-obstruction
- **Type:** Lemma
- **Section + number:** 8; Lemma 4
- **Statement:** Inconsistency of the GF(4)-cube linearization certifies that no two-coordinate APN extension exists.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** apn_extension_tests
- **Estimated cost:** Medium
- **Proposed Julia file:** `lemma4.jl`
- **Proposed Makefile target:** `lemma4`

### bent-subspace-census

- **ID:** bent-subspace-census
- **Type:** Experiment
- **Section + number:** 9; Table 8
- **Statement:** Count bent three-dimensional component spaces in all 716 known EA representatives.
- **Reproducibility:** Exact
- **VBF APIs likely needed:** walsh_hadamard, extract_linear_subspaces
- **Estimated cost:** Medium
- **Proposed Julia file:** `table8.jl`
- **Proposed Makefile target:** `table8`

### bent-extensions

- **ID:** bent-extensions
- **Type:** Fact
- **Section + number:** 9; Fact 6; Table 9
- **Statement:** Extend the 13 (6,3) bent EA roots; verify eight empty extension sets and classify the remaining union of 150 known EA classes.
- **Reproducibility:** Bounded
- **VBF APIs likely needed:** apn_extensions, partition_refinement_equivalence
- **Estimated cost:** Slow
- **Proposed Julia file:** `table9.jl`
- **Proposed Makefile target:** `table9`

### global-conjectures

- **ID:** global-conjectures
- **Type:** Conjecture
- **Section + number:** 1 and 5; Conjectures 1 and 2
- **Statement:** Known six-bit completeness and the universal degree bound remain conjectures, regardless of finite closure checks.
- **Reproducibility:** Out-of-scope
- **VBF APIs likely needed:** none
- **Estimated cost:** Slow
- **Proposed Julia file:** `report.jl`
- **Proposed Makefile target:** `report`

## Routines checklist

1. Parse and hash author Boolean ANFs and the 13 primary bent roots.
2. Exact component moments, counting functions and bounded rectangular extension primitives.
3. Consume the saved 716-representative closure without including another paper.
4. Classify completions with independently verified native EA/CCZ maps; preserve inconclusive searches.
5. Run practical Tables 1–9 with explicit measured limits and optional checkpoints.
6. Record printed-versus-computed discrepancies rather than silently correcting published tables.

## Open questions and source discrepancies

- Section 7 prints 615 codimension-two subspaces; the exact Gaussian coefficient is 651, consistent with Table 6 and 716×651=466116.
- Section 9 prints an impossible repeated Gaussian-coefficient formula for 108206 echelon spaces. The rank-0-through-3 sum 1+255+10795+97155 equals 108206.
- Table 4 header class counts contradict the listed 37 IDs: at κ=1.75 it prints four but lists six; at κ=4 it prints four but lists five. Retain both published and observed figures.
- Table 5 multiplicities sum to 503 rather than 716; its reported cubic count also conflicts with the independently reproduced 521. The fresh census is authoritative for this implementation.
- Table 2 Code64 rows are cyclically displaced by five from the degree/Γ columns; match by certified equivalence, never row position.
- The Section 6 APN column appears to count kernel-basis directions weighted by quotient dimension, not every nonzero quotient combination. Full enumeration and basis-only counts must be separate.
- Table 9 row EA counts sum to 193, while the claimed union is 150; overlaps must be deduplicated with certificates. The sentence “8 of 14” conflicts with the 13 bent roots.
- The author bent-3-3.txt is a batch of 240 truth tables, not the stated 13 class representatives; source those 13 from Polujan–Pott (arXiv:2003.12308v3), Appendix A.
- Author baby-1-5-5.dat has 206 records including both zero and a linear function: its orbit convention must be verified before treating its record numbers as EA class IDs.
- Invariant 1 has inconsistent RM arguments and an unused parameter; Section 9 filtration parameters and Invariant 3 stabilizer definition are insufficiently specified. Implement only interpretations justified by source/reference artifacts; unresolved values are explicitly unverified.
- Section 8 includes “Applying the procedure using ?” and an unlabeled intermediate table. Normalization and counters may differ from author timings; do not claim literal table identity without resolving these details.
- No finite closure or table reproduction proves either global conjecture.

## Author artifacts

The primary author index is https://langevin.univ-tln.fr/project/switch/switch.html (data: project/switch/data/sw.tar). Boolean classification: https://langevin.univ-tln.fr/data/bst/class-2-6.txt (150356 ANFs; SHA-256 `74cee20ea2db689ea6cebe4cc4f482e44d64eae4444b83cb93a32a425ce43628`). Five-bit data: baby-1-5-5.dat (`07a3a896ee032c63041caa5914928c43ca7767f182bf4a3bd6441482bd8b89aa`). Raw bent batch: https://langevin.univ-tln.fr/project/vectorial/data/bent-3-3.txt (`d5d6e8382b01b69b25a6f8d7d20480bfd8079002c3e5436df83d5f13da915bc0`). These copyrighted inputs remain ignored.

## Executed scope

Tables 1, 4, 5, 7 and 8 were run on their complete finite inputs. Table 7 retains a convention discrepancy: its second β=4 degree-2-or-3 seed count is seven in the primary data, versus six printed; six counts cubic seeds alone. All fourteen Table 2 roots and the specified Table 3 interpretations were computed; Table 3 remains incomplete because author parameters are unresolved. Lemma 1 and Proposition 1 were checked on all 716 known inputs. Section 6 audited all 716 parents, 45108 directions and 20674 completion certificates against complete saved constructor metadata; its basis count is 11598, with the basis-dependent class column unverified. Table 6, Section 8 and Table 9 ran bounded profiles on every relevant seed type, with limits and incomplete status retained. Full two-coordinate closure, universal proofs, unspecified invariants and the complete bent-extension union remain unverified. See README.md and TEST_REPORT.md for actual timings and evidence paths.
