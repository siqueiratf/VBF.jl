#=
Independently replay the full n30 coefficient-orbit certificate using Julia
stdlib integer polynomial arithmetic. No VBF finite-field or rank routines.
Run `julia test/verify_certificate.jl results/orbit-.../coefficients.csv`.
=#
using SHA, TOML, Random

const N_BITS = 30
const MODULUS = 1073741907
const FIELD_ORDER = (1 << N_BITS) - 1

function multiply(a, b)
    z = 0
    while b != 0
        isodd(b) && (z ⊻= a)
        b >>= 1
        a <<= 1
        a >> N_BITS != 0 && (a ⊻= MODULUS)
    end
    z
end

function field_power(a, exponent)
    @assert exponent >= 0
    z = 1
    while exponent != 0
        isodd(exponent) && (z = multiply(z, a))
        a = multiply(a, a)
        exponent >>= 1
    end
    z
end

degree(x) = 8sizeof(x) - leading_zeros(x) - 1
function polynomial_remainder(a, b)
    while a != 0 && degree(a) >= degree(b)
        a ⊻= b << (degree(a)-degree(b))
    end
    a
end
function polynomial_gcd(a, b)
    while b != 0
        a, b = b, polynomial_remainder(a, b)
    end
    a
end
function binary_rank(columns)
    pivots = Dict{Int,Int}()
    for column in columns
        x = column
        while x != 0
            j = degree(x)
            if haskey(pivots, j)
                x ⊻= pivots[j]
            else
                pivots[j] = x
                break
            end
        end
    end
    length(pivots)
end
function absolute_trace(x)
    z = 0
    for _ in 1:N_BITS
        z ⊻= x
        x = multiply(x, x)
    end
    @assert z in (0, 1)
    z
end

