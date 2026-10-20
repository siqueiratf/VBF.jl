# Review of the n = 10 search method (2026-10-20)

This review compares the n = 10 prototype with the n = 8 pipeline, from the
code and from controlled experiments on the 25 quadratic n = 10 classes of the
catalog. It separates verified results (V) from hypotheses (H). No result here
is exhaustive unless it says so.

## 1. Component comparison

| Component | n = 8 code | n = 10 prototype | Effect |
|---|---|---|---|
| Exchange: anchor | all 5-dim V_5 < C2(F) with maximal bent count (about 3 per seed) | all 7-dim V_7 < C2(F) with maximal bent count | V: at n = 10 this rule is not selective. 22 of 25 seeds have M_7 = 94 and about 345,000 anchors each (`anchors_n10.jl`). |
| Exchange: target b(U) | fixed global value `target_b6 = 52` (`VBFSearch/src/drivers.jl:40`) | max b(U_8) over U_8 >= V_7 inside the parent (178 to 198) | H: the n = 10 target favours the parent. It selects cosets that look like the parent's own best subspaces. |
| Re-extension | exact enumeration of t with a kernel cap (`max_kernel = 23`, flagged) | Lee-Brickell ISD, probabilistic | V: recall 21/24 = 0.875 at 30k iterations (E1); the misses are random. The default is now 120k iterations. |
| Prefilter | Lemma 3.12 of Beierle et al. (delta <= 8) | the same test, `passes_delta8` | V: equal to the direct delta on 400/400 hits (E2). It is exact and has no bias. |
| Switching | separate move, complete system (`VBF.switching_neighbors`) | absent; added as `e3_quadswitch.jl` | V: the complete VBF version takes more than 50 min per seed at n = 10. The new quadratic version takes 10-80 s and is exact for quadratic neighbours. |
| Closure | old BFS: only search-new functions with B6 = 52 are queued (`search_b52/search.jl:49,134`); the new engine does not recurse | absent | V: the n = 8 paper draft says that descendants have no profile filter; the old code applies one. The text and the code disagree. |
| Novelty | sigma against the reference index, EA solver for equal sigma | sigma against the 25 catalog classes, `are_ea_equivalent` confirms each label | V: correct for quadratic APN (EA = CCZ, Yoshiara 2012). Novelty is relative to the catalog, which holds the published classes found up to 2026-10-17. |

## 2. Structure of the moves

For a quadratic APN F, every move keeps a subspace of C2(F) and replaces the rest:

- quadratic switching keeps a 9-dim subspace (codimension 1);
- re-extension of U_8 < C2(F) keeps 8 dimensions (codimension 2);
- the exchange keeps the 7-dim anchor and adds q outside C2(F) (codimension 3).

Every child of a move of codimension k shares a subspace of dimension at least
10 - k with the parent. The exchange with q outside C2(F) is the only move here
that can give a child with dim(C2(F) ∩ C2(G)) = 7.

## 3. Experiments

| Experiment | Scope | Result |
|---|---|---|
| E1 ISD recall | the certain in-C2 extensions of anchors 1-6 of Beierle-Leander 3 | V: 21 of 24 found at 30k iterations; all 3 misses found with another random seed |
| E2 prefilter | 400 random hits | V: agrees with the direct delta on 400 of 400 |
| E3 quadratic switching | all 25 seeds, complete for quadratic neighbours | V: it finds again the published relations (Gold x^3 -> both BCL 2009 classes; Li-Zhou-Li-Qu <-> Triplicate 6, the HIK 2026 pair Fl -> F1; Triplicate 3 <-> 4, the HIK pair F2/F3). 19 seeds have no nontrivial direction. No new class: the known set is closed under quadratic switching. |
| E4 re-extension inside C2 | 60 random U_8 per seed (0.034% of the 174,251), 60k iterations | V: 23 of 25 seeds give only themselves; Gold x^3 and x^3 + Tr(x^9) give known BCL classes. H: most seeds are rigid in codimension 2; the sample is too small to prove it. |
| Pilot exchange | Beierle-Leander 3, all 31 maximal anchors, all 2^38 cosets each, target 190 | V: 158,007 hits, 10,385 passed the prefilter, 104 extensions, all equal to C2(seed) (canonical basis and EA test); no U_8 with q outside C2 extended. |

