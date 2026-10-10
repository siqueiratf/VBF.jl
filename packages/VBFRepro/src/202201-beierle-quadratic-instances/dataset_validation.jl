# Implements dataset count, APN verification, and quadratic-degree verification.
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: Results — dataset-counts, apn-verification, quadratic-degree
#
# VBF API used: SBox, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

const _DATASETS = [
    ("apn_8bit.txt",  8,  12921),
    ("apn_9bit.txt",  9,  35),
    ("apn_10bit.txt", 10, 5),
]

"""
    dataset_counts(io; save_results) -> NamedTuple

Count functions in each dataset file and verify every line has 2^n entries.
Beierle–Leander (2022), Results section (headline counts).
"""
function dataset_counts(io::IO = stdout; save_results::Bool = false, input_dir::AbstractString = joinpath(@__DIR__, "inputs"))
    print_section("dataset-counts", io)
    results = []
    all_ok = true
    for (fname, n, expected) in _DATASETS
        path = joinpath(input_dir, fname)
        if !isfile(path)
            print_kv("n=$n", "INCONCLUSIVE: source unavailable ($path)", io)
            all_ok = false
            push!(results, (; file = fname, n, status = :unavailable, ok = false))
            continue
        end
        expected_len = 1 << n
        count = 0
        malformed = 0
        for line in eachline(path)
            s = strip(line)
            isempty(s) && continue
            count += 1
            lut = parse_lut_line(s)
            if length(lut) != expected_len
                malformed += 1
            end
        end
        count_ok = count == expected
        form_ok  = malformed == 0
        ok = count_ok && form_ok
        all_ok = all_ok && ok
        print_kv("file", fname, io)
        print_kv("  count",     count,     io)
        print_kv("  expected",  expected,  io)
        print_kv("  malformed", malformed, io)
        print_check("n=$n: count and well-formedness", ok, io)
        push!(results, (; file=fname, n, count, expected, malformed, ok))
    end
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "dataset_counts.toml"), "w") do f
            println(f, "# dataset_counts results")
            for r in results
                println(f, "[[result]]")
                if hasproperty(r, :status)
                    println(f, "file = \"$(r.file)\"")
                    println(f, "n = $(r.n)")
                    println(f, "status = \"$(r.status)\"")
                    continue
                end
                println(f, "file = \"$(r.file)\"")
                println(f, "n = $(r.n)")
                println(f, "count = $(r.count)")
                println(f, "expected = $(r.expected)")
                println(f, "malformed = $(r.malformed)")
                println(f, "ok = $(r.ok)")
            end
        end
    end
    status = all_ok ? :passed : any(r -> hasproperty(r, :status) && r.status == :unavailable, results) ? :inconclusive : :failed
    return (; results, all_ok, status)
end

