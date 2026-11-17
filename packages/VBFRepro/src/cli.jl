# Command-line interface of bin/vbfrepro: help per command, paper lookup by a
# unique part of the ID or bib key, and shell completion scripts.

const COMMANDS = ["list", "info", "run", "test", "scaffold", "check", "completions", "help"]

const USAGE = Dict(
    "list" => """
        Usage: bin/vbfrepro list [FILTER]

        Print the ID and the bib key of each paper reproduction. FILTER keeps the
        papers whose ID or bib key contains it (case-insensitive).

        Example: bin/vbfrepro list yu""",
    "info" => """
        Usage: bin/vbfrepro info PAPER

        Show the targets and the parameters of a paper. PAPER is the ID, the bib
        key or a unique part of them, for example 202211-yu-qam, Yu_202211 or yu-qam.""",
    "run" => """
        Usage: bin/vbfrepro run PAPER [--target TARGET] [--param KEY=VALUE ...]
                                      [--timeout-seconds N] [--output DIR]

        Run a target of a paper (default: report) in a separate process and record
        the evidence (run.toml, output.log) under packages/VBFRepro/src/results/runs/.

          --target TARGET       Makefile target; see bin/vbfrepro info PAPER
          --param KEY=VALUE     Makefile parameter, for example --param limit=1000
          --timeout-seconds N   stop the run after N seconds
          --output DIR          write the evidence to DIR
          --list                show the targets and parameters of PAPER

        Example: bin/vbfrepro run yu-qam --target small_searches --timeout-seconds 600""",
    "test" => """
        Usage: bin/vbfrepro test PAPER [--timeout-seconds N] [--output DIR]

        Run the tests of a paper and record the evidence like run.

        Example: bin/vbfrepro test 202211-yu-qam --timeout-seconds 300""",
    "scaffold" => """
        Usage: bin/vbfrepro scaffold PAPER [--update]

        Write PAPER/paper.toml with candidate claims found in the file headers, the
        Makefile help and the tests. Every candidate has review = "pending": a person
        reviews it against the paper and the code. An existing file is not replaced;
        --update only appends new candidates and refreshes the unassigned list.""",
    "check" => """
        Usage: bin/vbfrepro check [PAPER]

        Check paper.toml of one paper, or of all papers that have one. Errors (schema,
        missing files, targets or tests) give exit status 1; review items (pending
        candidates, files in no claim) are listed but do not fail.""",
    "completions" => """
        Usage: bin/vbfrepro completions bash|zsh|fish

        Print a completion script. Load it in your shell:
          bash:  source <(bin/vbfrepro completions bash)
          zsh:   source <(bin/vbfrepro completions zsh)
          fish:  bin/vbfrepro completions fish | source""",
    "help" => """
        Usage: bin/vbfrepro help [COMMAND]

        Show the commands, or the help of one command.""",
)

const OVERVIEW = """
    Usage: bin/vbfrepro COMMAND [ARGS]

    Run the paper reproductions of VBF.jl and record their evidence.

    Commands:
      list [FILTER]        list the paper IDs and bib keys
      info PAPER           show the targets and parameters of a paper
      run PAPER            run a target of a paper (default: report)
      test PAPER           run the tests of a paper
      scaffold PAPER       write candidate portal metadata (paper.toml)
      check [PAPER]        check the portal metadata
      completions SHELL    print a completion script for bash, zsh or fish
      help [COMMAND]       show this help, or the help of a command

    PAPER is the ID, the bib key or a unique part of them (bin/vbfrepro list).
    A unique prefix of a command also works, for example "te" for test.
    Use bin/vbfrepro COMMAND --help for the options of a command."""

"""An error of the command line: printed with its usage hint, exit status 2."""
struct UsageError <: Exception
    msg::String
    command::String
end
UsageError(msg) = UsageError(msg, "")
Base.showerror(io::IO, e::UsageError) = print(io, e.msg)

"""Resolve a command from its name or a unique prefix."""
function resolve_command(word::AbstractString)
    word in COMMANDS && return String(word)
    found = filter(c -> startswith(c, word), COMMANDS)
    length(found) == 1 && return only(found)
    isempty(found) && throw(UsageError("unknown command '$word'; the commands are $(join(COMMANDS, ", "))"))
    throw(UsageError("'$word' matches more than one command: $(join(found, ", "))"))
