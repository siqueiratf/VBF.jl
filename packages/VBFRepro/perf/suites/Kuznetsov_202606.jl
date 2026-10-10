# Historical calibration workloads retain the original mathematical fixtures.
module PerfKuznetsovCalibration
using VBF
const PAPER_DIR=normpath(joinpath(@__DIR__, "..", "..", "src", "202606-kuznetsov-groebner-search"))
include(joinpath(PAPER_DIR,"helpers.jl"))
include(joinpath(PAPER_DIR,"phase2.jl"))
const SINGLE = UInt8[0,0,0,128,0,80,240,32,0,144,160,176,16,208,64,0,0,168,210,250,111,151,77,53,212,236,166,30,171,195,41,193,
  0,114,191,77,84,118,27,185,193,35,222,188,133,55,106,88,128,90,237,183,187,49,38,44,149,223,88,146,190,164,131,25,
  0,175,228,203,145,110,133,250,168,151,236,83,41,70,157,114,80,87,102,225,174,249,104,191,44,187,186,173,194,5,164,227,
  240,45,171,246,53,184,158,147,153,212,98,175,76,81,71,218,32,85,169,92,138,175,243,86,157,120,180,209,39,146,254,203,
  0,228,177,213,56,140,121,77,210,166,195,55,250,222,27,191,144,220,243,63,199,219,84,200,150,74,85,9,209,93,226,238,
  160,54,174,184,204,10,50,116,179,181,29,155,207,153,145,71,176,142,108,210,179,221,159,113,119,217,11,37,100,154,232,150,
  16,91,69,142,185,162,28,135,106,177,159,196,211,88,214,221,208,51,87,52,22,165,97,82,126,13,89,170,168,139,127,220,
  64,121,170,19,189,212,167,78,251,82,177,152,22,239,172,213,0,145,56,41,146,83,90,27,111,110,247,118,237,188,133,84]
end
function register!(reg)
    P=PerfKuznetsovCalibration
    benchmark!(reg;group="papers",name="Kuznetsov_202606_kernel",n=8,
        paper_id="202606-kuznetsov-groebner-search",mode="paper_specific",approach="self-equivalence kernel",
        setup=P.build_A_matrix,call=P.fc22_sol22,
        validate=(p,v)->(@assert length(v.pivot_cols)==184 && length(v.free_cols)==40),
        note="224-coefficient linear constraints; historical rank 184, dimension 40")
    benchmark!(reg;group="papers",name="Kuznetsov_202606_groebner_slice",n=8,cost=3,samples=3,
        paper_id="202606-kuznetsov-groebner-search",mode="paper_specific",approach="Groebner NL=4 slice",
        setup=()->copy(P.SINGLE),call=P.phase2_slice,
        validate=(p,v)->(@assert length(v)==1 && only(v).lut==p),
        parameters=(;variables=24,verify=true),
        note="historical one-solution GF(2) msolve fixture; includes APN filter")
end
