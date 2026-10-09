# Rebuild the quadratic APN comparison corpus

This workflow recomputes signatures for every registered quadratic (8,8)-APN
corpus member and quadratic APN catalog LUT, then independently recomputes
them from the original public datasets. It addresses the comparison-source
provenance gap: recomputing an index from its imported side stores alone
does not verify the import against its original input.

Run from any directory:

```sh
make -C census/quadratic_apn8/rebuild_corpus test
make -C census/quadratic_apn8/rebuild_corpus all threads=16
```

The stages `fetch`, `stored`, `raw`, `compare`, `candidates`, and `equivalence`
can also run individually.
All downloaded inputs, progress databases, logs and reports default to the
ignored `census/quadratic_apn8/results/signature_rebuild/` directory. The
existing catalog, corpus side stores and sigma index are read-only inputs.
`OUTDIR=/absolute/path` selects a different result directory. Re-run the same
command to resume an interrupted computation; completed sources are skipped.

For a bounded timing run, use a **different** output directory:

```sh
julia --project=. -t 16 census/quadratic_apn8/rebuild_corpus/rebuild.jl stored \
  --outdir /tmp/apn-signature-benchmark --source stored_beierle2025_n8 --limit 10000
```

Every processed LUT must have degree exactly two and every nonzero polar map
must have rank seven. The latter condition proves APN for quadratic functions.
`signature.jl` uses its own Boolean Möbius transform, binary elimination,
differential histogram and integer Walsh transform. It calls no VBF
verification/signature routines. VBF supplies the existing polynomial and
compact-coefficient decoders; tests compare the independent result with the
library on several members of every corpus, including affine transformations
and invalid controls.

The original sources are:

- [Zenodo 16752428](https://zenodo.org/records/16752428): 3,775,599 LUTs. Fetching
  uses the authors' compressed mirror, then verifies the decompressed file
  against Zenodo's published MD5, `dd6ae0655ba8a299a3d668cfc6cf10bf`.
- [sboxU](https://github.com/lpp-crypto/sboxU/tree/7066b825c979ceefa901e7be3b2afcc63f587bcf):
  the six literal-LUT/polynomial literature datasets, at the revision recorded
  in the local corpus descriptors. Python/Sage code is parsed as data and
  never executed.
- [Simon-Berg thesis](https://github.com/Simon-Berg/thesis/tree/c13952d2458cb692171816b483f4e8ac0c62455a):
  all 27 polynomial files (196,863 members), at the recorded revision.
- [Langevin May 2025 binary dump](https://langevin.univ-tln.fr/data/apns/apn-11888039-may-2025-8.out):
  all 11,888,039 records, including public classes absent from the published
  list. Its SHA-256 is pinned to the existing raw-file manifest.
- Taniguchi's two members are regenerated with the VBF constructor; catalog
  representative LUTs are read directly. These dependencies remain explicit
  limitations of original-file provenance.

Downloads record URLs, revisions, byte counts and SHA-256 hashes in
`sources/provenance.toml`. Each source checkpoint binds input bytes, verification
and reader code, the Julia manifest, decoding code, dimension, expected count
and any limit. Changed identities refuse to resume; use a fresh directory.
A timing prefix never receives complete coverage. The mixed upstream literal
lists also contain nonquadratic functions; every excluded record is retained
in `excluded(member_idx, reason, lut_sha256)` and counted in the summary.
Unexpected validation failures in declared quadratic sources stop the stage
with a nonzero exit status, retaining previously committed batches.

Each source produces a SQLite `records` table with `member_idx`, `sigma_hash`
and `lut_sha256`, and a TOML summary. `comparison.toml` reports missing,
changed and orphan rows in the old index; differences between original and
stored LUT/signature sets; and the fresh union's signature count. Import-content
and old-index agreement have separate Boolean verdicts; exhaustive coverage
alone does not imply those comparisons passed.
`fresh_union.sqlite` contains the freshly computed baseline in
`signatures(sigma_hash)`. Comparison refuses absent/incomplete sources.
The union is built separately and installed after comparison succeeds;
candidate checking verifies its checksum against the completed report.

A different signature separates quadratic APN CCZ classes; a matching signature
is only a possible equivalence match. This workflow certifies the listed input
scope, not novelty throughout all published literature. It does not download
the older Sage snapshots or the duplicate text encoding of the binary dump;
the earlier raw cross-check lists those as subsets/re-encodings. Add them to
the scope if their independently rebuilt coverage is required.

The final `candidates` stage checks `search_b52/results/desk1/found.tsv` and the
three smaller census/search candidate files. Every candidate signature is
recomputed. `candidate_comparison.tsv` reports each match or absence;
`candidate_comparison.toml` breaks counts down by the search's original status.
`search_public_matches.tsv` identifies public dump records with a matching
signature and states whether the LUT itself matches. A signature hit without
an exact LUT match requires an EA/CCZ test to resolve equivalence.
Override `CANDIDATES="/path/one.tsv /path/two.tsv"` to check other runs.
The screenshot's independent audit is absent from this checkout; counts from
that screenshot must be compared with the new report, not assumed in advance.

The `equivalence` stage resolves the search matches against their original
public dump representatives using VBF's native partition refinement with
`relation=:ea`. It independently rechecks the candidate/public signatures and
the public record LUT digest before searching. Every positive result saves
both LUTs and an explicit affine graph map in `equivalence_checks.toml`.
`ea_witness.jl` checks the map's EA block structure, bijective input/output
blocks and the graph identity at all 256 inputs, using only the standard
library. Maps run from the candidate graph to the public graph, packed as
`(x << 8) | F(x)`; the 16 columns are images of basis bits 0 through 15.

```sh
make -C census/quadratic_apn8/rebuild_corpus equivalence EA_TIMEOUT=60 EA_MAX_NODES=1000000
make -C census/quadratic_apn8/rebuild_corpus verify-witnesses
```

Budget hits remain `inconclusive`. A negative result requires exhaustive
search against **every** public record with the matching signature. Checks
are saved after each candidate; completed verdicts resume and unresolved
ones are retried. The report binds input and source-code hashes; archive it
before rerunning with changed inputs or code. The completed run found explicit
EA witnesses for **all 61 matches**, with no inconclusive results. This also
certifies CCZ equivalence. The separate 110,436 absence results continue to
certify inequality to the rebuilt quadratic baseline.
