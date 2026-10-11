# Local catalog data and evidence

Tracked declarative resources and the generated catalog live in `../src/data/`.
This directory retains downloaded originals (`raw/`), large external records
(`members.sqlite`), verified import receipts, derived signature/class indexes,
local equivalence proofs, search runs and historical research evidence.

These stores are not inputs to the tracked database except for explicitly
pinned original-source files. Reusable external records are checked against
source and implementation hashes and ordered member digests. Searches become
rebuild inputs only through publication into `src/data/luts/` and `corpora.toml`.

See the [package guide](../README.md) for APIs and build commands.
