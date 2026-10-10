# Catalog data

Tracked source data:

- `apn/n*_apn.toml`: curated APN LUTs or monomial parameters.
- `literature_sboxes.toml`: literature S-box LUTs.
- `sporadic.toml`: fixed APN LUTs with citations and provenance.
- `corpora.toml`: raw dataset files and format-specific readers.
- `sources.toml`: URLs, pinned revisions, checksums and Julia converters.

`catalog.sqlite` is the generated queryable catalog. Named datasets share tables;
there is no database per family. Bibliography records originate in the shared
`bibliography.bib`; reproduction citation identities are in `publications.toml`.

Downloaded originals are retained under ignored `raw/`. `members.sqlite` is the
large local extension; signature/fingerprint indexes and `imports.toml` are
regenerable local products. See the [package guide](../README.md)
for the source-to-catalog commands.
