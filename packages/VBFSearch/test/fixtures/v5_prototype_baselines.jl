"""Pinned historical source for opt-in V5 prototype tests only.

The fixtures are never included as VBF modules. Prototypes extract and transform
specific functions under strict source guards, and tests compare mathematical
outputs and cursor semantics with the current VBF package.
"""
module V5PrototypeBaselines
using SHA,Test
const FIXTURES = (
    pre_du7=(file="v5-pre-du7.jl", sha256="b90eaee972f215f465b0ab590c5e28295a841baedcafa66b1ea7cd24a66cc3a1"),
    pre_stable_dense=(file="v5-pre-stable-dense.jl", sha256="0dc0e38da76a5d322227784917a3f792d25938115310121edbe9ba04b3fcc5e2"),
)
function environment(kind::Symbol)
    fixture=getproperty(FIXTURES,kind)
    source=joinpath(@__DIR__,fixture.file)
    bytes2hex(open(SHA.sha256,source)) == fixture.sha256 || error("prototype fixture SHA256 mismatch")
    if kind===:pre_du7
        return ("VBF_V5_BASELINE_SOURCE"=>source,"VBF_V5_BASELINE_SHA256"=>fixture.sha256,
                "VBF_V5_HISTOGRAM_SOURCE"=>source,"VBF_V5_HISTOGRAM_SHA256"=>fixture.sha256)
    elseif kind===:pre_stable_dense
        return ("VBF_ITERATOR_BASELINE"=>source,"VBF_ITERATOR_BASELINE_SHA256"=>fixture.sha256,
                "VBF_V5_HISTOGRAM_SOURCE"=>source,"VBF_V5_HISTOGRAM_SHA256"=>fixture.sha256)
    end
    error("unknown prototype fixture")
end

"Compare scientific outputs and coverage; candidate-work counters may differ."
function native_parity(reference,native)
    for field in (:Ss,:nX,:nX_used,:next_x,:du_reject,:nT,:key,:capped,:skipped)
        @test getproperty(reference,field)==getproperty(native,field)
    end
end
end
