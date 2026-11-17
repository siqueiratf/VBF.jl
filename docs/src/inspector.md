# APN inspector

Inspect an eight-bit function, validate its APN property, view its mathematical
invariants and run bounded EA or CCZ comparisons. The page uses the same
`VBFSearch`, `VBF` and `VBFCatalog` evidence pipeline as the command-line tools.

## Launch the interactive documentation

You need Julia >= 1.12, `git`, `curl` and `gzip`. From a fresh clone, run this
command from the repository root:

```sh
make -C docs serve
```

Open <http://127.0.0.1:8088/docs/> and select **APN inspector** in the sidebar.
The command installs the environments and builds the missing reference data
(`make -C docs data`). It builds the docs without deploying them, then starts the
Julia backend. Stop it with Ctrl-C. The first run downloads the Beierle et al. 2025
corpus (3.16 GB) once. `make -C docs serve-inspector` starts only the inspector,
at <http://127.0.0.1:8088/>, and does not build the docs.
Use `port=8090` to change the port. To browse a saved experiment, provide an
absolute path:

```sh
make -C docs serve run=/absolute/path/to/experiment
```

!!! note "The inspector needs a local server"
    This site is static. It shows the interface below, but the checks, the
    database queries and the equivalence searches run in the local Julia server.
    On this site, the interface shows "Julia backend unavailable". Run
    `make -C docs serve-inspector` in a clone and open <http://127.0.0.1:8088/>.
All inputs and evidence stay on the server you run.

[Open the inspector in a separate tab](assets/apn-inspector.html)

```@raw html
<iframe id="apn-inspector" title="Interactive APN evidence inspector"
        style="width:100%;height:1100px;border:1px solid #ddd;border-radius:4px;"
        loading="lazy"></iframe>
<script>
(() => {
    const frame = document.getElementById('apn-inspector');
    const link = document.querySelector('a[href$="assets/apn-inspector.html"]');
    if (frame && link) frame.src = link.href;
})();
</script>
<noscript>The inspector requires JavaScript and the local Julia backend.</noscript>
```

## Inspect and validate a candidate

1. Paste a LUT (256 integers, `F(0)` first), 56 hexadecimal digits encoding
   the 28 quadratic ANF coefficients, or a polynomial such as `x^3 mod=0x11D`.
   The polynomial default is `0x11B`; choose the intended field basis.
2. Select **Validate and compare with corpus**. Inspect APN status, degree,
   differential uniformity, linearity, nonlinearity and the Walsh plot.
   Expand the evidence panel for the ANF, DDT histogram, polar ranks and
   ortho-derivative. Download the exact LUT and evidence as JSON.
3. Paste a second function to run a bounded **CCZ** or **EA** comparison.
   Inspect its conclusion and download the comparison certificate.
   A stopped solver is inconclusive; increase the budget to continue investigating.
4. With a saved run selected at launch, select **Load candidates** to inspect
   persisted LUTs and any existing classification snapshot.

## What the evidence establishes

| Result | Interpretation |
|:---|:---|
| Full DDT has uniformity two | Computationally verifies APN on all inputs |
| Distinct sigma signatures of verified quadratic APNs | Certifies CCZ inequivalence within the theorem's quadratic scope |
| Equal signatures | Necessary filter; exact equivalence remains unresolved |
| Verified affine graph map | Certifies CCZ equivalence; EA additionally preserves the output subspace |
| Complete solver exhaustion | Computational inequivalence result; no independent negative proof tree is exported |
| Time or node limit reached | Unresolved |
| Absent signature in a reference | Inequivalent to that documented quadratic corpus; does not establish literature-wide novelty |

Every verdict retains its reference scope and provenance. See the
[Search guarantees](https://github.com/siqueiratf/VBF.jl/blob/main/packages/VBFSearch/README.md)
for outstanding coverage gaps. Check a downloaded certificate through VBF:

```sh
bin/vbf verify comparison.toml
```

Publication tables and standalone figures come from `bin/vbf report`.
See the [inspector guide](https://github.com/siqueiratf/VBF.jl/blob/main/docs/inspector/README.md)
for API routes and the [search guide](https://github.com/siqueiratf/VBF.jl/blob/main/packages/VBFSearch/README.md)
for checkpointing, classification and reports.
