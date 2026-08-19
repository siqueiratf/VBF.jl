# APN function catalog

One TOML per input bit-width `n` (`n4_apn.toml`, `n5_apn.toml`, …).
Each entry is sourced from a primary specification or published list
and verified APN at build time (`differential_uniformity == 2`).

For n ≥ 6, where there are dozens to thousands of CCZ classes, the
entries here are the small "canonical representatives" set; the bulk
APN database lands in artifacts in a later phase.

## Schema (per `[[apn_functions]]` entry)

| field            | type             | required | meaning                                          |
|------------------|------------------|----------|--------------------------------------------------|
| `name`           | string           | yes      | unique key — used by `find_function(db; canonical_name=name)` |
| `description`    | string           | yes      | human-readable                                   |
| `n`              | int              | yes      | input/output bits                                |
| `m`              | int              | yes      | output bits — must equal `n` for now             |
| `lut`            | array of int     | yes      | length `2^n`, entries `< 2^m`                    |
| `algebraic_form` | string           | no       | e.g. `"x^3 in GF(2^4) with x^4 + x + 1"`         |
| `is_permutation` | bool             | yes      | self-explanatory                                 |
| `bib_key`        | string           | yes      | resolves into the `bibliography` table           |
| `source`         | string           | yes      | human-readable citation                          |

## Adding or changing an entry (do not stop at the TOML)

`../../BFA_catalog.sqlite` is committed and is built from these files, and
`packages/VBF/test/unit/catalog_{queries,content}_test.jl` reconstruct their
expected counts from these TOMLs and compare them against that DB. An entry
added here but not built into the DB therefore fails CI — silently as far as
this directory is concerned, since nothing here looks wrong.

So every change here is a three-step change:

```bash
$EDITOR n8_apn.toml                                    # 1. the entry
make -C ../../data-build sync-apn                      # 2. carry it into the DB
make -C ../../data-build check                         # 3. gate: must print catalog-check: OK
git add n8_apn.toml ../../BFA_catalog.sqlite           #    both, one commit
```

Step 2 used to be `make -C ../../data-build catalog`, the full rebuild. Use
`sync-apn` for a change confined to *this* directory: it touches `family =
'APN'` only, needs no external data source, re-verifies every function through
`load_apn_function` before writing, and is idempotent. The full rebuild also
rebuilds the importer-backed families, so it needs their sources — today that
means `BFA_THESIS_PATH` for the Simon-Berg thesis. Run the full rebuild when you
change an importer, `sources.toml`, or `literature_sboxes.toml`.

Neither command can silently lose rows any more. The full rebuild refuses to
start when a required source is unavailable, assembles into a staging file, and
installs it only after checking that no family shrank.

`make check` also runs the catalog test items; `make check-structure` is the
fast half (no Julia needed) and is what the pre-commit hook runs first. Enable
the hook once per clone with `git config core.hooksPath .githooks`.

`is_apn` and `is_quadratic` are *derived* at build time
(`differential_uniformity == 2` and `algebraic_degree ≤ 2`); the loader
verifies APN-ness and refuses entries that fail.
