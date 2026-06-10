@testset "extension criteria" begin
    gold4 = gold_apn(4, 1)
    zero4 = SBox{4}(zeros(Int, 16))

    @test !lemma46_filter(gold4).eliminated
    @test lemma46_filter(zero4).eliminated

    lg = lemma47_check(gold4)
    lz = lemma47_check(zero4)
    @test lg.exhaustive
    @test lz.exhaustive
    @test lg.agrees === true
    @test lz.agrees === true
    @test lg.witness === nothing
    @test lz.witness !== nothing

    t49 = theorem49_exhaustive_check()
    @test t49.total_linear_maps == 64
    @test t49.disagreements == 0
    @test t49.condition_true == t49.extension_apn
    @test t49.condition_true > 0
    @test t49.condition_true < t49.total_linear_maps
end
