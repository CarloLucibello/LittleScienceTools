__precompile__()
module Random
using Compat #xor
export ParisiRapuano, randperm!, getRNG

using Base.Random
import Base: rand, srand

include("parisi_rapuano.jl")
include("random.jl")
end #submodule