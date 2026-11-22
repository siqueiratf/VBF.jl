#!/usr/bin/env python3
"""Build the binary arrays of the class explorer page (/explorer).

    explorer_data.py --classes classes.sqlite --features features.sqlite
                     --genealogy genealogy.sqlite --out DIR [--pairs pairs.u32]

DIR/<version>/ gets one little-endian array per field, index i = class id - 1
(admission order), and DIR/current.json names the version:

  two.i16, three.i16   invariants (-1 when not measured yet)
  jitter.i8            two values per class: the unit-disk cell offset of
                       apn-layout/src/layout.rs, times 127
  status.u8            0 catalog-matching, 1 new, 2 published seed, 3 unknown
  method.u8            0 seed or none, 1 v5, 2 switching (first path)
  generation.u16       0 for a seed, discoverer's generation + 1; 65535 unknown
  family.u8            colour index (0..23) of the root seed of the lineage
  discoverer.u32       class id of the discoverer (0 for a seed or unknown)
  root.u32             class id of the root seed (0 unknown)
  time.f32             seconds since the first admission
  found.u16            construction paths that reached the class (capped)
  finders.u8           distinct parents among them (capped at 255)
  expanded.u8          1 when the class is an expanded parent (construction done)
  spaces.u16           maximizing 5-spaces (v5 jobs) as a parent
  cosets.f32           v5 cosets checked as a parent
  reached.u16          distinct classes its paths reached (with --pairs; capped)
  reached_new.u16      the new ones among them (signature absent from the catalog)
  inv.u8               four values per class: du (differential uniformity of the
                       ortho-derivative), c4 and c2 (components of rank 4 and 2),
                       four (entry 4 of the nonbent signature); 255 = not measured

meta.json gives the count, the time origin, the ranges and the provenance.
"""
import argparse, json, sqlite3, time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np


