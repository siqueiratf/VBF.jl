#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy>=1.26", "pyarrow>=15"]
# ///
"""Export a class-graph snapshot (closure_graph.jl output) as compact CSR files.

  export_graph.py SNAPSHOT OUT [--reports DIR] [--subsets 1000,10000,100000]

SNAPSHOT is a folder with edges.bin, flags.bin and nodes-*.json. --reports adds
the columns of classes.sqlite and features.sqlite; each row is matched by class
id and must have the same LUT SHA-256. OUT gets:

  out.offsets.u64 out.targets.u32 out.methods.u8   CSR of out-edges
  in.offsets.u64  in.sources.u32  in.methods.u8    CSR of in-edges (CSC)
  nodes.parquet   one row per vertex (vertex = class id - 1)
  edges.parquet   src, dst, methods (portable edge list)
  manifest.json   counts, formats, provenance and SHA-256 of each file
  subsets/<N>/    induced subgraphs of N vertices (breadth-first, undirected,
                  from vertex 0), same layout

All binary files are little-endian. methods: bit 0 = V5, bit 1 = switching.
Self-loops are not edges; nodes.parquet keeps their counts.
"""
import argparse, glob, hashlib, json, os, sqlite3, sys, time
from collections import deque
import numpy as np
import pyarrow as pa
import pyarrow.parquet as pq

SCHEMA = "vbf-apn-class-graph-csr-v1"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 22), b""):
            h.update(b)
    return h.hexdigest()


def read_snapshot(snap):
    flags = np.fromfile(os.path.join(snap, "flags.bin"), dtype="<u1")
    n = len(flags)
    raw = np.fromfile(os.path.join(snap, "edges.bin"), dtype="<u4").reshape(-1, 2)
    src = raw[:, 0].astype(np.uint32)
    dst = (raw[:, 1] & 0x3FFFFFFF).astype(np.uint32)
    method = np.where(raw[:, 1] & 0x80000000, 2, 1).astype(np.uint8)
    # edges.bin has one record per method; merge them into one edge with a bit mask.
    key = (src.astype(np.uint64) << 32) | dst
    order = np.argsort(key, kind="stable")
    key, method = key[order], method[order]
    uniq, first = np.unique(key, return_index=True)
    methods = np.bitwise_or.reduceat(method, first)
    src = (uniq >> 32).astype(np.uint32)
    dst = (uniq & 0xFFFFFFFF).astype(np.uint32)
    if src.size and max(src.max(), dst.max()) >= n:
        sys.exit("edge endpoint outside the vertex range")
    nodes = []
    for path in sorted(glob.glob(os.path.join(snap, "nodes-*.json")),
                       key=lambda p: int(p.rsplit("-", 1)[1].split(".")[0])):
        nodes.extend(json.load(open(path)))
    if len(nodes) != n or any(r["id"] != i + 1 for i, r in enumerate(nodes)):
        sys.exit("nodes-*.json does not hold ids 1..n in order")
    return n, src, dst, methods, flags, nodes


def csr(n, rows, cols, vals):
    order = np.lexsort((cols, rows))
    counts = np.bincount(rows, minlength=n).astype(np.uint64)
    offsets = np.zeros(n + 1, dtype=np.uint64)
    np.cumsum(counts, out=offsets[1:])
    return offsets, cols[order].astype(np.uint32), vals[order].astype(np.uint8)


def weak_components(n, src, dst):
    parent = np.arange(n, dtype=np.int64)
    def find(x):
        root = x
        while parent[root] != root:
            root = parent[root]
        while parent[x] != root:
            parent[x], x = root, parent[x]
        return root
    for a, b in zip(src.tolist(), dst.tolist()):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)
    roots = np.array([find(i) for i in range(n)], dtype=np.int64)
    _, label, sizes = np.unique(roots, return_inverse=True, return_counts=True)
    rank = np.argsort(-sizes, kind="stable")  # component 0 = largest
    relabel = np.empty_like(rank)
    relabel[rank] = np.arange(len(rank))
    return relabel[label].astype(np.uint32), sizes[rank]