"""
    verify_apn(io; sample_size, full_search, save_results) -> NamedTuple

Verify differential_uniformity == 2 for dataset functions.
For n >= 9 or full_search=true, checks all functions. Otherwise checks
sample_size functions from the n=8 dataset.
Beierle–Leander (2022), Results — apn-verification.
"""
function verify_apn(
    io::IO = stdout;
    sample_size::Int = 100,
    full_search::Bool = false,
    save_results::Bool = false,
    input_dir::AbstractString = joinpath(@__DIR__, "inputs"),
)
    sample_size > 0 || full_search || throw(ArgumentError("sample_size must be positive unless full_search=true"))
    print_section("apn-verification", io)
    results = []
    all_ok = true
    for (fname, n, total) in _DATASETS
        path = joinpath(input_dir, fname)
        if !isfile(path)
            print_kv("n=$n", "INCONCLUSIVE: source unavailable ($path)", io)
            all_ok = false
            push!(results, (; file = fname, n, status = :unavailable, ok = false))
            continue
        end
        exhaustive = (n >= 9) || full_search
        limit = exhaustive ? typemax(Int) : sample_size
        checked = 0
        failures = Int[]
        for (i, f) in enumerate(stream_dataset(path; limit))
            if differential_uniformity(f) != 2
                push!(failures, i)
            end
            checked += 1
        end
        ok = checked > 0 && isempty(failures)
        all_ok = all_ok && ok
        mode = exhaustive ? "exhaustive" : "sampled ($checked / $total)"
        print_kv("file", fname, io)
        print_kv("  mode", mode, io)
        print_kv("  checked", checked, io)
        if !ok
            print_kv("  failed at indices", failures, io)
        end
        print_check("n=$n: all checked are APN ($mode)", ok, io)
        push!(results, (; file=fname, n, checked, total, exhaustive, failures, ok))
    end
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "verify_apn.toml"), "w") do f
            println(f, "# verify_apn results")
            for r in results
                println(f, "[[result]]")
                if hasproperty(r, :status)
                    println(f, "file = \"$(r.file)\"")
                    println(f, "n = $(r.n)")
                    println(f, "status = \"$(r.status)\"")
                    continue
                end
                println(f, "file = \"$(r.file)\"")
                println(f, "n = $(r.n)")
                println(f, "checked = $(r.checked)")
                println(f, "total = $(r.total)")
                println(f, "exhaustive = $(r.exhaustive)")
                println(f, "ok = $(r.ok)")
            end
        end
    end
    status = all_ok ? :passed : any(r -> hasproperty(r, :status) && r.status == :unavailable, results) ? :inconclusive : :failed
    return (; results, all_ok, status)
end

"""
    verify_quadratic(io; sample_size, full_search, save_results) -> NamedTuple

Verify algebraic_degree == 2 for dataset functions.
For n >= 9 or full_search=true, checks all functions. Otherwise checks
sample_size functions from the n=8 dataset.
Beierle–Leander (2022), Results — quadratic-degree.
"""
function verify_quadratic(
    io::IO = stdout;
    sample_size::Int = 100,
    full_search::Bool = false,
    save_results::Bool = false,
    input_dir::AbstractString = joinpath(@__DIR__, "inputs"),
)
    sample_size > 0 || full_search || throw(ArgumentError("sample_size must be positive unless full_search=true"))
    print_section("quadratic-degree", io)
    results = []
    all_ok = true
    for (fname, n, total) in _DATASETS
        path = joinpath(input_dir, fname)
        if !isfile(path)
            print_kv("n=$n", "INCONCLUSIVE: source unavailable ($path)", io)
            all_ok = false
            push!(results, (; file = fname, n, status = :unavailable, ok = false))
            continue
        end
        exhaustive = (n >= 9) || full_search
        limit = exhaustive ? typemax(Int) : sample_size
        checked = 0
        failures = Int[]
        for (i, f) in enumerate(stream_dataset(path; limit))
            if algebraic_degree(f) != 2
                push!(failures, i)
            end
            checked += 1
        end
        ok = checked > 0 && isempty(failures)
        all_ok = all_ok && ok
        mode = exhaustive ? "exhaustive" : "sampled ($checked / $total)"
        print_kv("file", fname, io)
        print_kv("  mode", mode, io)
        print_kv("  checked", checked, io)
        if !ok
            print_kv("  failed at indices", failures, io)
        end
        print_check("n=$n: all checked are quadratic ($mode)", ok, io)
        push!(results, (; file=fname, n, checked, total, exhaustive, failures, ok))
    end
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "verify_quadratic.toml"), "w") do f
            println(f, "# verify_quadratic results")
            for r in results
                println(f, "[[result]]")
                if hasproperty(r, :status)
                    println(f, "file = \"$(r.file)\"")
                    println(f, "n = $(r.n)")
                    println(f, "status = \"$(r.status)\"")
                    continue
                end
                println(f, "file = \"$(r.file)\"")
                println(f, "n = $(r.n)")
                println(f, "checked = $(r.checked)")
                println(f, "total = $(r.total)")
                println(f, "exhaustive = $(r.exhaustive)")
                println(f, "ok = $(r.ok)")
            end
        end
    end
    status = all_ok ? :passed : any(r -> hasproperty(r, :status) && r.status == :unavailable, results) ? :inconclusive : :failed
    return (; results, all_ok, status)
end
