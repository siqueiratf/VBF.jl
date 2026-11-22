# apn-explorer

Rust analyses of the class explorer data (`tools/analysis/explorer_data.py` arrays and
the `(parent, class)` pairs of `genealogy_extract.py`). The explorer page (`/explorer`)
only draws the JSON output; the `vlab dashboard` update job builds and runs this tool.

    cargo build --release
    target/release/apn-explorer all --data EXPLORER/<version> --pairs pairs.u32 \
        [--catalog catalog_features.sqlite] [--out DIR] [--limit N] [--threads T]

Commands: `heatmaps`, `transitions`, `distributions`, `generations`, `communities`, `all`.
`--limit N` keeps the first N classes (admission order) for benchmarks on subsets.
Output (default `<version>/analysis/`): `heatmaps.json`, `transitions.json`,
`distributions.json`, `in_degree.u32`, `generations.json`, `communities.json`,
`community_louvain.u32`, `community_leiden.u32`. `APN_GAMMA` sets the modularity
resolution (default 1); `APN_NULL=0` skips the configuration-model null.

## Validation

- Heatmaps: 4,448,991 measured classes (as `meta.json`); all 3,809,038 catalog rows in
  cells; novelty by c4 equal to the earlier Python analysis.
- Transitions: the generation of a class via its discoverer gives NMI = 1 (deterministic);
  same-value rates equal the earlier analysis.
- Distributions: the in-degrees sum to the number of distinct edges (18,005,222).
- Generations: 24,294 / 1,213,600 / 3,428,994 classes, as before.
- Communities (`cargo test`): a ring of 30 cliques is recovered exactly with its known
  modularity; aggregation keeps 2m and Q; Leiden communities are connected on random
  graphs. On the data: modularity recomputed on the original graph, a breadth-first test
  for disconnected communities (Leiden 0, Louvain 1), and a configuration-model null.

## Benchmarks (cannon, 12 threads)

| command | 100k classes | 1M classes | 4.67M classes | peak memory (4.67M) |
|---|---|---|---|---|
| heatmaps (with catalog) | 0.03 s | 0.16 s | 4.1 s | 335 MiB |
| distinct edges | 1.1 s | 1.3 s | 2.3 s | 1.1 GiB |
| transitions (12-run null) | 1.3 s | 18.8 s | 55 s | 1.2 GiB |
| distributions | 0.11 s | 1.3 s | 4.5 s | 1.2 GiB |
| generations | 0.01 s | 0.4 s | 1.8 s | 1.1 GiB |
| communities: Louvain / Leiden | 1.0 / 0.8 s | 23 / 18 s | 134 / 69 s | |
| communities: null model, condensed graph | 2.0 s / 1.2 s | | 145 s / 5.7 s | 3.2 GiB |

## What the analyses show (data of 2026-11-22, 4,666,888 classes)

- Novelty depends on the region: c4 = 0 has 28% new classes, c4 >= 1 below 8%; inside a
  lobe the share grows with two. Unreached catalog classes concentrate at high two.
- Parent-to-child dependence is statistically significant only because of N: effect sizes
  stay small (NMI <= 0.014, Cramer's V <= 0.06), and the MI changes with the expansion
  order, so part of it is a search effect.
- The in-degree mostly measures exposure: mean 7.7 -> 1.3 over the admission deciles,
  singletons 12% -> 75% (Spearman -0.45); no real power-law tail. Rediscoveries over all
  paths have a heavy tail (alpha 2.87 from 8). The share of reached classes already known
  grows from 9% to 92% over the expansion order (saturation).
- Breadth-first: generation 2 starts at id 1,237,895; 11% of generation 1 is expanded; 39%
  of the edges of generation-1 parents reach their own generation.
- Communities: Leiden 313 (Q 0.476) against a degree-preserving null at Q 0.299. They
  follow the seed lineages (NMI 0.23) and not the invariants (NMI <= 0.001), so they
  describe the search more than the mathematics. One exception: community 1 (26,738
  classes) is almost closed (conductance 0.019), with 12.4% new and mean two 364.