def write_graph(out, n, src, dst, methods, table, provenance):
    os.makedirs(out, exist_ok=True)
    o_off, o_tgt, o_met = csr(n, src, dst, methods)
    i_off, i_src, i_met = csr(n, dst, src, methods)
    for name, arr in (("out.offsets.u64", o_off), ("out.targets.u32", o_tgt), ("out.methods.u8", o_met),
                      ("in.offsets.u64", i_off), ("in.sources.u32", i_src), ("in.methods.u8", i_met)):
        arr.astype(arr.dtype.newbyteorder("<")).tofile(os.path.join(out, name))
    pq.write_table(table, os.path.join(out, "nodes.parquet"), compression="zstd")
    pq.write_table(pa.table({"src": src, "dst": dst, "methods": methods}),
                   os.path.join(out, "edges.parquet"), compression="zstd")
    files = {f: {"bytes": os.path.getsize(os.path.join(out, f)), "sha256": sha256(os.path.join(out, f))}
             for f in sorted(os.listdir(out)) if os.path.isfile(os.path.join(out, f)) and f != "manifest.json"}
    manifest = {
        "schema": SCHEMA, "created_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "vertices": int(n), "edges": int(len(src)),
        "edges_by_method": {"v5_only": int((methods == 1).sum()), "switching_only": int((methods == 2).sum()),
                            "both": int((methods == 3).sum())},
        "format": {
            "endianness": "little",
            "vertex": "0-based index; class_id = vertex + 1 (nodes.parquet keeps both)",
            "out": "out.offsets.u64 has vertices+1 entries; out-neighbours of v are "
                   "out.targets.u32[out.offsets[v]:out.offsets[v+1]], sorted",
            "in": "same layout for in-neighbours (in.offsets.u64, in.sources.u32)",
            "methods": "u8 per edge: bit 0 = V5 extension, bit 1 = switching",
            "direction": "parent -> child: the child class was constructed from the parent",
            "self_loops": "not stored as edges; see nodes.parquet v5_self_loops, switching_self_loops",
        },
        "semantics": "Observed construction graph of quadratic APN EA classes in dimension 8. "
                     "Coverage is incomplete; a community is not a CCZ class.",
        "provenance": provenance, "files": files,
    }
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)
    return manifest