| W1 target window | anchor 1 of Beierle-Leander 3, window 78:82, 2^32 cosets (1/64), 60k iterations | V: 26,616 hits, 711 passed the prefilter (2.7%), 1 APN space (known, sigma of the seed), 0 new. Histogram of 2^30 cosets: counts are even, mean about 54; an APN child containing this V_7 has 82.3 bent forms per other coset on average. |

Coverage of the pilot: the exchange covered every coset of every maximal anchor
of one seed, but only cosets with exactly the target count. That is a fraction
1.9e-8 of all U_8 = V_7 + <q>, and 31 of the 6.35 M 7-dim subspaces of C2(F).

## 4. What the results show

1. V: the moves and checks are correct. Switching finds every published
   switching relation among the known classes, and re-extension finds the
   parent and the BCL classes again.
2. V: the 25 known classes are closed under quadratic switching. H: they are
   also nearly closed under codimension-2 re-extension.
3. V: for Beierle-Leander 3, the exchange with the parent-specific target found
   only the parent, and the wider window 78:82 (W1) did not change this. In
   about 11,000 U_8 with q outside C2 that passed the prefilter, none extended.
   H: the target rule is not the main obstacle. APN spaces that share a
   bent-maximal 7-dim anchor with this seed are very rare or absent.
4. H: new n = 10 classes, if they exist near the known ones, are at
   codimension 3 or more, or in other EA classes of the same CCZ class.

## 5. Proposed improvements, in priority order

| # | Change | Why | Cost (measured or estimated) |
|---|---|---|---|
| 1 | Exchange with a target window learned from APN spaces, not the parent maximum | removes the bias toward the parent | the hits grow fast outside the tail: run a 2^30-coset pilot per window value first to measure hits, prefilter rate and yield |
| 2 | Switching from the non-quadratic EA classes inside each CCZ class (the route of Edel-Pott at n = 6) | the quadratic switching graph of the known classes is closed; other EA representatives have other neighbours | complete VBF switching, more than 50 min per function; parallel on the 16 server cores |
| 3 | Exhaustive codimension-2 re-extension for the seeds with symmetry, sampled for the others | E4 covered 0.034% only | 174,251 ISD runs per seed, about 72 CPU-hours at 60k iterations; orbits reduce it for Gold and the BCL classes |
| 4 | Anchor rule from the lexicographic flag profile, from a (10,5)-bent V_5 | the maximal-V_7 rule gives 7.6 M anchors | H: a few hundred bent V_5 per seed; to be measured |
| 5 | Closure driver: switching, then re-extension, then exchange, on each admitted class, with the same persistence as `pilot_stream.jl` | without it a new class never becomes a parent | small code; it is useful only after a new class appears |

Experiment 1 was run as W1 (section 3) and gave no new class. Experiment 2
(switching from the other EA classes of each CCZ class) is now the first one
to run, because it tests the remaining main hypothesis.

## 6. Reproduction

All scripts are in this folder and use fixed random seeds. Results go to
`results/` (ignored by git). See `gpu/README.md` for the GPU setup.

| Result | Command (from the repository root) |
|---|---|
| anchors | `julia -t 12 --project=. packages/VBFSearch/prototypes/n10/anchors_n10.jl` |
| E1, E2 | `julia -t 12 --project=. packages/VBFSearch/prototypes/n10/experiments_e1e2.jl` |
| E3 | `julia --project=. packages/VBFSearch/prototypes/n10/e3_quadswitch.jl` |
| E4 | `julia -t 12 --project=. packages/VBFSearch/prototypes/n10/e4_compmode.jl 60 60000` |
| pilot | `pilot_export.jl`, then `gpu/scan_anchors.jl` on the GPU, then `pilot_stream.jl` |
