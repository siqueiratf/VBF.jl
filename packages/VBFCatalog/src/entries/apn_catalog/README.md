# APN function catalog

One TOML per input bit-width `n` (`n4_apn.toml`, `n5_apn.toml`, …).
Each entry is sourced from a primary specification or published list
and verified APN at build time (`differential_uniformity == 2`).

For n ≥ 6, where there are dozens to thousands of CCZ classes, the
entries here are curated representatives. Compact bulk dataset members share
the catalog database or its large local extension; see the catalog guide.

## Schema (per `[[apn_functions]]` entry)

| field            | type             | required | meaning                                          |
|------------------|------------------|----------|--------------------------------------------------|
| `name`           | string           | yes      | unique key — used by `find_function(db; canonical_name=name)` |
| `description`    | string           | yes      | human-readable                                   |
| `n`              | int              | yes      | input/output bits                                |
| `m`              | int              | yes      | output bits — must equal `n` for now             |
| `lut`            | array of int     | one representation | length `2^n`, entries `< 2^m` |
| `monomial_exponent` | int           | alternative | reconstruct the power function through VBF |
| `modulus`        | int              | optional | field polynomial used for reconstruction |
| `algebraic_form` | string           | no       | e.g. `"x^3 in GF(2^4) with x^4 + x + 1"`         |
| `is_permutation` | bool             | yes      | self-explanatory                                 |
| `bib_key`        | string           | yes      | resolves into the `bibliography` table           |
| `source`         | string           | yes      | human-readable citation                          |

## Updating an entry

From the repository root, edit the source TOML, rebuild and run the catalog gate:

```sh
make -C packages/VBFCatalog/src/import catalog
make -C packages/VBFCatalog/src/import check
```

Commit the entry and rebuilt `BFA_catalog.sqlite` together. The gate checks source
agreement and runs catalog tests. See the [catalog guide](../../../README.md)
for original-source fetching, local overrides and bulk corpus storage.

`is_apn` and `is_quadratic` are *derived* at build time
(`differential_uniformity == 2` and `algebraic_degree ≤ 2`); the loader
verifies APN-ness and refuses entries that fail.
