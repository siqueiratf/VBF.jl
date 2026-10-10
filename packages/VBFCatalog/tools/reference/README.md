# Independently rebuilt APN reference

These tools consume the catalog and pinned original public files to build a
separate quadratic (8,8)-APN comparison reference. They never update the curated
catalog. Run them from the repository workspace environment, Julia >= 1.12.

```sh
make -C packages/VBFCatalog/tools/reference test
make -C packages/VBFCatalog/tools/reference all \
  OUTDIR="$PWD/data/apn/rebuilds/reference01" threads=16
```

`all` runs fetch, stored-corpus rebuilding, original-file rebuilding, comparison,
candidate checking and bounded EA checks sequentially. The default output is
`data/apn/rebuilds/original-source/`. Always choose a fresh output directory when
the implementation, dependency environment or input files change. For a bounded
smoke run, use `rebuild.jl stored --outdir DIR --limit N`; partial coverage cannot
produce a complete reference manifest. Fetching all originals and rebuilding
millions of records can take substantial time and disk space.

`raw_readers.jl` decodes decimal LUTs, gzip text, tar members and documented
64-byte records of eight little-endian 28-bit colex coefficient masks. Malformed
or truncated records keep explicit failure flags; out-of-format masks are rejected.
The independent DDT, ANF, polar-rank and signature verifier is shared from
`VBFSearch/src/verification/` and remains standard-library-only. Decoding and
verification are distinct code paths. `paths.jl` resolves recorded historical
census input paths to their relocated files; every caller still checks digests.

Checkpoint identities include input and executable-source hashes. Coverage
requires every expected record, successful verification and explicit provenance.
`compare.jl` records exclusions and failures and constructs the union only from
complete inputs. Absence proves separation from the specified quadratic reference
through the separating invariant. A matching signature requires equivalence
checks; it does not establish an equivalence class by itself.

The original evidence and downloaded files remain under
`data/apn/archive/census/results/signature_rebuild/`. Their embedded historical
paths and hashes are unchanged. The [data guide](../../../../data/apn/README.md)
explains how to prepare the reference used by searches, and the
[research assessment](../../../VBFSearch/AUDIT.md) states the scope of novelty.