end

"""Papers as `(id, bib)` pairs; `bib` is empty for an unregistered slug."""
function paper_index(; root=papers_root())
    keys = isfile(publications_path()) ? TOML.parsefile(publications_path()) : Dict{String,Any}()
    [(id=p.id, bib=String(get(keys, p.id, ""))) for p in discover_papers(; root)]
end

"""Resolve a paper from its ID, its bib key or a unique part of them (case-insensitive)."""
function resolve_paper(word::AbstractString; root=papers_root(), io=stderr)
    papers = paper_index(; root)
    for p in papers
        (word == p.id || (!isempty(p.bib) && lowercase(word) == lowercase(p.bib))) && return p.id
    end
    needle = lowercase(word)
    found = filter(p -> occursin(needle, p.id) || occursin(needle, lowercase(p.bib)), papers)
    if length(found) == 1
        println(io, "vbfrepro: using paper $(only(found).id)")
        return only(found).id
    end
    isempty(found) && throw(UsageError("no paper matches '$word'; run bin/vbfrepro list to see the IDs"))
    throw(UsageError("'$word' matches $(length(found)) papers:\n  " *
        join([p.id for p in found], "\n  ") * "\nUse a longer part of the ID, or run bin/vbfrepro list."))
end

"""Makefile parameters (`name ?= value`) of a paper, in file order."""
function paper_parameters(path)
    params = Pair{String,String}[]
    for line in eachline(joinpath(path, "Makefile"))
        m = match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\?=\s*(.*)$", line)
        m === nothing || push!(params, m[1] => strip(m[2]))
    end
    params
end

function print_info(id; io=stdout)
    path = paper_path(id)
    bib = something(paper_bib_key(id), "")
    println(io, id, isempty(bib) ? "" : "  ($bib)")
    println(io, "Directory: ", relpath(path, repo_root()))
    help = read(ignorestatus(`make --no-print-directory -s -C $path help`), String)
    isempty(strip(help)) || print(io, "\n", help)
    params = paper_parameters(path)
    if occursin(r"(?i)parameters", help) && !isempty(params)
        println(io, "\nPass a parameter with --param KEY=VALUE, for example --param $(first(first(params)))=...")
    elseif !isempty(params)
        println(io, "\nParameters (--param KEY=VALUE):")
        width = maximum(length(first(p)) for p in params)
        foreach(p -> println(io, "  ", rpad(first(p), width), "  default ", last(p)), params)
    end
    println(io, "\nRun a target: bin/vbfrepro run $id --target TARGET")
end

const COMPLETION_BASH = raw"""
_vbfrepro() {
    local cur prev root papers
    cur=${COMP_WORDS[COMP_CWORD]}; prev=${COMP_WORDS[COMP_CWORD-1]}
    root=$(cd -- "$(dirname -- "$(command -v "${COMP_WORDS[0]}" 2>/dev/null || echo "${COMP_WORDS[0]}")")/.." 2>/dev/null && pwd)
    papers=$(ls "$root/packages/VBFRepro/src" 2>/dev/null | grep -E '^[0-9]{6}-')
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "list info run test scaffold check completions help" -- "$cur")); return
    fi
    case "$prev" in
        info|run|test|scaffold|check) COMPREPLY=($(compgen -W "$papers" -- "$cur")); return;;
        completions) COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur")); return;;
        help) COMPREPLY=($(compgen -W "list info run test scaffold check completions" -- "$cur")); return;;
        --output) COMPREPLY=($(compgen -d -- "$cur")); return;;
        --target) COMPREPLY=($(compgen -W "$(grep -oE '^[a-z0-9_]+:' "$root/packages/VBFRepro/src/${COMP_WORDS[2]}/Makefile" 2>/dev/null | tr -d :)" -- "$cur")); return;;
        --param) COMPREPLY=($(compgen -W "$(sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\?=.*/\1=/p' "$root/packages/VBFRepro/src/${COMP_WORDS[2]}/Makefile" 2>/dev/null)" -- "$cur")); compopt -o nospace 2>/dev/null; return;;
        --timeout-seconds) return;;
    esac
    case "${COMP_WORDS[1]}" in
        run) COMPREPLY=($(compgen -W "--target --param --timeout-seconds --output --list --help" -- "$cur"));;
        test) COMPREPLY=($(compgen -W "--timeout-seconds --output --help" -- "$cur"));;
    esac
}
complete -F _vbfrepro vbfrepro bin/vbfrepro ./bin/vbfrepro
"""

