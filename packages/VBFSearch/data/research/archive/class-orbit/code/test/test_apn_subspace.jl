# search/test/test_apn_subspace.jl
#
# Validates the Phase 2-4 engine against VBF's own machinery BEFORE it is
# trusted to decide anything. The fast quadratic APN test must agree with
# differential_uniformity on known APN and known non-APN functions, and the
# coefficient <-> LUT round trip must be exact.
#
# Run: julia --project=. search/test/test_apn_subspace.jl

using Test
include(joinpath(@__DIR__, "..", "apn_subspace.jl"))

# Gold x^{2^k+1} over GF(2^8), as a homogeneous quadratic.
gold_lut(k::Int; modulus = primitive_polynomial(8)) =
    [gf_pow(x, (1 << k) + 1, 8; modulus = modulus) for x = 0:255]

@testset "apn_subspace engine" begin

    # x^{2^k+1} = x^{2^k} · x is a product of two F_2-linear forms, and the
    # diagonal terms a_i b_i x_i^2 = a_i b_i x_i are LINEAR. So Gold is not a
    # homogeneous quadratic: the round trip recovers it only up to an F_2-linear
    # map. That is exactly the right notion here — F and its homogeneous part
    # differ by an affine map, hence are EA-equivalent, hence equi-APN, so
    # searching homogeneous quadratics loses no EA-class.
    @testset "coeffs -> lut recovers Gold up to an F_2-linear map" begin
        for k in (1, 3)
            lut = gold_lut(k)
            h = coeffs_to_lut(lut_to_coeffs(lut))
            d = [h[x+1] ⊻ lut[x+1] for x = 0:255]
            @test d[1] == 0                                   # no constant term
            @test all(d[(x⊻y)+1] == d[x+1] ⊻ d[y+1] for x = 0:255, y = 0:255)
            # and the homogeneous part is APN exactly when the original is
            @test is_apn_reference(h) == is_apn_reference(lut)
        end
    end

    @testset "coeffs <-> lut round trip IS exact on homogeneous quadratics" begin
        for seed = 1:6
            c = falses(NCOEF)
            s = seed * 2654435761 % 4294967296
            for i = 1:NCOEF
                s = (1103515245 * s + 12345) % 2147483648
                c[i] = (s >> 16) & 1 == 1
            end
            @test lut_to_coeffs(coeffs_to_lut(c)) == c
        end
    end

    @testset "the fast APN test agrees with differential_uniformity" begin
        # Gold x^{2^k+1} is APN over GF(2^8) exactly when gcd(k,8) = 1, i.e. k odd.
        for k = 1:7
            lut = gold_lut(k)
            c = lut_to_coeffs(lut)
            la = UInt64[la_of_coeffs(c, a) for a = 1:255]
            fast = is_apn_from_la(la)
            slow = is_apn_reference(lut)
            @test fast == slow
            @test fast == (gcd(k, 8) == 1)
        end
    end

    @testset "the fast APN test rejects non-APN quadratics" begin
        # x^3 + x^5 is generally not APN over GF(2^8); whatever it is, the two
        # code paths must agree. Same for a handful of random quadratics.
        mod8 = primitive_polynomial(8)
        mixed = [gf_pow(x, 3, 8; modulus = mod8) ⊻ gf_pow(x, 5, 8; modulus = mod8) for x = 0:255]
        c = lut_to_coeffs(mixed)
        # the polarisation B kills linear terms, so the fast test on the
        # quadratic part decides APN-ness of the full function
        la = UInt64[la_of_coeffs(c, a) for a = 1:255]
        @test is_apn_from_la(la) == is_apn_reference(mixed)

        n_agree = 0
        for seed = 1:40
            cc = falses(NCOEF)
            s = seed * 2654435761 % 4294967296
            for i = 1:NCOEF
                s = (1103515245 * s + 12345) % 2147483648
                cc[i] = (s >> 16) & 1 == 1
            end
            lut = coeffs_to_lut(cc)
            la = UInt64[la_of_coeffs(cc, a) for a = 1:255]
            is_apn_from_la(la) == is_apn_reference(lut) && (n_agree += 1)
        end
        @test n_agree == 40
    end

    @testset "rank8 matches a naive F_2 rank" begin
        # Independent Gaussian elimination over the 8 byte-columns.
        function naive_rank(m::UInt64)
            cols = [UInt8((m >> (8 * j)) & 0xff) for j = 0:7]
            piv = zeros(UInt8, 8)
            r = 0
            for v0 in cols
                v = v0
                while v != 0
                    b = trailing_zeros(v) + 1
                    if piv[b] == 0
                        piv[b] = v
                        r += 1
                        break
                    end
                    v ⊻= piv[b]
                end
            end
            r
        end
        s = UInt64(0x243F6A8885A308D3)
        for t = 1:2000
            s = s * 6364136223846793005 + 1442695040888963407
            @test rank8(s) == naive_rank(s)
        end
        @test rank8(UInt64(0)) == 0
        @test rank8(UInt64(0x8040201008040201)) == 8   # identity: 8 independent columns
    end

    @testset "Gold x^3 and x^9 lie in the Frobenius commutant" begin
        # Squaring on GF(2^8) as an F_2-linear map.
        mod8 = primitive_polynomial(8)
        frob = falses(8, 8)
        for j = 0:7
            img = gf_pow(1 << j, 2, 8; modulus = mod8)
            for k = 0:7
                ((img >> k) & 1) == 1 && (frob[k+1, j+1] = true)
            end
        end
        A = Matrix{Bool}(frob)
        M = build_M_A(A)
        for k in (1, 3)
            c = lut_to_coeffs(gold_lut(k))
            @test in_kernel(M, c)          # x^{2^k+1} commutes with squaring
        end
        kb = kernel_basis(A)
        @test kb.dim + kb.rank == NCOEF
        @test kb.dim > 0
        # every basis vector really is in the kernel
        @test all(in_kernel(M, v) for v in kb.basis)
    end
end