"""Check the fixed field, orbit coverage, literal normalization and every CSV rank."""
function verify_certificate(path)
    started = time_ns()
    @assert degree(MODULUS) == N_BITS
    for p in (2, 3, 5)
        @assert polynomial_gcd(field_power(2, 1 << (N_BITS ÷ p)) ⊻ 2, MODULUS) == 1
    end
    @assert field_power(2, 1 << N_BITS) == 2
    @assert field_power(2, FIELD_ORDER) == 1
    for p in (3, 7, 11, 31, 151, 331)
        @assert field_power(2, FIELD_ORDER ÷ p) != 1
    end
    basis = [1 << j for j in 0:N_BITS-1]
    trace_mask = sum(absolute_trace(x) << (j-1) for (j,x) in enumerate(basis))
    tr(x) = count_ones(x & trace_mask) & 1
    e1, e2 = 5, (1 << 20) + (1 << 12)
    g = gcd(e2-e1, FIELD_ORDER)
    count = FIELD_ORDER ÷ g
    @assert (g, count) == (21483, 49981)
    inverse = invmod(5, FIELD_ORDER)
    @assert gcd(1-e2*inverse, FIELD_ORDER) == g
    @assert mod(1024-e2*inverse,g) == mod(1023,g)
    base, generator = field_power(2,1023), field_power(2,g)
    @assert field_power(generator,count) == 1
    for p in (151,331)
        @assert field_power(generator,count ÷ p) != 1
    end
    seen, c = Set{Int}(), base
    for _ in 1:count
        @assert c ∉ seen
        push!(seen,c)
        c = multiply(c,generator)
    end
    @assert c == base && length(seen) == count && 1 ∉ seen
    F(x) = multiply(2,field_power(x,e1)) ⊻ multiply(field_power(2,1024),field_power(x,e2))
    L(c,x) = field_power(x,4) ⊻ x ⊻ multiply(c,field_power(x,1 << 20) ⊻ field_power(x,1 << 12))
    Q(c,x) = tr(field_power(x,5) ⊻ multiply(c,field_power(x,e2)))
    rng = MersenneTwister(20261010)
    for a in vcat([1,2],rand(rng,1:FIELD_ORDER,6))
        c = multiply(base,field_power(a,e2-e1))
        @assert c ∈ seen
        scale = multiply(2,field_power(a,5))
        for y in vcat(basis,[0,1,rand(rng,0:FIELD_ORDER)])
            x = multiply(a,y)
            @assert F(x ⊻ a) ⊻ F(x) ⊻ F(a) == multiply(scale,L(c,y))
        end
        columns = [L(c,y) for y in basis]
        @assert binary_rank(columns) == 28 && binary_rank(vcat(columns,[1 ⊻ c])) == 29
    end
    for b in vcat([1,2],rand(rng,1:FIELD_ORDER,6))
        u = field_power(multiply(b,2),mod(-inverse,FIELD_ORDER))
        c = multiply(multiply(b,field_power(2,1024)),field_power(u,e2))
        @assert c ∈ seen
        for y in vcat(basis,[0,1,rand(rng,0:FIELD_ORDER)])
            @assert tr(multiply(b,F(multiply(u,y)))) == Q(c,y)
        end
        qb = [Q(c,x) for x in basis]
        polar = [sum((Q(c,x ⊻ y) ⊻ qb[i] ⊻ qb[j]) << (j-1) for (j,y) in enumerate(basis)) for (i,x) in enumerate(basis)]
        @assert binary_rank(polar) in (28,30)
    end
    d1 = [field_power(x,4) ⊻ x for x in basis]
    d2 = [field_power(x,1 << 20) ⊻ field_power(x,1 << 12) for x in basis]
    q1, q2 = [field_power(x,5) for x in basis], [field_power(x,e2) for x in basis]
    coefficients = Tuple{Int,Int,Int,Int}[]
    for (i,x) in enumerate(basis), j in i+1:N_BITS
        y = basis[j]
        a = field_power(x ⊻ y,5) ⊻ q1[i] ⊻ q1[j]
        b = field_power(x ⊻ y,e2) ⊻ q2[i] ⊻ q2[j]
        mask = sum(tr(multiply(z,b)) << (k-1) for (k,z) in enumerate(basis))
        push!(coefficients,(i,j,tr(a),mask))
    end
    checked, c = 0, base
    open(path) do io
        header = split(readline(io),',')
        positions = Dict(name=>i for (i,name) in enumerate(header))
        for line in eachline(io)
            row = parse.(Int,split(line,','))
            value(name) = row[positions[name]]
            checked += 1
            @assert value("index") == checked && value("coefficient") == c
            columns = [d1[j] ⊻ multiply(c,d2[j]) for j in 1:N_BITS]
            @assert binary_rank(columns) == value("derivative_rank") == 28
            @assert binary_rank(vcat(columns,[1 ⊻ c])) == value("augmented_rank") == 29
            polar = zeros(Int,N_BITS)
            for (i,j,a,b) in coefficients
                if a ⊻ (count_ones(c & b) & 1) != 0
                    polar[i] |= 1 << (j-1)
                    polar[j] |= 1 << (i-1)
                end
            end
            @assert binary_rank(polar) == value("polar_rank") == 28
            c = multiply(c,generator)
        end
    end
    @assert checked == count && c == base
    Dict("implementation"=>"independent Julia stdlib polynomial arithmetic and literal polar trace masks",
        "n"=>N_BITS,"modulus"=>MODULUS,"coefficients_checked"=>checked,"coverage_complete"=>true,
        "derivative_rank"=>28,"augmented_rank"=>29,"polar_rank"=>28,"du4_certified"=>true,
        "permutation_certified"=>true,"walsh_support_inclusion_certified"=>true,
        "coefficients_csv"=>abspath(path),"coefficients_csv_sha256"=>open(io->bytes2hex(sha256(io)),path),
        "elapsed_seconds"=>(time_ns()-started)/1e9)
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("usage: julia verify_certificate.jl COEFFICIENTS.csv")
    TOML.print(stdout,verify_certificate(only(ARGS));sorted=true)
end
