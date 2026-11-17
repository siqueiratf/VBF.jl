# Command-line tools

Two scripts in `bin/` run the work of the repository from a shell. Run them
from the root of a clone, after `julia --project=. -e 'using Pkg; Pkg.instantiate()'`.

| Script | Purpose |
|:---|:---|
| `bin/vbfrepro` | run the [paper reproductions](reproductions.md) and record their evidence |
| `bin/vbf` | run the [searches](generated/search.md) for new quadratic APN functions |

## Help

Each script prints its commands with `help`, and the options of one command
with `COMMAND --help`:

```sh
bin/vbfrepro help
bin/vbfrepro run --help
bin/vbf help compare
```

A unique prefix of a command also works: `bin/vbfrepro te PAPER` runs `test`.
An incomplete command prints what is missing and the next command to run:

```text
$ bin/vbfrepro run
vbfrepro: run needs a PAPER; run bin/vbfrepro list to see the IDs
Run bin/vbfrepro run --help for the options.
```

## Find and run a paper

```sh
bin/vbfrepro list                 # all paper IDs and bib keys
bin/vbfrepro list yu              # only the papers whose ID or bib key contains "yu"
bin/vbfrepro info yu-qam          # targets and parameters of one paper
bin/vbfrepro test 202211-yu-qam --timeout-seconds 300
bin/vbfrepro run yu-qam --target small_searches --param limit=1000
```

`PAPER` is the ID (`202211-yu-qam`), the bib key (`Yu_202211`) or a unique part
of them (`yu-qam`). If a part matches more than one paper, the script lists the
matches. Each run writes `run.toml` and `output.log` under
`packages/VBFRepro/src/results/runs/PAPER/`.

## Tab completion

The scripts print completion scripts for bash, zsh and fish. The completion
knows the commands, the paper IDs, the targets and parameters of a paper, and
the options:

```sh
source <(bin/vbfrepro completions bash); source <(bin/vbf completions bash)   # bash
source <(bin/vbfrepro completions zsh);  source <(bin/vbf completions zsh)    # zsh
bin/vbfrepro completions fish | source; bin/vbf completions fish | source    # fish
```

To keep it, put the same lines, with the absolute path of `bin/`, in your shell
startup file. Then, for example, `bin/vbfrepro run 2022<Tab>` lists the papers of
2022, and `bin/vbfrepro run 202211-yu-qam --target <Tab>` lists the targets of
that paper.

## Searches

```sh
bin/vbf search --output /tmp/run1 --duration 10m --threads 4
bin/vbf status /tmp/run1
bin/vbf resume /tmp/run1 --duration 10m --threads 4
```

See the [search guide](generated/search.md) for the methods, the checkpoints and
the publication of the results.
