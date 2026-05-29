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

`is_apn` and `is_quadratic` are *derived* at build time
(`differential_uniformity == 2` and `algebraic_degree ≤ 2`); the loader
verifies APN-ness and refuses entries that fail.