const COMPLETION_ZSH = "autoload -U +X bashcompinit && bashcompinit\n" * COMPLETION_BASH

const COMPLETION_FISH = raw"""
function __vbfrepro_makefile
    set -l words (commandline -opc)
    set -l root (path resolve (path dirname (command -v $words[1]; or echo $words[1]))/..)
    echo $root/packages/VBFRepro/src/$words[3]/Makefile
end
function __vbfrepro_papers
    set -l bin (commandline -opc)[1]
    set -l root (path resolve (path dirname (command -v $bin; or echo $bin))/..)
    for d in $root/packages/VBFRepro/src/*/
        set -l id (path basename $d)
        string match -qr '^[0-9]{6}-' $id; and echo $id
    end
end
for c in vbfrepro bin/vbfrepro ./bin/vbfrepro
    complete -c $c -f
    complete -c $c -n __fish_use_subcommand -a list -d 'list the paper IDs'
    complete -c $c -n __fish_use_subcommand -a info -d 'targets and parameters of a paper'
    complete -c $c -n __fish_use_subcommand -a run -d 'run a target of a paper'
    complete -c $c -n __fish_use_subcommand -a test -d 'run the tests of a paper'
    complete -c $c -n __fish_use_subcommand -a scaffold -d 'write candidate portal metadata'
    complete -c $c -n __fish_use_subcommand -a check -d 'check the portal metadata'
    complete -c $c -n __fish_use_subcommand -a completions -d 'print a completion script'
    complete -c $c -n __fish_use_subcommand -a help -d 'show the help'
    complete -c $c -n '__fish_seen_subcommand_from info run test scaffold check; and test (count (commandline -opc)) -eq 2' -a '(__vbfrepro_papers)'
    complete -c $c -n '__fish_seen_subcommand_from completions' -a 'bash zsh fish'
    complete -c $c -n '__fish_seen_subcommand_from help' -a 'list info run test scaffold check completions'
    complete -c $c -n '__fish_seen_subcommand_from run' -l target -x -d 'Makefile target' -a '(string match -rg "^([a-z0-9_]+):" < (__vbfrepro_makefile) 2>/dev/null)'
    complete -c $c -n '__fish_seen_subcommand_from run' -l param -x -d 'KEY=VALUE' -a '(string match -rg "^([A-Za-z_][A-Za-z0-9_]*)\\s*\\?=" < (__vbfrepro_makefile) 2>/dev/null | string replace -r \'$\' =)'
    complete -c $c -n '__fish_seen_subcommand_from run' -l list -d 'targets and parameters'
    complete -c $c -n '__fish_seen_subcommand_from run test' -l timeout-seconds -r
    complete -c $c -n '__fish_seen_subcommand_from run test' -l output -r -F
    complete -c $c -l help -d 'show the help'
end
"""

