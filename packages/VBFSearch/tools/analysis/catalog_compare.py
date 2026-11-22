#!/usr/bin/env python3
"""Compare the search with the published catalog per stratum of invariants.

    catalog_compare.py --classes classes.sqlite --features features.sqlite
                       --catalog catalog_features.sqlite --out OUT.json

Units are distinct invariant signatures (sigma): the catalog table has one row
per signature, and a search class counts as catalog-matching when its sigma is
in the catalog. Strata: c4 (rank-4 components: 0, 1, >= 2) x band of two (20
wide) [x band of three (10 wide) for the fine table].

Per stratum: catalog signatures (C), search signatures (S), both (B), search
only (S - B: new), catalog only (C - B: not reached yet), and the Chapman
capture-recapture estimate N = (C + 1)(S + 1)/(B + 1) - 1 of all signatures.
The estimate assumes that the two samples are independent inside a stratum;
the catalog comes from a random search and the closure from constructions,
so read it as an indication, and compare strata rather than trust one total.
"""
import argparse, json, sqlite3
from collections import defaultdict


def stratum(c4, two, three, fine):
    k = (min(int(c4), 2), int(two) // 20 * 20)
    return k + ((int(three) // 10 * 10,) if fine else ())


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--classes", required=True); p.add_argument("--features", required=True)
    p.add_argument("--catalog", required=True); p.add_argument("--out", required=True)
    a = p.parse_args()
    db = sqlite3.connect(f"file:{a.classes}?mode=ro", uri=True)
    db.execute("ATTACH ? AS f", (f"file:{a.features}?mode=ro",))
    db.execute("ATTACH ? AS k", (f"file:{a.catalog}?mode=ro",))
    search = {}
    for sigma, c4, two, three in db.execute(
            "SELECT c.sigma, f.c4, f.two, f.three FROM classes c JOIN f.features f ON f.sha=c.sha"):
        search[sigma] = (c4, two, three)
    catalog = {}
    for sigma, c4, two, three in db.execute(
            "SELECT sigma, c4, two, three FROM k.catalog_features WHERE error IS NULL OR error=''"):
        catalog[sigma] = (c4, two, three)
    report = {"search_signatures": len(search), "catalog_signatures": len(catalog),
              "both": len(search.keys() & catalog.keys())}
    for fine in (False, True):
        rows = defaultdict(lambda: [0, 0, 0])  # C, S, B
        for s, v in catalog.items():
            rows[stratum(*v, fine)][0] += 1
            if s in search:
                rows[stratum(*v, fine)][2] += 1
        for s, v in search.items():
            rows[stratum(*v, fine)][1] += 1
        table, total = [], 0.0
        for key in sorted(rows):
            C, S, B = rows[key]
            N = (C + 1) * (S + 1) / (B + 1) - 1
            total += N
            entry = {"c4": key[0] if key[0] < 2 else ">=2", "two": f"{key[1]}..{key[1] + 19}", "catalog": C, "search": S,
                     "both": B, "new": S - B, "catalog_only": C - B, "chapman_estimate": round(N),
                     "known": C + S - B, "known_share_of_estimate": round((C + S - B) / N, 3) if N > 0 else None}
            if fine:
                entry["three"] = f"{key[2]}..{key[2] + 9}"
            table.append(entry)
        name = "fine" if fine else "coarse"
        report[f"{name}_strata"] = table
        report[f"{name}_estimate_total"] = round(total)
    C, S, B = len(catalog), len(search), report["both"]
    report["unstratified_estimate"] = round((C + 1) * (S + 1) / (B + 1) - 1)
    report["known_total"] = C + S - B
    json.dump(report, open(a.out, "w"), indent=1)
    print(json.dumps({k: report[k] for k in ("search_signatures", "catalog_signatures", "both", "known_total",
                                             "unstratified_estimate", "coarse_estimate_total", "fine_estimate_total")}))


if __name__ == "__main__":
    main()
