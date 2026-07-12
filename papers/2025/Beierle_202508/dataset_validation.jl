# Implements streamed validation for the Zenodo dataset
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 5
#
# Pseudocode:
#   1. Locate a local new_apns.txt path from a parameter, environment variable, or input/datasets.
#   2. Parse only the requested number of LUT lines.
#   3. Validate each sample as a quadratic APN SBox, optionally with ortho-derivative construction.
# VBF API used: SBox, algebraic_degree, differential_uniformity, is_quadratic_apn, apn_ea_mugshot

include(joinpath(@__DIR__, "helpers.jl"))

function default_dataset_path()
    env_path = get(ENV, "BEIERLE2025_NEW_APNS_PATH", "")
    isempty(env_path) || return env_path
    joinpath(@__DIR__, "input", "datasets", ZENODO_FILE)
end

function resolved_dataset_path(path::AbstractString)
    isempty(path) ? default_dataset_path() : path
end

"Parse one LUT line containing decimal or 0x-prefixed byte values."
function parse_lut_line(
    line::AbstractString;
    expected_length::Integer = 256,
    max_value::Integer = 255,
)
    vals = Int[]
    for m in eachmatch(r"0x[0-9a-fA-F]+|\d+", line)
        token = m.match
        value = startswith(lowercase(token), "0x") ? parse(Int, token[3:end]; base = 16) :
                parse(Int, token)
        push!(vals, value)
    end
    length(vals) == Int(expected_length) || throw(
        ArgumentError("expected $(Int(expected_length)) LUT values, got $(length(vals))"),
    )
    all(0 .<= vals .<= Int(max_value)) || throw(ArgumentError("LUT value outside expected range"))
    vals
end

"Validate one parsed LUT as a quadratic APN function."
function validate_lut_sample(vals::AbstractVector{<:Integer}; nbits::Integer = 8, check_ortho::Bool = false)
    n = Int(nbits)
    F = SBox{n}(vals)
    degree = algebraic_degree(F)
    du = differential_uniformity(F)
    ortho_ok = check_ortho ? (is_quadratic_apn(F) && apn_ea_mugshot(F).kind == :quadratic) : nothing
    (;
        n,
        degree,
        differential_uniformity = du,
        quadratic_apn = degree == 2 && du == 2,
        ortho_checked = check_ortho,
        ortho_ok,
    )
end

"Stream at most sample_size LUT lines from a local dataset."
function dataset_sample(
    dataset_path::AbstractString = "";
    sample_size::Integer = 0,
    nbits::Integer = 8,
    check_ortho::Bool = false,
)
    path = resolved_dataset_path(dataset_path)
    requested = Int(sample_size)
    if !isfile(path)
        return (;
            available = false,
            path,
            requested,
            checked = 0,
            all_quadratic_apn = false,
            samples = NamedTuple[],
            note = "dataset file not found; set BEIERLE2025_NEW_APNS_PATH or dataset_path",
        )
    end
    requested >= 0 || throw(ArgumentError("sample_size must be non-negative"))
    samples = NamedTuple[]
    checked = 0
    open(path, "r") do io
        while checked < requested && !eof(io)
            line = readline(io)
            isempty(strip(line)) && continue
            vals = parse_lut_line(
                line;
                expected_length = 1 << Int(nbits),
                max_value = (1 << Int(nbits)) - 1,
            )
            checked += 1
            push!(samples, validate_lut_sample(vals; nbits, check_ortho))
        end
    end
    (;
        available = true,
        path,
        requested,
        checked,
        all_quadratic_apn = all(s -> s.quadratic_apn, samples),
        samples,
        note = checked == requested ? "sample complete" : "file ended before requested sample size",
    )
end

"Count local dataset rows up to max_lines; default callers should keep this bounded."
function count_dataset_lines(dataset_path::AbstractString = ""; max_lines::Integer = 0)
    path = resolved_dataset_path(dataset_path)
    isfile(path) || return (; available = false, path, counted = 0, complete = false)
    limit = Int(max_lines)
    limit >= 0 || throw(ArgumentError("max_lines must be non-negative"))
    counted = 0
    complete = false
    open(path, "r") do io
        while !eof(io)
            readline(io)
            counted += 1
            if limit > 0 && counted >= limit
                return
            end
        end
        complete = true
    end
    (; available = true, path, counted, complete)
end

"Report Zenodo metadata and optional streamed sample validation."
function dataset_validation_report(
    io::IO = stdout;
    dataset_path::AbstractString = "",
    sample_size::Integer = 0,
    nbits::Integer = 8,
    check_ortho::Bool = false,
)
    print_section("Zenodo Dataset Validation", io)
    sample = dataset_sample(dataset_path; sample_size, nbits, check_ortho)
    print_kv("Zenodo record", ZENODO_RECORD, io)
    print_kv("file", ZENODO_FILE, io)
    print_kv("expected new classes", NEW_ZENODO_CLASSES, io)
    print_kv("reported md5", ZENODO_FILE_MD5, io)
    print_kv("local path", sample.path, io)
    if sample.available
        print_check("local dataset file available", true, io)
    else
        print_kv("local dataset file available", "no (optional unless sample_size>0)", io)
    end
    if sample.requested == 0
        print_kv("sample validation", "not requested (sample_size=0)", io)
    else
        print_check("local dataset file available for requested sample", sample.available, io)
        print_check("requested sample lines were read", sample.checked == sample.requested, io)
        print_check("all sampled LUTs are quadratic APN", sample.all_quadratic_apn, io)
        print_kv("sampled LUTs", sample.checked, io)
        print_kv("ortho derivative checked", check_ortho, io)
    end
    print_kv("completeness", "metadata exact; sample validation is bounded and streamed", io)
    sample
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    dataset_validation_report(; sample_size = 0)
end