"""Command-line entry; return an exit code. Usage errors throw [`UsageError`](@ref)."""
function main(args=ARGS)
    args = String.(args)
    if isempty(args) || first(args) in ("--help", "-h")
        println(OVERVIEW)
        return 0
    end
    command = resolve_command(first(args))
    rest = args[2:end]
    if command == "help" || "--help" in rest || "-h" in rest
        topic = command == "help" ? (isempty(rest) ? "" : resolve_command(first(rest))) : command
        println(isempty(topic) ? OVERVIEW : USAGE[topic])
        return 0
    end
    if command == "list"
        length(rest) <= 1 || throw(UsageError("list accepts at most one FILTER", "list"))
        needle = lowercase(isempty(rest) ? "" : only(rest))
        papers = filter(p -> occursin(needle, p.id) || occursin(needle, lowercase(p.bib)), paper_index())
        width = maximum(length(p.id) for p in paper_index())
        foreach(p -> println(rpad(p.id, width), "  ", p.bib), papers)
        isempty(papers) && println(stderr, "vbfrepro: no paper matches '$(only(rest))'")
        return isempty(papers) ? 1 : 0
    elseif command == "completions"
        length(rest) == 1 || throw(UsageError("completions needs a shell: bash, zsh or fish", command))
        shells = Dict("bash" => COMPLETION_BASH, "zsh" => COMPLETION_ZSH, "fish" => COMPLETION_FISH)
        haskey(shells, only(rest)) || throw(UsageError("unknown shell '$(only(rest))'; use bash, zsh or fish", command))
        print(shells[only(rest)])
        return 0
    end
    if command == "check"
        length(rest) <= 1 || throw(UsageError("check accepts at most one PAPER", command))
        ids = isempty(rest) ? [p.id for p in discover_papers() if isfile(joinpath(p.path, PAPER_FILE))] :
            [resolve_paper(only(rest))]
        nerr = 0
        for id in ids
            errors, review = check_paper_metadata(id)
            foreach(e -> println("error: ", e), errors)
            foreach(r -> println("review: ", r), review)
            nerr += length(errors)
        end
        println("checked $(length(ids)) paper(s): $nerr error(s)")
        return nerr == 0 ? 0 : 1
    end
    if isempty(rest) || startswith(first(rest), "--")
        "--list" in rest && (main(["list"]); return 0)
        throw(UsageError("$command needs a PAPER; run bin/vbfrepro list to see the IDs", command))
    end
    id = resolve_paper(first(rest))
    if command == "scaffold"
        all(a -> a == "--update", rest[2:end]) || throw(UsageError("scaffold accepts only --update", command))
        file = scaffold_paper(id; update = "--update" in rest)
        claims, unassigned = discover_candidates(id)
        println("wrote $(relpath(file, repo_root())): $(length(claims)) candidate claim(s), $(length(unassigned)) unassigned item(s)")
        println("Review each claim, then run bin/vbfrepro check $id")
        return 0
    end
    if command == "info" || "--list" in rest
        command == "info" && length(rest) > 1 && throw(UsageError("info accepts one PAPER", command))
        print_info(id)
        return 0
    end
    target = command == "test" ? "test" : "report"
    parameters = Dict{String,String}()
    timeout = nothing
    output = nothing
    index = 2
    while index <= length(rest)
        option = rest[index]
        startswith(option, "--") || throw(UsageError("unexpected argument '$option'", command))
        index < length(rest) || throw(UsageError("missing value for '$option'", command))
        value = rest[index+1]
        if option == "--target" && command == "run"
            target = value
        elseif option == "--param" && command == "run"
            pieces = split(value, '='; limit=2)
            length(pieces) == 2 || throw(UsageError("parameter must be KEY=VALUE", command))
            haskey(parameters, pieces[1]) && throw(UsageError("duplicate parameter '$(pieces[1])'", command))
            parameters[pieces[1]] = pieces[2]
        elseif option == "--timeout-seconds"
            timeout = tryparse(Float64, value)
            timeout === nothing && throw(UsageError("--timeout-seconds needs a number", command))
        elseif option == "--output"
            output = value
        else
            throw(UsageError("unsupported option '$option' for $command", command))
        end
        index += 2
    end
    result = run_paper(id; target, parameters, timeout_seconds=timeout, output)
    println("$(result.paper) $(result.target): $(result.status)\nEvidence: $(result.output)")
    return result.status == "passed" ? 0 : 1
end

"""Entry point of bin/vbfrepro: print usage errors without a stack trace."""
function cli(args=ARGS)
    try
        return main(args)
    catch error
        error isa UsageError || error isa ArgumentError || rethrow()
        println(stderr, "vbfrepro: ", sprint(showerror, error))
        command = error isa UsageError ? error.command : ""
        message = sprint(showerror, error)
        if !isempty(command)
            println(stderr, "Run bin/vbfrepro $command --help for the options.")
        elseif !occursin("bin/vbfrepro", message)
            println(stderr, "Run bin/vbfrepro help for the commands.")
        end
        return 2
    end
end
