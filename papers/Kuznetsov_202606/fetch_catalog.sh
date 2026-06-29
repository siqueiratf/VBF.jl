#!/usr/bin/env bash
# Fetch the known dimension-8 quadratic-APN catalogs for the Phase-2 novelty oracle.
# Real, citable data — never fabricated. Outputs are gitignored (catalogs/).
#
#   default       : BLP22 — sboxU apn_8bit_BLP22 (Beierle–Leander–Perrin 2022, 6368 LUTs)
#                   -> catalogs/apn8_blp22.json
#   --full | --25 : also BLP25 — Zenodo 16752428 (Beierle, Langevin, Leander, Polujan,
#                   Rasoolzadeh 2025, 3,775,599 inequivalent quadratic APN, ~3.4 GB)
#                   -> catalogs/apn8_blp2025.txt
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p catalogs

URL22="https://raw.githubusercontent.com/lpp-crypto/sboxU/main/sboxU/scripts/apnDB/apn_8bit_BLP22.py"
TMP="$(mktemp)"
echo "fetching BLP22: $URL22"
curl -fsSL "$URL22" -o "$TMP"
python3 - "$TMP" <<'PY'
import sys, json
ns = {}
exec(open(sys.argv[1]).read(), ns)
luts = ns["all_funcs"]
assert all(len(x) == 256 for x in luts), "expected 256-entry LUTs"
json.dump({"source": "sboxU apn_8bit_BLP22 (Beierle-Leander-Perrin 2022)",
           "n": 8, "count": len(luts), "luts": luts},
          open("catalogs/apn8_blp22.json", "w"))
print(f"wrote catalogs/apn8_blp22.json : {len(luts)} LUTs")
PY
rm -f "$TMP"

if [[ "${1:-}" == "--full" || "${1:-}" == "--25" ]]; then
    URL25="https://zenodo.org/api/records/16752428/files/new_apns.txt/content"
    echo "fetching BLP25 (~3.4 GB): $URL25"
    curl -fsSL "$URL25" -o catalogs/apn8_blp2025.txt
    echo "wrote catalogs/apn8_blp2025.txt : $(wc -l < catalogs/apn8_blp2025.txt) LUTs"
fi
