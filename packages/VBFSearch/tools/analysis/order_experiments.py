#!/usr/bin/env python3
"""Experiments on the order of construction of the closure search.

    order_experiments.py --explorer DIR/<version> --genealogy genealogy.sqlite
                         --pairs pairs.u32 --out OUT_DIR [--seed 1]

Inputs: the explorer arrays (status, two, three, generation), the genealogy
(per parent cost and expansion flag) and the (parent, class) pair of every
construction path. Writes OUT_DIR/report.json and, when matplotlib is present,
PNG figures. Nothing here touches the search.

E1  Yield of an expanded parent, independent of the search order: the distinct
    classes its paths reached, the new ones among them (signature absent from
    the catalog), and its cost (v5 cosets). Binned means and rank correlations
    against the parent's own data, and a cross-fitted additive model.
E2  Replay. Only expanded parents can be replayed (their reached sets are
    known). A parent becomes available when a seed or an earlier replayed
    expansion reaches it, as in the real search. Policies: admission order
    (the real one), random, the E1 model, and an oracle by true yield (upper
    bound). Measured: new classes found against parents expanded and against
    cosets spent.
E3  Coverage per cell (two, three) with Chao1 from the rediscovery counts.
E4  Heavy parents (more than 32 maximizing 5-spaces or 300 EA jobs) against
    the other expanded parents.
"""
import argparse, heapq, json, sqlite3, time
from pathlib import Path

import numpy as np


def ranks(x):
    r = np.empty(len(x)); r[np.argsort(x, kind="mergesort")] = np.arange(len(x)); return r


def spearman(a, b):
    return float(np.corrcoef(ranks(a), ranks(b))[0, 1]) if len(a) > 2 else float("nan")


