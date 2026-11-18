# VBF.jl portal

The website of VBF.jl: Reproductions, Catalog and Library. A Julia generator (module
`VBFPortal`) builds static pages from the paper folders, the evidence records and the
catalog; Documenter builds the Library. The browser reads catalog entries from a SQLite
query database over HTTP Range requests (`js/members.js`).

| Folder | Content |
|---|---|
| `src/` | `VBFPortal`: identity, snapshots, model, rendering, catalog pages, Library decoration, link check |
| `templates/`, `assets/` | HTML templates; `portal.css`, `frame.css` (header and footer of every page), `library.css` (Documenter), `portal.js` |
| `js/` | Browser code, bundled with esbuild into `assets/js/` (ignored) |
| `catalog.toml` | Site names of the catalog families and corpora (presentation text only) |
| `build.jl` | The build: Library, portal pages, catalog pages, redirects, link check |
| `review/serve.mjs` | A local server with the behaviour of GitHub Pages (base path `/VBF.jl/`, HTTP Range) |
| `test/` | Julia unit tests (`runtests.jl`) and browser tests (`browser/`, Playwright and axe-core) |
| `POC.md` | The catalog proof of concept (stage S0) and its storage decision |

## Build and review the complete portal

You need Julia 1.12 or later and Node.js 22 or later. Run these commands from the
repository root:

```sh
make -C docs portal         # catalog data, production query database, browser code, build
make -C docs serve-portal   # then open http://127.0.0.1:8430/VBF.jl/
```

`make -C docs portal` does these steps:

1. `make -C docs data` installs the catalog data of this checkout: the Zenodo version of the
   snapshot when one exists (about 490 MB), else a build from the originals.
2. `portal-query` gets the production query database (all corpora, 759 MiB) into
   `.cache/vbfcatalog/query-<snapshot key>.sqlite`. It downloads the Zenodo copy of this
   snapshot when one exists; else it builds the file from the local catalog.
3. `portal-js` bundles the browser code (`npm ci`, `node build.mjs`).
4. `build.jl` builds the site into `docs/portal/build/`. It reads the Zenodo version list;
   offline, it uses the last cached list, and `--offline` skips the request.

The server serves `docs/portal/build/` under `/VBF.jl/`, as GitHub Pages will. The query
database in the build is a symbolic link to the file in `.cache/vbfcatalog/`.

## Tests

```sh
julia --project=docs/portal -e 'using Pkg; Pkg.test()'     # unit tests
make -C docs test-portal                                    # browser tests, full database
```

`test-portal` runs every browser test at desktop and mobile width, and the tests of
`production.spec.mjs` against the production query database and against the query
database of an archived Zenodo version. These record the requests, bytes and time of each
query in `docs/portal/test/browser/test-results/production-measurements.json`. CI runs the
same browser tests on a small query database with three corpora; the production tests
then skip.

Screenshots for a design review (with the server running):

```sh
node docs/portal/test/browser/screenshots.mjs OUT_DIR
```

## Deployment

The live site at https://siqueiratf.github.io/VBF.jl/ is still built by `docs/make.jl`.
The portal replaces it only after an explicit approval (stage S5.6). Until then, CI builds
the portal as the `portal-preview` artifact.
