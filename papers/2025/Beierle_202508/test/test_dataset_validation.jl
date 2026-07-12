@testset "dataset parser and bounded sample" begin
    F = gold_apn(4, 1)
    line = join(Int.(F.lut), " ")
    vals = parse_lut_line(line; expected_length = 16, max_value = 15)
    @test vals == Int.(F.lut)

    hexline = join(("0x" * string(v, base = 16) for v in Int.(F.lut)), ",")
    @test parse_lut_line(hexline; expected_length = 16, max_value = 15) == Int.(F.lut)

    path = tempname()
    open(path, "w") do io
        println(io, line)
    end
    sample = dataset_sample(path; sample_size = 1, nbits = 4)
    @test sample.available
    @test sample.checked == 1
    @test sample.all_quadratic_apn
end
