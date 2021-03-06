__precompile__()
module Random
using Compat #xor
export ParisiRapuano, randperm!, getRNG,
        randchoice, randchoice!, randint,
        DiscreteDistribution

using Base.Random
import Base: rand, srand

include("parisi_rapuano.jl")
include("discrete_distribution.jl")

# Knuth shuffles (see Wikipedia)
"""
    randperm!([rng,] v::AbstractArray)

In-place random permutation of the elements of `v`.
"""
function randperm!(rng::AbstractRNG, v::AbstractArray)
    n = length(v)
    for i=1:n-1
        r = rand(rng, 0:n-i)
        v[i], v[i+r] = v[i+r], v[i]
    end
end

randperm!(v::AbstractArray) = randperm!(GLOBAL_RNG, v)


"""
randchoice!([rng,] a, k; exclude=nothing)

Sample `k` elements from array `a` without repetition and eventually excluding elements in `exclude`.
Pay attention, it has complecity `O(length(a))`, since it creates a copy of `a`
internally.
Use [`randchoice!`](@ref) if you want a `O(k)` sampler.
"""
randchoice(rng::AbstractRNG, a::AbstractArray{T}, k::Integer; exclude = T[]) where {T} = randchoice!(rng, collect(a), k; exclude = exclude)
randchoice(a::AbstractArray{T}, k::Integer; exclude = T[]) where {T} = randchoice(GLOBAL_RNG, a, k; exclude = exclude)

"""
randchoice!([rng,] a, k; exclude=nothing)

Sample `k` elements from array `a` without repetition and eventually excluding elements in `exclude`.
Pay attention, it changes the order of the elements in `a`.
Use [`randchoice`](@ref) for the non-mutating version.
"""
function randchoice!(rng::AbstractRNG, a::AbstractArray{T}, k::Integer; exclude::Vector{T} = T[]) where T
    length(a) < k + length(exclude) && error("Array too short.")
    res = Vector{eltype(a)}()
    sizehint!(res, k)
    n = length(a)
    i = 1
    while length(res) < k
        r = rand(rng, 1:n-i+1)
        if !(a[r] in exclude)
            push!(res, a[r])
            a[r], a[n-i+1] = a[n-i+1], a[r]
            i += 1
        end
    end
    return res
end

randchoice!(a::AbstractArray{T}, k::Integer; exclude = T[]) where {T} = randchoice!(GLOBAL_RNG, a, k; exclude = exclude)

"""
    randchoice([rng,] itr)

Returns a random element of `itr`. This implementation
is more efficient than the one in Base for `rand(itr)`.
"""
randchoice(rng, itr) = nth(itr, _randchoice(rng, length(itr)))
randchoice(itr) = randchoice(GLOBAL_RNG, itr)

_randchoice(rng, n::Int) = floor(Int, rand(rng) * n) + 1

#
#    nth(xs, n::Integer)
#
#Return the n'th element of xs. Mostly useful for non indexable collections.
function nth(xs, n::Integer)
    n > 0 || throw(BoundsError(xs, n))
    # catch, if possible
    applicable(length, xs) && (n ≤ length(xs) || throw(BoundsError(xs, n)))
    s = start(xs)
    i = 0
    while !done(xs, s)
        (val, s) = next(xs, s)
        i += 1
        i == n && return val
    end
    # catch iterators with no length but actual finite size less then n
    throw(BoundsError(xs, n))
end

nth(xs::AbstractArray, n::Integer) = xs[n]


"""
    getRNG(seed)

Returns `MersenneTwister(seed)` if `seed` is greater than `0`, `GLOBAL_RNG`
otherwise.
"""
getRNG(seed::Integer) = seed > 0 ? MersenneTwister(seed) : GLOBAL_RNG

end #submodule