def binned(x, y, edges):
    k = np.digitize(x, edges)
    return [{"bin": f"<{edges[0]}" if b == 0 else (f">={edges[-1]}" if b == len(edges) else f"{edges[b-1]}..{edges[b]}"),
             "parents": int((k == b).sum()), "mean": float(y[k == b].mean())} for b in range(len(edges) + 1) if (k == b).sum() >= 50]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--explorer", required=True); p.add_argument("--genealogy", required=True)
    p.add_argument("--pairs", required=True); p.add_argument("--out", required=True)
    p.add_argument("--seed", type=int, default=1)
    a = p.parse_args(); t0 = time.time(); rng = np.random.default_rng(a.seed)
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True); report = {}
    E = Path(a.explorer)
    status = np.fromfile(E / "status.u8", "u1"); two = np.fromfile(E / "two.i16", "<i2").astype(float)
    three = np.fromfile(E / "three.i16", "<i2").astype(float); gen = np.fromfile(E / "generation.u16", "<u2")
    g = sqlite3.connect(f"file:{a.genealogy}?mode=ro", uri=True)
    G = np.array(g.execute("SELECT id, seed, found, spaces, cosets, ea_jobs, expanded, produced FROM genealogy ORDER BY id").fetchall(), dtype=np.float64)
    g.close()
    n = min(len(G), len(status)); G = G[:n]; status, two, three, gen = status[:n], two[:n], three[:n], gen[:n]
    seed, found, spaces, cosets, ea, expanded = G[:, 1] > 0, G[:, 2], G[:, 3], G[:, 4], G[:, 5], G[:, 6] > 0
    pairs = np.fromfile(a.pairs, "<u4").reshape(-1, 2).astype(np.int64)
    pairs = pairs[(pairs[:, 0] >= 1) & (pairs[:, 0] <= n) & (pairs[:, 1] >= 1) & (pairs[:, 1] <= n)]
    order = np.argsort(pairs[:, 0], kind="mergesort"); par, cls = pairs[order, 0], pairs[order, 1] - 1
    offsets = np.searchsorted(par, np.arange(1, n + 2))
    print(f"loaded {n:,} classes, {len(pairs):,} pairs, {expanded.sum():,} expanded parents in {time.time()-t0:.0f}s", flush=True)
    report["counts"] = {"classes": int(n), "pairs": int(len(pairs)), "expanded": int(expanded.sum()), "seeds": int(seed.sum())}

    # ---------- E1: order-independent yield of each expanded parent ----------
    P = np.flatnonzero(expanded)  # 0-based indices
    reached = np.zeros(n); reached_new = np.zeros(n)
    for i in P:
        c = np.unique(cls[offsets[i]:offsets[i + 1]])
        reached[i] = len(c); reached_new[i] = (status[c] == 1).sum()
    cost = np.maximum(cosets, 1)
    m = expanded & (two >= 0)
    feats = {"two": two, "three": three, "own status new": (status == 1).astype(float), "seed": seed.astype(float),
             "generation": gen.astype(float), "own rediscoveries": found, "5-spaces": spaces, "cosets": cosets}
    e1 = {"parents": int(m.sum()), "mean_reached": float(reached[m].mean()), "mean_reached_new": float(reached_new[m].mean()),
          "new_fraction_of_reached": float(reached_new[m].sum() / max(1, reached[m].sum())),
          "spearman_with_reached_new": {k: spearman(v[m], reached_new[m]) for k, v in feats.items()},
          "spearman_with_new_per_coset": {k: spearman(v[m], (reached_new / cost)[m]) for k, v in feats.items()},
          "by_two": binned(two[m], reached_new[m], [300, 340, 360, 380, 400, 420]),
          "by_three": binned(three[m], reached_new[m], [10, 20, 30, 40, 50, 60]),
          "by_status": [{"status": s, "parents": int((m & (status == k)).sum()), "mean_reached_new": float(reached_new[m & (status == k)].mean())}
                        for k, s in ((0, "catalog"), (1, "new"), (2, "seed")) if (m & (status == k)).sum()],
          "by_spaces": binned(spaces[m], reached_new[m], [2, 4, 8, 16, 32])}
    # Additive model on binned features, cross-fitted on two halves.
    # "found" grows after a parent is queued (later rediscoveries), so it leaks
    # future information; the model used for the replay leaves it out. All other
    # features are known when the parent is admitted (5-spaces after prepare_v5).
    def design(idx, with_found=False):
        cols = []
        for x, edges in ((two, [300, 340, 360, 380, 400, 420]), (three, [10, 20, 30, 40, 50, 60]),
                         (spaces, [2, 4, 8, 16, 32])) + (((np.log2(1 + found), [1, 2, 3, 4, 6]),) if with_found else ()):
            k = np.digitize(x[idx], edges); cols += [(k == b).astype(float) for b in range(len(edges) + 1)]
        cols += [(status[idx] == 1).astype(float), seed[idx].astype(float)]
        return np.stack(cols, axis=1)
    def crossfit(target, with_found=False):
        out = np.zeros(n)
        for train, test in ((idx[:half], idx[half:]), (idx[half:], idx[:half])):
            w, *_ = np.linalg.lstsq(design(train, with_found), target[train], rcond=None); out[test] = design(test, with_found) @ w
        return out
    idx = np.flatnonzero(m); rng.shuffle(idx); half = len(idx) // 2
    pred = crossfit(reached_new); pred_rate = crossfit(reached_new / cost)
    e1["model_spearman_out_of_sample"] = spearman(pred[idx], reached_new[idx])
    e1["model_with_found_spearman_out_of_sample"] = spearman(crossfit(reached_new, True)[idx], reached_new[idx])
    e1["rate_model_spearman_out_of_sample"] = spearman(pred_rate[idx], (reached_new / cost)[idx])
    top = idx[np.argsort(-pred[idx])][: len(idx) // 10]
    e1["model_top_decile_mean_reached_new"] = float(reached_new[top].mean())
    report["E1_yield"] = e1
    print(f"E1 done in {time.time()-t0:.0f}s: out-of-sample rank correlation {e1['model_spearman_out_of_sample']:.3f}", flush=True)

    # ---------- E2: replay of other queue orders ----------
    def replay(policy):
        known = np.zeros(n, bool); known[seed] = True
        avail = []; pushed = np.zeros(n, bool)
        def push(i):
            if expanded[i] and not pushed[i]:
                pushed[i] = True; heapq.heappush(avail, (policy(i), i))
        for i in np.flatnonzero(seed):
            push(i)
        curve_new, curve_cost, done = [], [], 0; new_total = 0; spent = 0.0
        while avail:
            _, i = heapq.heappop(avail)
            c = cls[offsets[i]:offsets[i + 1]]; fresh = np.unique(c[~known[c]])
            known[fresh] = True; new_total += int((status[fresh] == 1).sum()); spent += cost[i]; done += 1
            for j in fresh:
                push(j)
            curve_new.append(new_total); curve_cost.append(spent)
        return np.array(curve_new), np.array(curve_cost)
    shuffled = rng.random(n)
    policies = {"admission order (real)": lambda i: i, "random": lambda i: shuffled[i],
                "model (E1, cross-fitted)": lambda i: -pred[i] if pred[i] else 0.0,
                "model of new per coset": lambda i: -pred_rate[i] if pred_rate[i] else 0.0,
                "fewest 5-spaces first": lambda i: spaces[i],
                "oracle (true new reached)": lambda i: -reached_new[i]}
    e2 = {}; curves = {}
    for name, pol in policies.items():
        cn, cc = replay(pol); curves[name] = (cn, cc)
        k = len(cn); marks = {f"{q}%": int(cn[max(0, int(k * q / 100) - 1)]) for q in (10, 25, 50, 75, 100)}
        total = cc[-1]
        by_cost = {f"{q}%": int(cn[min(k - 1, int(np.searchsorted(cc, total * q / 100)))]) for q in (10, 25, 50, 75)}
        e2[name] = {"parents_replayed": k, "new_found_after_x_percent_of_parents": marks,
                    "new_found_after_x_percent_of_cosets": by_cost}
        print(f"E2 {name}: parents {marks} | cosets {by_cost}", flush=True)
    report["E2_replay"] = e2

    # ---------- E3: coverage per cell (Chao1) ----------
    known_cls = (found > 0) | seed
    def chao(f):
        f1, f2 = int((f == 1).sum()), int((f == 2).sum()); s = len(f)
        return {"observed": s, "f1": f1, "f2": f2, "chao1": float(s + (f1 * f1 / (2 * f2) if f2 else f1 * (f1 - 1) / 2))}
    meas = known_cls & (two >= 0) & ~seed
    e3 = {"all_discovered": chao(found[meas]), "new": chao(found[meas & (status == 1)]), "catalog": chao(found[meas & (status == 0)])}
    cells = {}
    for i in np.flatnonzero(meas):
        key = (int(two[i]) // 10 * 10, int(three[i]) // 5 * 5); cells.setdefault(key, []).append(found[i])
    e3["cells"] = sorted(({"two": k[0], "three": k[1], **chao(np.array(v))} for k, v in cells.items() if len(v) >= 200),
                         key=lambda c: -(c["chao1"] - c["observed"]))[:30]
    report["E3_coverage"] = e3

    # ---------- E4: heavy parents ----------
    heavy = expanded & ((spaces > 32) | (ea > 300)); light = expanded & ~heavy
    any_heavy = ((spaces > 32) | (ea > 300)) & ~expanded
    def describe(sel):
        return {"parents": int(sel.sum()), "median_two": float(np.median(two[sel & (two >= 0)])) if (sel & (two >= 0)).any() else None,
                "median_three": float(np.median(three[sel & (two >= 0)])) if (sel & (two >= 0)).any() else None,
                "new_share": float((status[sel] == 1).mean()) if sel.any() else None,
                "median_spaces": float(np.median(spaces[sel])) if sel.any() else None,
                "median_rediscoveries": float(np.median(found[sel])) if sel.any() else None}
    report["E4_heavy"] = {"expanded heavy": describe(heavy), "expanded light": describe(light),
                          "heavy, not expanded (deferred)": describe(any_heavy)}

    (out / "report.json").write_text(json.dumps(report, indent=1))
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        fig, ax = plt.subplots(1, 2, figsize=(13, 4.8))
        for name, (cn, cc) in curves.items():
            ax[0].plot(np.arange(1, len(cn) + 1), cn, label=name); ax[1].plot(cc / 1e9, cn, label=name)
        ax[0].set_xlabel("parents expanded"); ax[0].set_ylabel("new classes found"); ax[0].legend(fontsize=8)
        ax[1].set_xlabel("v5 cosets spent (billions)"); ax[1].set_ylabel("new classes found")
        fig.suptitle("E2: replay of queue orders over the expanded parents"); fig.tight_layout(); fig.savefig(out / "E2_replay.png", dpi=110)
        fig, ax = plt.subplots(1, 3, figsize=(15, 4.2))
        for k, (key, title) in enumerate((("by_two", "two"), ("by_three", "three"), ("by_spaces", "maximizing 5-spaces"))):
            b = e1[key]; ax[k].bar([x["bin"] for x in b], [x["mean"] for x in b]); ax[k].set_title("new classes reached per parent, by " + title)
            ax[k].tick_params(axis="x", rotation=40)
        fig.tight_layout(); fig.savefig(out / "E1_yield.png", dpi=110)
        print("figures written", flush=True)
    except ImportError:
        print("matplotlib not available: no figures", flush=True)
    print(f"done in {time.time()-t0:.0f}s -> {out}", flush=True)


if __name__ == "__main__":
    main()
