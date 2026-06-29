# Phase-1 tests for the n/class-generic V_A machinery (va_generic.jl).
include(joinpath(@__DIR__, "..", "va_generic.jl"))
using .VAGeneric

@testset "va_generic" begin
    @testset "dim(V_A) feasibility map" begin
        # values cross-checked against the full survey (survey.jl)
        @test va_dim(8, 22) == 40   # paper's class
        @test va_dim(8, 13) == 32
        @test va_dim(8, 14) == 24
        @test va_dim(8, 16) == 24
        @test va_dim(8, 1)  == 8
        @test va_dim(7, 16) == 31
        @test va_dim(7, 22) == 49
        @test va_dim(7, 23) == 45
    end

    @testset "basis-bin determinism + size" begin
        mktempdir() do d
            p1 = joinpath(d, "a.bin"); p2 = joinpath(d, "b.bin")
            nf = write_rows_bin(p1, 8, 22)
            write_rows_bin(p2, 8, 22)
            @test nf == 40
            @test read(p1) == read(p2)                 # deterministic
            @test filesize(p1) == nf * 8 * 8           # n_free × n UInt64
            nl = write_lut_bin(joinpath(d, "l.bin"), 8, 22)
            @test nl == 40
            @test filesize(joinpath(d, "l.bin")) == nf * (256 ÷ 8) * 8
        end
    end

    @testset "row-form ↔ LUT consistency" begin
        # bilinear row i, byte j must equal F(e_i ⊕ e_j) from the function's LUT
        p = VAGeneric.va_parameterize(8, 22)
        for bi in (1, 7, 40)
            lut = va_basis_lut(bi, p)
            bv = falses(p.n_free); bv[bi] = true
            c = VAGeneric.apply_b(bv, p)
            for i in 0:7, j in 0:7
                i == j && continue
                val = 0
                for k in 0:7
                    c[VAGeneric.col_idx(min(i,j), max(i,j), k, 8) + 1] && (val |= 1 << k)
                end
                @test val == lut[(1 << i) | (1 << j) + 1]
            end
        end
    end

    @testset "small class exhaustion (n=8 class 1, dim 8)" begin
        p = VAGeneric.va_parameterize(8, 1)
        @test p.n_free == 8
        apn = 0; total = 0
        for code in 0:(2^p.n_free - 1)
            bv = falses(p.n_free)
            for k in 1:p.n_free; ((code >> (k-1)) & 1 == 1) && (bv[k] = true); end
            lut = quadratic_lut_n(VAGeneric.apply_b(bv, p), 8)
            F = SBox{8}(lut)
            @test algebraic_degree(F) <= 2            # genuine quadratic
            differential_uniformity(F) == 2 && (apn += 1)
            total += 1
        end
        @test total == 256
        # deterministic, reproducible census of this subspace
        @test apn == count(begin
            bv = falses(p.n_free)
            for k in 1:p.n_free; ((code >> (k-1)) & 1 == 1) && (bv[k] = true); end
            differential_uniformity(SBox{8}(quadratic_lut_n(VAGeneric.apply_b(bv, p), 8))) == 2
        end for code in 0:255)
    end
end
