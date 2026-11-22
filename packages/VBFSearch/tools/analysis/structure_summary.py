#!/usr/bin/env python3
"""Cross the invariants with the construction history of the closure search.

    structure_summary.py --explorer DIR/<version> --out OUT_DIR

Reads the explorer arrays (explorer_data.py) and writes OUT_DIR/summary.json
and, when matplotlib is present, OUT_DIR/structure_*.png. Sections:

A  drift of every invariant over the admission order (blocks of ids)
B  separation of new and catalog-matching classes per invariant (AUC, rates)
C  the same invariants per generation
D  rediscoveries (a coverage proxy) per invariant value
E  inheritance parent -> child: agreement against the base rate
F  new classes per million cosets by the parent's invariants (expanded parents)
G  rare classes: c4 > 0, c2 = 1, four > 0, du >= 20
"""
import argparse, json
from pathlib import Path

import numpy as np


def auc(pos, neg):
    """P(value of a new class > value of a catalog class), ties count one half."""
    allv = np.concatenate([pos, neg]); r = np.empty(len(allv))
    order = np.argsort(allv, kind="mergesort"); sv = allv[order]
    ranks = np.arange(1, len(allv) + 1, dtype=float)
    # average ranks of ties
    _, start, count = np.unique(sv, return_index=True, return_counts=True)
    avg = start + (count + 1) / 2.0
    r[order] = np.repeat(avg, count)
    return float((r[:len(pos)].sum() - len(pos) * (len(pos) + 1) / 2) / (len(pos) * len(neg)))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--explorer", required=True); p.add_argument("--out", required=True)
    a = p.parse_args(); E = Path(a.explorer); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    L = lambda name, t: np.fromfile(E / name, t)
    two, three = L("two.i16", "<i2").astype(float), L("three.i16", "<i2").astype(float)
    st, gen, disc = L("status.u8", "u1"), L("generation.u16", "<u2"), L("discoverer.u32", "<u4").astype(np.int64)
    found, exp = L("found.u16", "<u2").astype(float), L("expanded.u8", "u1") > 0
    cosets, rnew = L("cosets.f32", "<f4").astype(float), L("reached_new.u16", "<u2").astype(float)
    inv = L("inv.u8", "u1").reshape(-1, 4).astype(float)
    du, c4, c2, four = inv[:, 0], inv[:, 1], inv[:, 2], inv[:, 3]
    n = len(two); ids = np.arange(1, n + 1); meas = two >= 0; new = st == 1; cat = st == 0
    V = {"two": two, "three": three, "du": du, "c4": c4, "four": four, "c2": c2}
    S = {"classes": int(n), "measured": int(meas.sum())}

    # A: drift over admission order
    blocks = []
    for lo in range(0, n, 250_000):
        s = slice(lo, min(n, lo + 250_000)); m = meas[s]
        blocks.append({"first_id": lo + 1, "new_pct": round(100 * float(new[s].mean()), 1),
                       **{f"mean_{k}": round(float(v[s][m].mean()), 3) for k, v in V.items() if k in ("two", "three", "du")},
                       "pct_c4_pos": round(100 * float((c4[s][m] > 0).mean()), 3), "pct_four_pos": round(100 * float((four[s][m] > 0).mean()), 4),
                       "median_found": float(np.median(found[s])), "generation_2_pct": round(100 * float((gen[s] == 2).mean()), 1)})
    S["A_drift"] = blocks

    # B: new against catalog
    mn, mc = meas & new, meas & cat
    S["B_separation"] = {k: {"mean_new": round(float(v[mn].mean()), 3), "mean_catalog": round(float(v[mc].mean()), 3),
                             "auc_new_higher": round(auc(v[mn], v[mc]), 3)} for k, v in V.items()}
    S["B_new_rate_by_value"] = {k: [{"value": int(x), "classes": int(((v == x) & meas & (st < 2)).sum()),
                                     "new_pct": round(100 * float(new[(v == x) & meas & (st < 2)].mean()), 1)}
                                    for x in np.unique(v[meas]) if ((v == x) & meas & (st < 2)).sum() >= 100]
                                for k, v in (("du", du), ("c4", c4), ("four", four), ("c2", c2))}
    band = lambda v, edges: np.digitize(v, edges)
    for k, v, edges in (("two", two, [320, 350, 370, 380, 390, 400, 410, 420]), ("three", three, [10, 20, 25, 30, 35, 40, 50, 60])):
        b = band(v, edges); rows = []
        for i in range(len(edges) + 1):
            sel = meas & (b == i) & (st < 2)
            if sel.sum() >= 100:
                rows.append({"band": (f"<{edges[0]}" if i == 0 else f">={edges[-1]}" if i == len(edges) else f"{edges[i-1]}..{edges[i]}"),
                             "classes": int(sel.sum()), "new_pct": round(100 * float(new[sel].mean()), 1)})
        S["B_new_rate_by_value"][k] = rows

    # C: per generation
    S["C_generations"] = {int(g): {"classes": int((gen == g).sum()), "new_pct": round(100 * float(new[gen == g].mean()), 1),
                                   **{f"mean_{k}": round(float(v[(gen == g) & meas].mean()), 3) for k, v in V.items()},
                                   "median_found": float(np.median(found[gen == g]))} for g in (0, 1, 2)}

    # D: rediscoveries per value
    S["D_found_by_value"] = {k: [{"value": int(x), "median_found": float(np.median(found[(v == x) & meas])),
                                  "singletons_pct": round(100 * float((found[(v == x) & meas] == 1).mean()), 1)}
                                 for x in np.unique(v[meas]) if ((v == x) & meas).sum() >= 100]
                             for k, v in (("du", du), ("c4", c4), ("four", four))}

    # E: inheritance
    has = (disc > 0) & meas; j = np.where(has, disc - 1, 0); pair = has & meas[j]
    E_ = {}
    for k, v in V.items():
        pv, cv = v[j[pair]], v[pair]
        vals, cnt = np.unique(cv, return_counts=True); base = float(((cnt / cnt.sum()) ** 2).sum())
        same = float((pv == cv).mean())
        E_[k] = {"same_value_pct": round(100 * same, 2), "base_rate_pct": round(100 * base, 2), "lift": round(same / base, 2) if base else None,
                 "corr": round(float(np.corrcoef(pv, cv)[0, 1]), 3) if pv.std() > 0 and cv.std() > 0 else None}
        if k in ("c4", "four", "c2"):
            E_[k]["child_positive_pct_if_parent_positive"] = round(100 * float((cv[pv > 0] > 0).mean()), 2) if (pv > 0).any() else None
            E_[k]["child_positive_pct_if_parent_zero"] = round(100 * float((cv[pv == 0] > 0).mean()), 4)
    E_["new_child_pct_if_parent_new"] = round(100 * float(new[pair][st[j[pair]] == 1].mean()), 1)
    E_["new_child_pct_if_parent_catalog"] = round(100 * float(new[pair][st[j[pair]] == 0].mean()), 1)
    S["E_inheritance"] = E_

    # F: yield of expanded parents by invariants
    F_ = {}
    for k, v in (("du", du), ("c4", c4), ("four", four)):
        rows = []
        for x in np.unique(v[exp & meas]):
            sel = exp & meas & (v == x)
            if sel.sum() >= 30:
                rows.append({"value": int(x), "parents": int(sel.sum()), "new_per_mcoset": round(1e6 * rnew[sel].sum() / max(1, cosets[sel].sum()), 1)})
        F_[k] = rows
    S["F_yield_by_parent_invariant"] = F_

    # G: rare classes
    G_ = {}
    for name, sel in (("c4>0", meas & (c4 > 0)), ("c2=1", meas & (c2 > 0)), ("four>0", meas & (four > 0)), ("du>=20", meas & (du >= 20))):
        if not sel.any():
            continue
        d = disc[sel]; dd = d[d > 0] - 1
        G_[name] = {"classes": int(sel.sum()), "new_pct": round(100 * float(new[sel].mean()), 1), "seeds": int((st[sel] == 2).sum()),
                    "median_found": float(np.median(found[sel])), "generation": {int(g): int((gen[sel] == g).sum()) for g in (0, 1, 2)},
                    "mean_two": round(float(two[sel].mean()), 1), "mean_three": round(float(three[sel].mean()), 1),
                    "discoverer_also_rare_pct": round(100 * float((sel[dd]).mean()), 1) if len(dd) else None,
                    "base_rare_pct": round(100 * float(sel[meas].mean()), 3)}
    S["G_rare"] = G_
    (out / "summary.json").write_text(json.dumps(S, indent=1))

    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        from matplotlib.colors import LogNorm
        def heat(ax, x, y, sel, xb, yb, title, xl, yl, rate=True):
            H, xe, ye = np.histogram2d(x[sel], y[sel], bins=[xb, yb])
            if rate:
                N, _, _ = np.histogram2d(x[sel & new], y[sel & new], bins=[xb, yb])
                R = np.where(H >= 20, 100 * N / np.maximum(H, 1), np.nan)
                im = ax.pcolormesh(xe, ye, R.T, cmap="viridis", vmin=0, vmax=100); plt.colorbar(im, ax=ax, label="% new")
            else:
                im = ax.pcolormesh(xe, ye, H.T, cmap="viridis", norm=LogNorm(vmin=1)); plt.colorbar(im, ax=ax, label="classes")
            ax.set_title(title, fontsize=10); ax.set_xlabel(xl); ax.set_ylabel(yl)
        sel = meas & (st < 2)
        fig, ax = plt.subplots(2, 3, figsize=(18, 10))
        heat(ax[0, 0], two, three, sel, np.arange(156, 464, 4), np.arange(0, 142, 2), "% new by (two, three)", "two", "three")
        heat(ax[0, 1], two, three, meas, np.arange(156, 464, 4), np.arange(0, 142, 2), "classes by (two, three)", "two", "three", rate=False)
        heat(ax[0, 2], ids.astype(float), three, sel, np.linspace(0, n, 120), np.arange(0, 142, 2), "% new by (admission order, three)", "class id", "three")
        heat(ax[1, 0], ids.astype(float), two, sel, np.linspace(0, n, 120), np.arange(156, 464, 4), "% new by (admission order, two)", "class id", "two")
        heat(ax[1, 1], two, du, sel, np.arange(156, 464, 4), np.arange(7.5, 31.5, 1), "% new by (two, du)", "two", "du (ortho-derivative)")
        heat(ax[1, 2], three, du, sel, np.arange(0, 142, 2), np.arange(7.5, 31.5, 1), "% new by (three, du)", "three", "du (ortho-derivative)")
        fig.tight_layout(); fig.savefig(out / "structure_maps.png", dpi=90)
        fig, ax = plt.subplots(1, 3, figsize=(18, 4.6))
        b = S["A_drift"]; x = [r["first_id"] / 1e6 for r in b]
        ax[0].plot(x, [r["new_pct"] for r in b], "o-"); ax[0].set_title("% new per block of 250,000 admissions"); ax[0].set_xlabel("first id (millions)")
        ax[1].plot(x, [r["mean_two"] for r in b], "o-", label="mean two"); ax2 = ax[1].twinx(); ax2.plot(x, [r["mean_three"] for r in b], "s-", color="C1", label="mean three")
        ax[1].set_title("mean two (left) and three (right)"); ax[1].set_xlabel("first id (millions)")
        ax[2].plot(x, [r["mean_du"] for r in b], "o-", label="mean du"); ax[2].plot(x, [r["pct_c4_pos"] for r in b], "s-", label="% c4 > 0")
        ax[2].legend(); ax[2].set_title("du and rank-4 components over time"); ax[2].set_xlabel("first id (millions)")
        fig.tight_layout(); fig.savefig(out / "structure_drift.png", dpi=90)
        print("figures written")
    except ImportError:
        print("matplotlib not available: no figures")
    print(json.dumps({k: S[k] for k in ("B_separation", "E_inheritance")}, indent=1))


if __name__ == "__main__":
    main()
