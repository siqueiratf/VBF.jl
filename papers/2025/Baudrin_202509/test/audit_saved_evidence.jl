# Standalone independent audit of completed six-bit saved experiment evidence.
# Usage: julia --project=. audit_saved_evidence.jl SECTION32.toml [SWITCHING.toml]
# No VBF map, invariant or equivalence implementation is called here.
using Test
using TOML
using SHA
isdefined(@__MODULE__,:bgp_test_certificate) || include("certificate_oracle.jl")

function bgp_test_degree(lut)
    size = length(lut)
    n = trailing_zeros(size)
    degree = 0
    for output_bit in 0:(n-1)
        coefficients = [(value >> output_bit) & 1 for value in lut]
        for bit in 0:(n-1), x in 0:(size-1)
            x & (1 << bit) == 0 && continue
            coefficients[x+1] ⊻= coefficients[(x ⊻ (1 << bit))+1]
        end
        degree = max(degree,maximum(count_ones(x) for x in 0:(size-1)
            if coefficients[x+1] != 0;init=0))
    end
    return degree
end

function bgp_test_ddt_spectrum(lut)
    size = length(lut)
    spectrum = Dict{Int,Int}()
    for a in 0:(size-1)
        counts = zeros(Int,size)
        for x in 0:(size-1)
            counts[(lut[x+1] ⊻ lut[(x ⊻ a)+1])+1] += 1
        end
        for count in counts
            spectrum[count] = get(spectrum,count,0)+1
        end
    end
    return spectrum
end

function bgp_test_apn(lut)
    size = length(lut)
    for a in 1:(size-1)
        counts = zeros(Int,size)
        for x in 0:(size-1)
            value = (lut[x+1] ⊻ lut[(x ⊻ a)+1])+1
            counts[value] += 1
            counts[value] > 2 && return false
        end
    end
    return true
end

function bgp_test_walsh_spectrum(lut; absolute=false)
    size = length(lut)
    spectrum = Dict{Int,Int}()
    for a in 0:(size-1), b in 0:(size-1)
        value = sum(isodd(count_ones(a & x)+count_ones(b & lut[x+1])) ? -1 : 1
            for x in 0:(size-1))
        absolute && (value = abs(value))
        spectrum[value] = get(spectrum,value,0)+1
    end
    return spectrum
end

function bgp_test_ortho_derivative(lut)
    size = length(lut)
    output = zeros(Int,size)
    for a in 1:(size-1)
        derivatives = unique([lut[x+1] ⊻ lut[(x ⊻ a)+1] ⊻ lut[1] ⊻ lut[a+1]
            for x in 0:(size-1)])
        normals = [b for b in 1:(size-1)
            if all(v -> iseven(count_ones(b & v)),derivatives)]
        length(normals) == 1 || error("quadratic derivative is not a hyperplane")
        output[a+1] = only(normals)
    end
    return output
end

