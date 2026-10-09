# APN8 class check (local web page)

**Path**: `census/quadratic_apn8/web/`

This page tells you if an (8,8)-function is in a known CCZ class of quadratic APN
functions, in the census list of 553 new classes, or in a new class. Paste the function
into one input box. The server finds the format.

## Run

```
make instantiate            # once: HTTP.jl, JSON3 and the local packages VBF, VBFCatalog
make serve                  # http://127.0.0.1:8088/
make serve port=9000        # other port; host=... changes the address (default 127.0.0.1)
make test                   # tests the request handler without a socket
```

The server uses two threads: one interactive thread for HTTP and one default thread for
the exact EA test (`--threads=1,1`). It has its own environment (`Project.toml`,
`Manifest.toml`). The root `Project.toml` does not change.

The server needs the σ-index side store `packages/VBFCatalog/corpora/ccz_sigma_index.sqlite`
and the catalog. It opens both once at start, read only (`PRAGMA query_only`). Start takes
some seconds (package load and the first σ). A request takes milliseconds.

## Input formats

| Format | Example | Rule |
|---|---|---|
| LUT | `[0, 1, 8, ...]` | 256 integers 0..255, F(0) first. Separators: spaces, commas, semicolons or newlines. Brackets are optional. Hex values need `0x`. |
| Coefficient string | `b8fbf84d...` | Exactly 56 hex digits = 28 bytes c_ij for 1 ≤ i < j ≤ 8, i outer, j inner. F(x) = XOR_{i<j} x_i x_j c_ij, x_1 = least significant bit. This is the format of `new_classes_553.tsv`. |
| Univariate polynomial | `x^3 + a*x^9` | Polynomial over GF(2^8), parsed by `VBF.polynomial_to_lut`. Modulus 0x11B by default; `mod=0x11D` changes it. `a`, `g` and `ksi` are the class of X (the element 0x02). Integer constants are read mod 2. `^` and `**` are powers. |

The server tries the formats in the order coefficient string, LUT, polynomial. It returns
an error message when no format fits (for example: wrong count of values, a value outside
0..255, a parse error).

## Output

Every parsed input gives the differential uniformity, "APN" (uniformity 2) and the
algebraic degree. A quadratic APN function also gives its σ hash and one of these verdicts:

| Verdict | Meaning |
|---|---|
| **KNOWN (sigma matches source X member i)** | σ is in the index of 3,808,491 known classes (4,005,445 index rows, n = 8). A σ match is necessary but **not sufficient** for CCZ-equivalence. The button "Exact EA check" runs `VBF.ea_mappings_from_ortho_derivative(F, G)` against member i of source X. This takes about 10 minutes when the functions are equivalent and seconds when they are not. |
| **NEW, in the census list (one of the 553)** | σ is absent from the index. Thus the function is CCZ-inequivalent to all indexed functions (rigorous). σ is equal to the σ of a line of `new_classes_553.tsv`. The EA check against that line is available. |
| **NEW, found in this study** (status `listed_new`) | σ is absent from the index and equal to a line of `../new_classes_extra.tsv` (theory experiment) or `../search_b52/new_classes_trial_773.tsv` (B6 = 52 search trial). The EA check against that line is available. |
| **Not in the catalog index, but PUBLIC** (status `raw_public`) | σ is absent from the index and equal to a line of `../crosscheck_raw/raw_only_546.tsv`: one of the 546 classes in the authors' public raw file of May 2025 that are not in their published list. |
| **NEW: sigma absent from the index and from the census list** | A rigorous CCZ-inequivalence certificate against all indexed sources. σ is a CCZ invariant of quadratic APN functions (Canteaut–Couvreur–Perrin; EA = CCZ for quadratic APN by Yoshiara). |
| **APN, not quadratic** | The σ oracle needs a quadratic function. The page gives only the basic properties. |
| **NOT APN** | The differential uniformity is larger than 2. |

Novelty is relative to the indexed sources. See `../reports/verification/REPORT.md` for
the index integrity check.

The exact EA test runs in a background task. One test runs at a time. The page asks for
its state every 5 seconds. The server finds the target function again from the input; it
does not use a target from the client.

## HTTP interface

| Route | Body | Result |
|---|---|---|
| `GET /` | | The page |
| `POST /api/classify` | the function as text | JSON; status 400 for a parse error |
| `POST /api/ea` | the function as text | JSON job (`id`, `state`) |
| `GET /api/ea/<id>` | | JSON job: `state` (queued, running, done, failed), `equivalent`, `message` |
| `GET /api/health` | | JSON: index rows, census size |

Example: `curl -s -X POST --data-binary 'x^3' http://127.0.0.1:8088/api/classify`

## Tests

`make test` includes `server.jl` and calls `APN8Web.handle` with hand-made
`HTTP.Request` values. It checks: a beierle2025_n8 member gives KNOWN; a census line (as
coefficients and as a LUT) gives the census verdict and the correct line; Gold x^3 (as a
polynomial, a LUT and with modulus 0x11D) gives KNOWN; a random permutation gives NOT APN;
Kasami x^57 gives "APN, not quadratic"; malformed inputs give status 400 with a message.
It also compares the coefficient decoder with `QK.lut` from `../qknuth.jl`. The verdict
"NEW" (absent from the index and the census list) has no test input, because no such
function is known.
