include(joinpath(@__DIR__, "..", "orbit_certificate.jl"))

# Independent dense Boolean elimination: deliberately does not call VBF rank.
function orbit_control_rank(vectors, n)
    matrix = [isodd(v >> j) for v in vectors, j in 0:n-1]
    r = 0
    for j in 1:n
        pivot = findfirst(i -> matrix[i,j], r+1:size(matrix,1))
        pivot === nothing && continue
        i = r + pivot
        r += 1
        matrix[r,:], matrix[i,:] = copy(matrix[i,:]), copy(matrix[r,:])
        for i in r+1:size(matrix,1)
            matrix[i,j] && (matrix[i,:] .⊻= matrix[r,:])
        end
    end
    r
end

@testset "Finite binomial coefficient-orbit certification" begin
    F = bracken_binomial(10,2; allow_nonpermutation=false)
    plan = binomial_orbit_plan(F)
    @test plan.field_irreducibility_verified
    @test plan.alpha == 2 && plan.alpha_order == (1 << 30)-1
    @test plan.derivative_gcd == plan.component_gcd == 21483
    @test plan.coefficient_count == plan.generator_order == 49981
    @test plan.component_base_exponent % 21483 == plan.derivative_base_exponent == 1023
    @test plan.multiplicity_per_coefficient * plan.coefficient_count == plan.group_order
    @test_throws ArgumentError binomial_orbit_plan(BrackenBinomial(
        F.k,F.s,F.n,F.t,(1<<30)+1,F.e1,F.e2,F.c1,F.c2))
    @test_throws ArgumentError binomial_orbit_plan(BrackenBinomial(
        F.k,F.s,F.n,F.t,F.modulus,F.e1,F.e2,1,F.c2))
    @test_throws ArgumentError binomial_orbit_plan(BrackenBinomial(
        F.k,F.s,F.n,F.t,F.modulus,F.e1,F.e2,F.c1,F.c2⊻1))
    @test_throws ArgumentError binomial_orbit_plan(bracken_binomial(4,5))

    short = binomial_orbit_certificate(F; max_coefficients=8,timeout_seconds=30)
    @test length(short.rows)==8 && short.summary["status"]=="inconclusive"
    @test !short.summary["coverage_complete"] && !short.summary["permutation_verified"]
    @test !short.summary["differential_uniformity_verified"] && !short.summary["walsh_bound_verified"]
    @test short.summary["derivative_ranks"]==short.summary["polar_ranks"]==[28]
    @test short.summary["collision_rhs_outside_image"]==8
    for kwargs in ((max_coefficients=0,), (timeout_seconds=0,))
        stopped = binomial_orbit_certificate(F; kwargs...)
        @test isempty(stopped.rows) && stopped.summary["status"]=="inconclusive"
    end
    @test_throws ArgumentError binomial_orbit_certificate(F;max_coefficients=-1)
    @test_throws ArgumentError binomial_orbit_certificate(F;timeout_seconds=Inf)

    # Full small orbits; original domains explicitly enumerated to check that
    # the power-image argument neither loses nor adds a coefficient.
    for (k,s) in ((1,2),(2,4),(5,1))
        Fs = bracken_binomial(k,s; allow_nonpermutation=false)
        p = binomial_orbit_plan(Fs)
        n, m, N = Fs.n, Fs.modulus, p.group_order
        evidence = binomial_orbit_certificate(Fs;
            max_coefficients=p.coefficient_count,timeout_seconds=30)
        @test evidence.summary["status"]=="certified"
        @test evidence.summary["coverage_complete"]
        coset = Set(row.coefficient for row in evidence.rows)
        derivative_set = Set(gf_mul(p.base,gf_pow(a,p.derivative_exponent,n;modulus=m),n;modulus=m) for a in 1:N)
        component_base = gf_pow(Fs.c1,p.component_base_exponent,n;modulus=m)
        component_set = Set(gf_mul(component_base,gf_pow(b,p.component_exponent,n;modulus=m),n;modulus=m) for b in 1:N)
        @test derivative_set==component_set==coset

        data = orbit_linear_data(Fs)
        differences = n<=6 ? collect(1:N) : [1,2,3,17,257,N]
        points = n<=6 ? collect(0:N) : [0; [1<<j for j in 0:n-1]; 3; 11; N]
        for a in differences
            scale = gf_mul(Fs.c1,gf_pow(a,Fs.e1,n;modulus=m),n;modulus=m)
            invscale = gf_pow(scale,N-1,n;modulus=m)
            c = gf_mul(p.base,gf_pow(a,p.derivative_exponent,n;modulus=m),n;modulus=m)
            matrices = orbit_case_matrices(Fs,data,c)
            @test orbit_control_rank(matrices.columns,n)==n-Fs.t
            @test orbit_control_rank(vcat(matrices.columns,UInt64(1⊻c)),n)==n-Fs.t+1
            literal_columns = [Fs((1<<j)⊻a)⊻Fs(1<<j)⊻Fs(a)⊻Fs(0) for j in 0:n-1]
            @test orbit_control_rank(literal_columns,n)==n-Fs.t
            for y in points
                x = gf_mul(a,y,n;modulus=m)
                normalized = gf_mul(Fs(x⊻a)⊻Fs(x)⊻Fs(a)⊻Fs(0),invscale,n;modulus=m)
                expected = gf_pow(y,1<<s,n;modulus=m)⊻y⊻gf_mul(c,
                    gf_pow(y,1<<(2k),n;modulus=m)⊻gf_pow(y,1<<((k+s)%n),n;modulus=m),n;modulus=m)
                @test normalized==expected
            end
        end
        masks = differences
        for b in masks
            u = gf_pow(gf_mul(b,Fs.c1,n;modulus=m),mod(-p.e1_inverse,N),n;modulus=m)
            c = gf_mul(gf_mul(b,Fs.c2,n;modulus=m),gf_pow(u,Fs.e2,n;modulus=m),n;modulus=m)
            @test c in coset
            q(y) = gf_trace(gf_mul(b,Fs(gf_mul(u,y,n;modulus=m)),n;modulus=m),n;modulus=m)
            for y in points
                @test q(y)==gf_trace(gf_pow(y,Fs.e1,n;modulus=m)⊻
                    gf_mul(c,gf_pow(y,Fs.e2,n;modulus=m),n;modulus=m),n;modulus=m)
            end
            # Literal component polarization has no precomputed monomial helpers.
            rows = UInt64[sum(UInt64(q((1<<i)⊻(1<<j))⊻q(1<<i)⊻q(1<<j)⊻q(0))<<j
                for j in 0:n-1) for i in 0:n-1]
            @test rows==orbit_case_matrices(Fs,data,c).polar
            @test orbit_control_rank(rows,n)==n-Fs.t
        end
        if n<=6
            lut = [Fs(x) for x in 0:N]
            @test length(unique(lut))==1<<n
            # Independent literal DDT and Walsh sums over all differences/masks.
            ddt_values = Set{Int}()
            for a in 1:N
                counts=zeros(Int,N+1)
                for x in 0:N; counts[(lut[(x⊻a)+1]⊻lut[x+1])+1]+=1; end
                union!(ddt_values,counts)
            end
            @test ddt_values==Set([0,1<<Fs.t])
            magnitudes=Set{Int}()
            for b in 1:N, a in 0:N
                w=sum(isodd(count_ones(a&x)+count_ones(b&lut[x+1])) ? -1 : 1 for x in 0:N)
                w!=0 && push!(magnitudes,abs(w))
            end
            @test magnitudes==Set(evidence.summary["observed_normalized_walsh_magnitudes"])
        end
    end

    # An arbitrary coefficient outside the source coset provides a negative
    # collision control: RHS zero is always in the image for c=1.
    matrices=orbit_case_matrices(F,orbit_linear_data(F),1)
    @test rank_f2(vcat(matrices.columns,UInt64(0));nbits=30)==rank_f2(matrices.columns;nbits=30)

    mktempdir() do dir
        output=joinpath(dir,"evidence")
        saved=binomial_orbit_certificate(bracken_binomial(2,4);
            max_coefficients=1,output_directory=output)
        parsed=TOML.parsefile(joinpath(output,"certificate.toml"))
        @test parsed["status"]=="certified" && parsed["coverage_complete"]
        @test parsed["coefficients_checked"]==1
        @test parsed["coefficients_csv_sha256"]==bytes2hex(open(SHA.sha256,joinpath(output,"coefficients.csv")))
        @test !isempty(parsed["source_sha256"])
        @test length(readlines(joinpath(output,"coefficients.csv")))==2
        @test_throws ArgumentError binomial_orbit_certificate(F;output_directory=output)
    end
end