function bgp_test_saved_census(path)
    data = TOML.parsefile(path)
    invariant_proofs = Ref(0)
    recorded_exhaustions = Ref(0)
    @testset "saved six-bit census independent audit" begin
        @test data["census_complete"] === true
        @test data["roots_distinct"] === true
        @test data["legacy_crosschecks_complete"] === true
        @test data["quadratic_classes"] == 691
        @test data["nonquadratic_classes"] == 25
        @test data["degree_counts"] == Dict("2"=>13,"3"=>521,"4"=>182)
        @test data["conjecture_proved"] === false
        @test length(data["rows"]) == length(data["dataset"]) == 14
        @test all(row -> row["complete"],data["rows"])
        @test sum(row["classes"] for row in data["rows"]) == 716
        roots = Dict(row["label"] => row["lut"] for row in data["dataset"])
        for row in data["dataset"]
            @test bytes2hex(sha256(UInt8.(row["lut"]))) == row["lut_sha256"]
            @test bgp_test_apn(row["lut"])
        end
        witnesses = data["witnesses"]
        @test length(witnesses) == 716
        @test length(Set(Tuple(record["target_lut"]) for record in witnesses)) == 716
        for row in data["rows"]
            matching = filter(record -> record["source_label"] == row["label"],witnesses)
            @test length(matching) == row["classes"]
            @test sort([record["target_index"] for record in matching]) == 1:row["classes"]
        end
        degrees = Dict{Int,Int}()
        for record in witnesses
            @test bgp_test_certificate(record)
            @test record["source_lut"] == roots[record["source_label"]]
            @test bgp_test_apn(record["target_lut"])
            degree = bgp_test_degree(record["target_lut"])
            degrees[degree] = get(degrees,degree,0)+1
        end
        @test degrees == Dict(2=>13,3=>521,4=>182)
        quadratic = Dict{String,Any}()
        absolute_walsh = Dict{String,Any}()
        for (label,lut) in roots
            absolute_walsh[label] = bgp_test_walsh_spectrum(lut;absolute=true)
            if bgp_test_degree(lut) == 2
                ortho = bgp_test_ortho_derivative(lut)
                quadratic[label] = (bgp_test_walsh_spectrum(ortho),
                    bgp_test_ddt_spectrum(ortho))
            end
        end
        @test length(quadratic) == 13
        checks = data["root_distinctness_checks"]
        @test length(checks) == 91
        pairs = Set{Tuple{String,String}}()
        for check in checks
            @test check["outcome"] == "inequivalent"
            first,second = check["first"],check["second"]
            @test first != second && haskey(roots,first) && haskey(roots,second)
            pair = Tuple(sort([first,second]))
            @test !(pair in pairs)
            push!(pairs,pair)
            proof = check["proof"]
            if occursin("ortho-derivative",proof)
                @test quadratic[first] != quadratic[second]
                invariant_proofs[] += 1
            elseif occursin("Walsh-spectrum",proof)
                @test absolute_walsh[first] != absolute_walsh[second]
                invariant_proofs[] += 1
            else
                # These records can be checked structurally; a negative
                # certificate cannot be reconstructed from a node count.
                # Their mathematical conclusion relies on the separately
                # validated exhaustive native solver, not this raw oracle.
                @test proof == "native CCZ search exhausted"
                @test check["nodes"] isa Integer && check["nodes"] >= 0
                recorded_exhaustions[] += 1
            end
        end
        @test length(pairs) == 91
    end
    println("Independently verified invariant rejections: $(invariant_proofs[]); " *
        "recorded native exhaustions (not independently replayed): $(recorded_exhaustions[])")
    return data
end

function bgp_test_saved_switching(path)
    data = TOML.parsefile(path)
    @testset "saved six-bit switching independent audit" begin
        @test data["parameters"]["dimension"] == 6
        @test data["conjecture_proved"] === false
        @test data["finite_region_complete"] === false
        @test all(bgp_test_certificate,data["witnesses"])
        for record in data["records"]
            parent,candidate = record["parent_lut"],record["candidate_lut"]
            direction = record["switching_direction"]
            support = Set(record["switching_support"])
            @test all(x -> candidate[x+1] ==
                (parent[x+1] ⊻ (x in support ? direction : 0)),0:63)
            @test bgp_test_apn(candidate)
        end
    end
    roots = [findfirst(==(root),data["reference_seeds"])
        for root in data["initial_roots"]]
    parents = [row["class_index"] for row in data["frontier"] if row["processed"]]
    println("Initial root indices: $(roots); expanded parent classes: $(parents)")
    return data
end

if abspath(PROGRAM_FILE) == @__FILE__
    1 <= length(ARGS) <= 2 || error("supply SECTION32.toml and optional SWITCHING.toml")
    bgp_test_saved_census(ARGS[1])
    length(ARGS) == 2 && bgp_test_saved_switching(ARGS[2])
end