def subset(n, src, dst, size, start=0):
    """Breadth-first ball on the undirected graph: a connected set of `size` vertices."""
    und_off, und_adj, _ = csr(n, np.concatenate([src, dst]), np.concatenate([dst, src]),
                              np.zeros(2 * len(src), dtype=np.uint8))
    seen = np.zeros(n, dtype=bool)
    seen[start] = True
    keep, queue = [start], deque([start])
    while queue and len(keep) < size:
        v = queue.popleft()
        for w in und_adj[und_off[v]:und_off[v + 1]].tolist():
            if not seen[w]:
                seen[w] = True
                keep.append(w)
                queue.append(w)
                if len(keep) == size:
                    break
    return np.array(sorted(keep), dtype=np.int64)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snapshot"); ap.add_argument("out")
    ap.add_argument("--reports", help="folder with classes.sqlite and features.sqlite")
    ap.add_argument("--subsets", default="1000,10000,100000")
    a = ap.parse_args()
    t0 = time.time()
    n, src, dst, methods, flags, nodes = read_snapshot(a.snapshot)
    print(f"read {n} vertices, {len(src)} edges ({time.time()-t0:.1f} s)", flush=True)

    wcc, wcc_sizes = weak_components(n, src, dst)
    cols = {
        "vertex": pa.array(np.arange(n, dtype=np.uint32)),
        "class_id": pa.array(np.arange(1, n + 1, dtype=np.uint32)),
        "lut_sha256": pa.array([bytes.fromhex(r["sha256"]) for r in nodes], pa.binary(32)),
        "is_seed": pa.array(flags.astype(bool)),
        "source": pa.array([r["source"] for r in nodes]).dictionary_encode(),
        "out_degree": pa.array(np.bincount(src, minlength=n).astype(np.uint32)),
        "in_degree": pa.array(np.bincount(dst, minlength=n).astype(np.uint32)),
        "v5_self_loops": pa.array(np.array([r["v5_returns"] for r in nodes], dtype=np.uint32)),
        "switching_self_loops": pa.array(np.array([r["switching_returns"] for r in nodes], dtype=np.uint32)),
        "weak_component": pa.array(wcc),
    }
    provenance = {"snapshot": os.path.abspath(a.snapshot),
                  "snapshot_manifest": json.load(open(os.path.join(a.snapshot, "manifest.json")))}
    if a.reports:
        db = sqlite3.connect(f"file:{os.path.join(a.reports, 'classes.sqlite')}?mode=ro", uri=True)
        rows = db.execute("SELECT id, sha, sigma, origin, absent FROM classes WHERE id <= ? ORDER BY id", (n,)).fetchall()
        if len(rows) != n or any(r[0] != i + 1 or r[1] != nodes[i]["sha256"] for i, r in enumerate(rows)):
            sys.exit("classes.sqlite does not match the snapshot ids and LUT digests")
        cols["sigma"] = pa.array([bytes.fromhex(r[2]) for r in rows], pa.binary(32))
        cols["outside_published_catalog"] = pa.array([bool(r[4]) for r in rows])
        fdb = sqlite3.connect(f"file:{os.path.join(a.reports, 'features.sqlite')}?mode=ro", uri=True)
        fcols = [c[1] for c in fdb.execute("PRAGMA table_info(features)") if c[1] != "sha"]
        feats = {r[0]: r[1:] for r in fdb.execute(f"SELECT sha, {', '.join(fcols)} FROM features")}
        for j, c in enumerate(fcols):
            cols[c] = pa.array([feats[r["sha256"]][j] if r["sha256"] in feats else None for r in nodes])
        provenance["reports"] = {f: sha256(os.path.join(a.reports, f)) for f in ("classes.sqlite", "features.sqlite")}
        provenance["reports_note"] = ("classes.sqlite comes from a later run of the same campaign; every row "
                                      "matched this snapshot by class id and LUT SHA-256")
    table = pa.table(cols)
    m = write_graph(a.out, n, src, dst, methods, table, provenance)
    print(f"full graph: {m['vertices']} vertices, {m['edges']} edges, "
          f"{len(wcc_sizes)} weak components ({time.time()-t0:.1f} s)", flush=True)

    for size in [int(s) for s in a.subsets.split(",") if s]:
        keep = subset(n, src, dst, size)
        index = np.full(n, -1, dtype=np.int64)
        index[keep] = np.arange(len(keep))
        mask = (index[src] >= 0) & (index[dst] >= 0)
        sub = table.take(pa.array(keep))
        sub = sub.set_column(0, "vertex", pa.array(np.arange(len(keep), dtype=np.uint32)))
        sub = sub.set_column(sub.schema.get_field_index("out_degree"), "out_degree",
                             pa.array(np.bincount(index[src[mask]], minlength=len(keep)).astype(np.uint32)))
        sub = sub.set_column(sub.schema.get_field_index("in_degree"), "in_degree",
                             pa.array(np.bincount(index[dst[mask]], minlength=len(keep)).astype(np.uint32)))
        sp = dict(provenance, subset={"method": "breadth-first ball on the undirected graph from vertex 0, "
                                      "induced subgraph; vertex renumbered, class_id kept", "size": int(len(keep))})
        sm = write_graph(os.path.join(a.out, "subsets", str(size)), len(keep),
                         index[src[mask]].astype(np.uint32), index[dst[mask]].astype(np.uint32), methods[mask], sub, sp)
        print(f"subset {size}: {sm['vertices']} vertices, {sm['edges']} edges", flush=True)


if __name__ == "__main__":
    main()
