@testset "dataset_validation_test" begin
    include(joinpath(@__DIR__, "..", "dataset_validation.jl"))

    # parse_lut_line: brace-wrapped and trailing-comma variants
    @test parse_lut_line("{0, 1, 2, 3}") == [0, 1, 2, 3]
    @test parse_lut_line("{0, 1, 2, 3},") == [0, 1, 2, 3]

    # parse_lut_line: a dim-9 line must parse to exactly 512 entries
    n9_line = "{" * join(0:511, ", ") * "}"
    @test length(parse_lut_line(n9_line)) == 512

    # The dataset .txt files are large and git-ignored (`*.txt`); a fresh
    # checkout will not have them. Skip the file-dependent checks when absent.
    inputs_dir = joinpath(@__DIR__, "..", "inputs")
    if all(f -> isfile(joinpath(inputs_dir, f)), ("apn_8bit.txt", "apn_9bit.txt", "apn_10bit.txt"))
        # stream_dataset: correct count for the small files
        n9 = 0
        for _ in stream_dataset(joinpath(inputs_dir, "apn_9bit.txt"))
            n9 += 1
        end
        @test n9 == 35

        n10 = 0
        for _ in stream_dataset(joinpath(inputs_dir, "apn_10bit.txt"))
            n10 += 1
        end
        @test n10 == 5

        # stream_dataset: verify each line in apn_9bit.txt has exactly 512 entries
        for f in stream_dataset(joinpath(inputs_dir, "apn_9bit.txt"))
            @test length(f.lut) == 512
        end

        # stream_dataset: verify each line in apn_10bit.txt has exactly 1024 entries
        for f in stream_dataset(joinpath(inputs_dir, "apn_10bit.txt"))
            @test length(f.lut) == 1024
        end

        # dataset_counts: all three files pass with exact expected counts
        r = dataset_counts(devnull)
        @test r.all_ok
        # Exact counts from EXPERIMENTS.md (headline results of the paper)
        @test r.results[1].count == 12921  # apn_8bit.txt: n=8
        @test r.results[2].count == 35     # apn_9bit.txt: n=9
        @test r.results[3].count == 5      # apn_10bit.txt: n=10

        # verify_apn: exhaustive for n=9 and n=10, sampled for n=8
        r_apn = verify_apn(devnull; sample_size = 5, full_search = false)
        @test r_apn.all_ok

        # verify_quadratic: exhaustive for n=9 and n=10
        r_quad = verify_quadratic(devnull; sample_size = 5, full_search = false)
        @test r_quad.all_ok
    else
        @test_skip "dataset files absent (packages/VBFRepro/papers/Beierle_202201/inputs/*.txt)"
    end
end
