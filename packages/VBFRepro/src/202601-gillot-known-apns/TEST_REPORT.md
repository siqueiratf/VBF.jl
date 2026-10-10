# Validation report

Date: 9 October 2026. Runtime: Julia 1.13.1, root project. Generated inputs and outputs remain ignored.

## Automated checks

`make -C packages/VBFRepro/src/202601-gillot-known-apns test report` passed 4,416 assertions: 18 helper, 12 extension, 25 driver and 4,361 Section 2 invariant assertions. The final suite includes retained completion LUTs and a safe zero-input Table 6 result. All eleven zero-budget Makefile targets (nine tables and Sections 6/8) also passed; incomplete/full-scope distinctions remain visible.

The tests cover independent ANF evaluation, counting/moment identities, exact rectangular extension behavior, all thirteen bent representatives, stop semantics, corrupted portable census rejection, checkpoint path rejection, snapshot parameters/source hashes, and literal/spectral invariant parity. Private author inputs are unnecessary for the test suite. Related core checks passed 35 APN-extension assertions and six unsigned-span assertions. Root test/report logs: `/tmp/vbf-gl-final-tests.log`, `/tmp/vbf-gl-final-report.log`; target smoke log: `/tmp/vbf-gl-target-smoke.log`.

## Actual full computations

Final snapshots were generated from the frozen drivers: Table 1 (150,356 records, 2.72 s), Table 2 (all fourteen roots, 23.90 s with `max_nodes=1000000`, `timeout_seconds=120`, `compute_gamma=true`), Table 5 (716, 0.62 s), Table 7 (150,356, 2.28 s), Table 8 (716, 0.38 s), Lemma 1 and Proposition 1 (716 each, 0.68/0.69 s). Table 3 ran all fourteen specified interpretations (0.98 s), retaining `complete=false` for unresolved source parameters. The full Section 6 audit passed 716 parents, 45,108 directions and 20,674 witnesses (1.40 s), with two freshly regenerated parity systems and the expected graph components. Log: `/tmp/vbf-gl-final-snapshots.log`.

The earlier full Table 4 run classified all 45,108 components into 37 EA classes in 157.019 s, with 74,317 queries and zero inconclusive decisions. Independent review verified all 44,314 saved graph certificates and reconstructed the complete component multiplicities. A separate raw Python audit reproduced all Table 1 bins and all Table 5 counting-function bins. See `REVIEW.md` for methods and limitations.

## Bounded computations and provenance

`results/bounded_runs_summary.toml` records Table 6's 28 seed projections, 48 completions and 46 certified matches; Table 9's thirteen roots and four certified matches; and Section 8's eight quartic seeds, 30,128 orbit evaluations and no candidates. Every expensive profile used explicit node, solution and time limits. These results do not certify full two-coordinate closure, eight empty bent-extension sets, the 150-EA-class union, or complete bihomogeneous enumeration.

`results/bounded_execution_calls.txt` preserves exact invocations. `results/run_parameters_manifest.toml` binds supplementary post-execution limits to each original expensive artifact's SHA-256. Original artifacts and their process-captured source hashes remain unchanged. The README gives the measured values and published-versus-observed differences.

The original Table 2 artifact is preserved as `results/table2_original21s.toml`; its original node/time caps could not be recovered and are explicitly marked unknown in the supplemental manifest. The fresh `results/table2.toml` captures its limits at execution.
