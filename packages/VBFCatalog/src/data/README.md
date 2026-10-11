# Catalog inputs

Only source inputs live here:

- `sources.toml`: pinned originals, adapter names, corpus counts, checksums and provenance.
- `apn.toml`: curated APN LUTs or power-function definitions with citations.
- `literature_sboxes.toml` and `sporadic.toml`: fixed literature definitions.
- `bibliography.bib`: shared citations.
- `luts/`: immutable public TSVs and normalized VBFSearch coefficient inputs.

An APN entry is a `[[apn_functions]]` block with a unique `name`, `n`, `m`,
`description`, `bib_key`, `source`, `is_permutation`, and either `lut` or
`monomial_exponent` (optionally `modulus`). VBF reconstructs and verifies it.

Eight-bit quadratic corpora can use gzip streams of 37-byte VBF coefficients,
without gzip timestamps. The manifest binds file SHA-256, ordered coefficient
digest, count and provenance. These bytes reconstruct functions without the
original run database. Search checkpoints and witnesses remain in VBFSearch.

Generated databases and downloaded originals live in `.cache/vbfcatalog/` outside
this package. See the [package guide](../../README.md) to rebuild and check.
