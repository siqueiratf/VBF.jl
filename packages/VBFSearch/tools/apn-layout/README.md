# apn-layout

Writes a graph snapshot of the APN class graph in which each class is
placed by its invariants, not by the search order. The output has the same
files that `docs/inspector/closure_graph.jl` writes, so `closure_monitor.jl`
serves it: at `/graph`, or at `/drawing` from `<run>/drawing`.

```
cargo build --release
# from a closure_graph.jl snapshot and the features cache (used by `vlab dashboard`)
target/release/apn-layout --snapshot RUN/graph/VERSION --features RUN/reports/features.sqlite --out RUN/drawing
# from a CSR export of export_graph.py
target/release/apn-layout --export EXPORT_DIR --out RUN_DIR [--graph-dir DIR]
```

Snapshot mode writes `DRAWING/current.json` and `DRAWING/<version>/`. It reads
the LUT SHA-256 of each vertex from `nodes-*.json` and `(two, three)` from
`features(sha, ..., two, three, ...)`; a class without features goes to the
reserved cell. `edges.bin`, `flags.bin` and `nodes-*.json` are hard-linked (or
copied) from the snapshot; only `positions.bin` and the manifest are new. The
version is `<now>-<suffix of the snapshot version>`.

Export mode writes `RUN_DIR/graph/<version>/` and `RUN_DIR/graph/current.json`
(or `--graph-dir DIR`). The default version is
`<export created_utc>-<completed_parents>-<vertices>`. Both modes take
`--version-tag V`.
`--fixed-time` takes the timestamps from the input and writes 0 for the
timings; two runs then give byte-identical files.

## Position rule

- x = (two - 320) / 140, y = (three - 80) / 100. `two` and `three` are the
  numbers of 2- and 3-dimensional subspaces in the nonbent component set, the
  axes of the `/structure` scatter chart. The bounds two 96..544 and
  three -20..180 fill the box x in [-1.6, 1.6], y in [-1, 1]; the census has
  two 158..460 (even) and three 0..140.
- A cell is 2 units of `two` by 1 unit of `three`. Inside it, the class gets
  an offset in an ellipse of 0.8 half cell, from the first 16 bytes of its
  `lut_sha256` only (see `src/layout.rs`).
- The position depends only on the class. It is the same in every snapshot,
  subset or superset. Only exactly rounded f64 operations are used; no RNG.

Edges, flags and node metadata are the same as `closure_graph.jl`. For the
full 2026-10-19 export, `edges.bin`, `flags.bin` and all `nodes-*.json` are
byte-identical to that builder's snapshot. When the export renumbers
vertices (subsets), each node record also has `class_id`.

## Dependencies

- `parquet` (no arrow, feature `zstd` only): reads `nodes.parquet`.
- `rusqlite` (feature `bundled`): reads `features.sqlite` read-only; the
  bundled SQLite needs no system library and is the same on every machine.
- `serde_json` (feature `preserve_order`) and `serde` (derive): read the
  manifests in key order, and only `sha256` of each node record.
- `sha2`: `builder_sha256` of the sources, and test inputs.
