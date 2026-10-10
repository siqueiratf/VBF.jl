"""Extract data without executing upstream code; requires pyarrow and pdftotext.

Usage: python prepare_sources.py DOWNLOAD_DIRECTORY
Inputs are pinned by sources.tsv and checked before parsing.
"""
import ast
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

import pyarrow.parquet as pq


def prepare(root):
    root = Path(root)
    manifest = Path(__file__).with_name("sources.tsv")
    inputs = list(csv.DictReader(manifest.open(), delimiter="\t"))
    for item in inputs:
        path = root / item["file"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"], path
    rows = []

    def add(source, member, kind, payload, expected_sha=""):
        rows.append((source, str(member), kind, payload, expected_sha))

    path = root / "github/cma029/APN-Repository/database/apn/apn_data_8.parquet"
    table = pq.read_table(path).to_pylist()
    assert len(table) == 32893
    for i, row in enumerate(table, 1):
        assert row["field_n"] == 8
        assert row["irr_poly"] == "x^8 + x^4 + x^3 + x^2 + 1"
        pairs = ast.literal_eval(row["poly"])
        payload = ";".join(f"{a},{b}" for a, b in pairs)
        add("andersen", i, "polynomial_pairs", payload)

    obj = json.loads((root / "github/KuznetsovKarazin/apn-gb-search/data/apn_all.json").read_text())
    assert len(obj["functions"]) == 566
    for i, row in enumerate(obj["functions"], 1):
        lut = bytes(row["sbox"])
        assert len(lut) == 256
        add("kuznetsov_gb", i, "lut", lut.hex())

    slides = ["galissant_jc2_2026.pdf", "2026-04-03_APN_exploration_C2.pdf",
              "2026-02-17_APN_exploration_IRIF.pdf", "2026-02-13_APN_exploration_INRIA_seminar.pdf"]
    for filename in slides:
        textpath = (root / filename).with_suffix(".txt")
        subprocess.run(["pdftotext", "-layout", str(root / filename), str(textpath)], check=True)
        found = 0
        for page, text in enumerate(textpath.read_text().split("\f"), 1):
            for match in re.finditer(r"\[((?:\s*\d+\s*,?\s*)+)\]", text):
                values = [int(x) for x in match[1].split(",") if x.strip()]
                if len(values) == 256:
                    add("galissant", f"{filename}:page{page}", "lut", bytes(values).hex())
                    found += 1
        assert found == 1, (filename, found)

    repo = root / "github/KuznetsovKarazin/apn-trace-product-switchings/results/current"
    obj = json.loads((repo / "projective_equivalence_partition.json").read_text())
    for orbit in obj["partition"]:
        for member in orbit["members"]:
            rho, eta = (int(member[k], 16) for k in ("rho_hex", "eta_hex"))
            add("trace_product_rank2", f"rho={rho:02x},eta={eta:02x}", "trace2",
                f"{rho},{eta}", member["function_sha256"])
    for theta in (1, 0xbc, 0xbd):
        add("trace_product_rank1", f"theta={theta:02x}", "trace1", str(theta))

    # k modulo 8 exhausts this formula for m=4: q repeats modulo 4,
    # and eight consecutive Frobenius terms cancel in characteristic two.
    for k in (1, 3, 5, 7):
        add("shi_peng_zheng", f"m=4,k={k}", "shi", str(k))

    path = root / "github/Xanadu-ins/apn-ccz-graph-framework/list_of_APN_functions_for_different_n"
    block = path.read_text().split("#n = 8", 1)[1].split("#n = 9", 1)[0]
    matches = re.findall(r'\("(\d+)",\s*([^\n]+)\),', block)
    assert len(matches) == 12
    for member, expression in matches:
        add("xanadu", member, "polynomial", expression.replace("ksi", "g"))

    path = root / "github/lpp-crypto/sboxU/sboxU/scripts/apnDB/reprs8.py"
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.FunctionDef) and node.name == "all_quadratic_polynomials":
            calls = next(x.value.elts for x in node.body if isinstance(x, ast.Return))
            assert len(calls) == 22
            for member, call in enumerate(calls, 1):
                expr = ast.get_source_segment(path.read_text(), call.args[0])
                expr = re.sub(r"sum\(X\*\*\((\d+)\*2\*\*i\) for i in range\(0, N\)\)",
                              lambda m: "(" + "+".join(f"X**{int(m[1]) * 2**i}" for i in range(8)) + ")", expr)
                expr = re.sub(r"\+\s*\+", "+", expr)
                add("sboxu_reprs8", member, "polynomial", expr)
    with (root / "inputs.tsv").open("w") as out:
        writer = csv.writer(out, delimiter="\t", lineterminator="\n")
        writer.writerow(("source", "member", "kind", "payload", "expected_lut_sha256"))
        writer.writerows(rows)
    print(f"Prepared {len(rows)} records from {len(inputs)} pinned files")


if __name__ == "__main__":
    prepare(sys.argv[1])