def disk_jitter(shas):
    raw = np.frombuffer(bytes.fromhex("".join(s[:32] for s in shas)), dtype="<u8").reshape(-1, 2)
    unit = lambda w: (w >> np.uint64(11)).astype(np.float64) * (1.0 / 9007199254740992.0) * 2.0 - 1.0
    u, v = unit(raw[:, 0]), unit(raw[:, 1])
    return u * np.sqrt(1.0 - v * v / 2.0), v * np.sqrt(1.0 - u * u / 2.0)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--classes", required=True); p.add_argument("--features", required=True)
    p.add_argument("--genealogy", required=True); p.add_argument("--out", required=True)
    p.add_argument("--pairs", help="(parent, class) uint32 pairs from genealogy_extract.py")
    a = p.parse_args()
    t0 = time.time()
    g = sqlite3.connect(f"file:{a.genealogy}?mode=ro", uri=True)
    rows = g.execute("SELECT id, admitted, seed, discoverer, method, found, finders, spaces, cosets, expanded "
                     "FROM genealogy ORDER BY id").fetchall()
    g.close()
    n = rows[-1][0]
    if n != len(rows):
        raise SystemExit("explorer_data: the genealogy ids are not contiguous")
    gen = np.array(rows, dtype=np.float64)
    admitted, seed, disc = gen[:, 1], gen[:, 2].astype(bool), gen[:, 3].astype(np.int64)
    method = gen[:, 4].astype(np.uint8); found = np.minimum(gen[:, 5], 65535).astype(np.uint16)
    finders = np.minimum(gen[:, 6], 255).astype(np.uint8)
    spaces = np.minimum(gen[:, 7], 65535).astype(np.uint16); cosets = gen[:, 8].astype(np.float32)
    expanded = gen[:, 9].astype(np.uint8)
    generation = np.full(n + 1, 65535, dtype=np.int64); root = np.zeros(n + 1, dtype=np.int64)
    for i in range(1, n + 1):  # discoverers are admitted earlier, so one pass in id order is enough
        if seed[i - 1]:
            generation[i] = 0; root[i] = i
        else:
            d = disc[i - 1]
            if 0 < d < i and generation[d] < 65535:
                generation[i] = generation[d] + 1; root[i] = root[d]
    print(f"genealogy {n} classes in {time.time()-t0:.0f}s", flush=True)
    c = sqlite3.connect(f"file:{a.classes}?mode=ro", uri=True)
    c.execute("ATTACH ? AS f", (f"file:{a.features}?mode=ro",))
    shas = [""] * n; status = np.full(n, 3, dtype=np.uint8)
    two = np.full(n, -1, dtype=np.int16); three = np.full(n, -1, dtype=np.int16)
    inv = np.full((n, 4), 255, dtype=np.uint8)
    for cid, sha, absent, origin, t2, t3, du, c4, c2, four in c.execute(
            "SELECT c.id, c.sha, c.absent, c.origin, f.two, f.three, f.du, f.c4, f.c2, f.four "
            "FROM classes c LEFT JOIN f.features f ON f.sha=c.sha"):
        if cid > n:
            continue
        shas[cid - 1] = sha
        status[cid - 1] = 2 if origin == "root" else (1 if absent else 0)
        if t2 is not None and t3 is not None:
            two[cid - 1], three[cid - 1] = t2, t3
            inv[cid - 1] = (du, c4, c2, four)
    c.close()
    missing = [i for i, s in enumerate(shas) if not s]
    for i in missing:  # classes admitted after the report copy: no sha yet
        shas[i] = "0" * 64
    dx, dy = disk_jitter(shas)
    jitter = np.stack([np.round(dx * 127), np.round(dy * 127)], axis=1).astype(np.int8)
    print(f"classes and features in {time.time()-t0:.0f}s ({len(missing)} without a report row)", flush=True)
    family = (root[1:] * 2654435761 % 2**32 % 24).astype(np.uint8)
    reached = np.zeros(n, dtype=np.uint16); reached_new = np.zeros(n, dtype=np.uint16)
    if a.pairs:
        pairs = np.fromfile(a.pairs, "<u4").reshape(-1, 2).astype(np.int64)
        pairs = pairs[(pairs[:, 0] >= 1) & (pairs[:, 0] <= n) & (pairs[:, 1] >= 1) & (pairs[:, 1] <= n)]
        pairs = np.unique(pairs[:, 0] * (n + 1) + pairs[:, 1])  # distinct (parent, class)
        par, cls = pairs // (n + 1) - 1, pairs % (n + 1) - 1
        reached = np.minimum(np.bincount(par, minlength=n), 65535).astype(np.uint16)
        reached_new = np.minimum(np.bincount(par, weights=(status[cls] == 1), minlength=n), 65535).astype(np.uint16)
        print(f"pairs: {len(pairs):,} distinct in {time.time()-t0:.0f}s", flush=True)
    origin_time = float(admitted.min())
    fields = {"two.i16": two, "three.i16": three, "jitter.i8": jitter, "status.u8": status, "method.u8": method,
              "generation.u16": np.minimum(generation[1:], 65535).astype(np.uint16), "family.u8": family,
              "discoverer.u32": disc.astype(np.uint32), "root.u32": root[1:].astype(np.uint32),
              "time.f32": (admitted - origin_time).astype(np.float32), "found.u16": found, "finders.u8": finders,
              "expanded.u8": expanded, "spaces.u16": spaces, "cosets.f32": cosets,
              "reached.u16": reached, "reached_new.u16": reached_new, "inv.u8": inv}
    version = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + f"-{n}"
    out = Path(a.out); target = out / version; target.mkdir(parents=True, exist_ok=True)
    for name, array in fields.items():
        np.ascontiguousarray(array).astype(array.dtype.newbyteorder("<")).tofile(target / name)
    measured = two >= 0
    known = generation[1:] < 65535
    meta = {"version": version, "count": n, "time_origin_utc": datetime.fromtimestamp(origin_time, timezone.utc).isoformat(),
            "time_span_seconds": float(admitted.max() - origin_time), "seeds": int(seed.sum()),
            "measured": int(measured.sum()), "new": int((status == 1).sum()), "catalog": int((status == 0).sum()),
            "unknown": int((status == 3).sum()), "generation_max": int(generation[1:][known].max()),
            "found_max": int(found.max()), "expanded": int(expanded.sum()), "spaces_max": int(spaces.max()),
            "reached_new_max": int(reached_new.max()),
            "du_range": [int(inv[measured, 0].min()), int(inv[measured, 0].max())] if measured.any() else [0, 1],
            "new_per_mcoset_p99": float(np.percentile((1e6 * reached_new / np.maximum(cosets, 1))[expanded > 0], 99)) if expanded.any() else 1.0, "two_range": [int(two[measured].min()), int(two[measured].max())],
            "three_range": [int(three[measured].min()), int(three[measured].max())],
            "fields": {k: str(v.dtype) for k, v in fields.items()},
            "sources": {"classes": a.classes, "features": a.features, "genealogy": a.genealogy},
            "method_codes": {"0": "seed or none", "1": "v5", "2": "switching"},
            "status_codes": {"0": "catalog-matching", "1": "new", "2": "published seed", "3": "unknown"}}
    (target / "meta.json").write_text(json.dumps(meta, indent=1))
    tmp = out / ".current.json"; tmp.write_text(json.dumps({"version": version})); tmp.replace(out / "current.json")
    for old in sorted(p for p in out.iterdir() if p.is_dir() and p.name[:1].isdigit() and p.name != version)[:-1]:
        for f in old.iterdir():
            f.unlink()
        old.rmdir()
    print(json.dumps({k: meta[k] for k in ("version", "count", "measured", "generation_max", "found_max")}), flush=True)


if __name__ == "__main__":
    main()
