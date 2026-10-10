# APN8 evidence inspector

The frontend validates exact eight-bit functions, compares their signatures
with the independently rebuilt quadratic reference, and runs bounded EA/CCZ
pair comparisons. It shares the [discovery evidence layer](../../../packages/VBFSearch/README.md).
It does not label a signature hit “KNOWN” or corpus absence “literature-new”.

## Run and inspect

From the repository root:

```sh
make -C census/quadratic_apn8/web instantiate
make -C census/quadratic_apn8/web serve
# Browse a search or independently validated import:
make -C census/quadratic_apn8/web serve \
  run=/absolute/path/to/experiment
```

Open `http://127.0.0.1:8088/`. The server uses one default thread for queued
comparisons and one interactive thread for HTTP (`--threads=1,1`). It needs the
catalog and old sigma index to retrieve named reference functions, plus
`data/apn/reference/{comparison.toml,fresh_union.sqlite}` and
`data/apn/supplement.tsv` (see [reference setup](../../../data/apn/README.md)). The old index supplies record pointers; the
fresh, digest-checked reference controls corpus-absence conclusions. Missing
or changed provenance stops initialization rather than silently using an old
baseline. Package/environment setup is local to `web/`.

1. Paste a function in the first box and select **Validate and compare with
   corpus**. Input can be 256 integers 0..255 (F(0) first), 56 hexadecimal ANF
   digits, or a polynomial such as `x^3 mod=0x11D`. The polynomial default is
   0x11B; field basis and modulus must match the intended function.
2. Inspect differential uniformity, APN status, Boolean degree, linearity,
   nonlinearity, the absolute Walsh plot, sigma, LUT digest, reference digest
   and the explicitly scoped verdict. Expand the evidence panel for the ANF,
   polar ranks, ortho-derivative and DDT histogram. A failed APN check includes
   a difference and its more-than-two solutions.
3. **Download validation evidence** saves the exact LUT and all displayed
   evidence as JSON. A reference signature match remains unresolved. If a
   reference LUT can be loaded, use its comparison button; missing target
   lookup is not evidence of inequivalence.
4. For a particular reference or another candidate, paste its function in the
   second box, choose **CCZ** or **EA**, set time/node limits, and select
   **Compare**. The result is a verified positive graph witness, a scoped
   invariant/computational negative, or an inconclusive budget stop. Download
   the TOML comparison certificate and recheck it with the standard-library
   verifier below. One comparison executes at a time.
5. With `--run PATH`, select **Load candidates**, optionally filtering for
   additional signatures, then **Load** a stored exact LUT. An imported
   historical bundle normally has no “additional” flag; leave that filter off.
   Every bounded pair check is saved as TOML under `data/apn/runs/web/`
   and, when a run is selected, appended transactionally to its `comparisons`
   table. The inspector can coexist with an enumeration writer because these
   append-only comparisons do not change search cursors.

## Meaning of verdicts

| Verdict | Guarantee |
|---|---|
| Not APN | Independent full DDT found differential uniformity greater than two |
| APN, not quadratic | APN verified; quadratic sigma comparison does not apply |
| Reference invariant match | Candidate needs an exact comparison; sigma agreement is not an equivalence proof |
| Study invariant match | Same limitation for a historical candidate; its absence is relative to the specified public reference |
| Identical public supplement | Literal LUT equality with the independently verified supplemental function |
| Inequivalent to documented quadratic corpus | Different signatures from all specified quadratic references; literature-wide novelty unresolved |
| Inequivalent to all APN power functions | Different signatures from all four Gold exponents, using Yoshiara 2016 |
| Equivalent with verified witness | Invertible affine ambient graph map independently checked on all 256 points; EA additionally preserves the output subspace |
| Inequivalent by exhaustive solver | Correct native complete solver exhausted its search; computational result, not an independently serialized negative proof tree |
| Inconclusive budget | No equivalence/inequivalence conclusion |

CCZ remains the correct relation for an arbitrary nonquadratic target. EA
inequivalence alone does not settle general CCZ equivalence. All finite checks
are computation, not proof-assistant formalization. The complete announced 2026
switching dataset and any unrepresented non-power constructions remain
comparison gaps; see [AUDIT.md](../../../packages/VBFSearch/AUDIT.md).

## API and verification

`POST /api/classify` accepts plain function text. `POST /api/ea` checks the
server-selected matched target. `POST /api/compare` accepts JSON fields
`candidate`, `target`, `relation`, `timeout_seconds` and `max_nodes` (server caps:
600 seconds and ten million nodes). `GET /api/ea/ID` polls a job;
`GET /api/ea/ID/certificate` downloads its evidence. `GET /api/health` includes
reference provenance. `GET /api/candidates?limit=50&offset=0&additional=false`
paginates stored candidates. `GET /api/relationships` returns the latest 200
recorded pair checks; `GET /api/classification` exposes the frozen snapshot
classification report when present. An absent edge is unresolved, never inferred inequivalence.

```sh
make -C census/quadratic_apn8/web test
# Recheck the persisted TOML positive witness/invariant certificate without VBF:
julia --startup-file=no \
  packages/VBFSearch/src/verification/verify_certificate.jl comparison.toml
```

`bin/vbf classify` resolves equal-sigma candidate buckets incrementally,
recording proven components and unresolved pairs. Complete canonical
classification beyond that finite candidate set, complete literature coverage, an
independent negative-search certificate and proof-assistant formalization remain
missing. The interface exposes existing evidence; it does not fill those gaps with a
novelty label. Publication CSV/LaTeX tables and SVG/PDF figures are generated by
`bin/vbf report`, rather than screen captures.
