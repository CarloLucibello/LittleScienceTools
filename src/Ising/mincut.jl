"""
    ground_state_mincut(g::AGraph, h::Vector, J)

Exactly compute the ground state of an Ising model with ferromagneting (i.e. nonnegative)
couplings using a minimum cut algorithm implemented in FatGraphs.jl package.

Coupling `J` can be in the form of a costant, a matrix, or a
vector of vectors (adjacency list style).

Returns a vector `σ` taking values ±1.
"""
function ground_state_mincut(g::AGraph, h::Vector, J)
    N = nv(g)
    source = N + 1
    target = N + 2
    dg, c = net_capacity(g, h, J)
    f, F, labels = maximum_flow(dg, source, target, c)
    σ = 3 - labels[1:N]*2
    return σ
end

function net_capacity{T}(g::AGraph, h::Vector{T}, J)
    N = nv(g)
    dg = digraph(g)
    add_vertices!(dg, 2)
    source = N+1
    target = N+2
    for i=1:N
        if h[i] > 0
            add_edge!(dg, source, i)
            add_edge!(dg, i, source)
        else
            add_edge!(dg, i, target)
            add_edge!(dg, target, i)
        end
    end

    C = promote_type(Jtype(J), T)
    c = Vector{Vector{C}}()
    for i=1:N
        neigs = neighbors(dg, i)
        push!(c, zeros(length(neigs)))
        for (k,j) in enumerate(neigs)
            if j <= N
                c[i][k] = getJ(J, i, j, k)
            elseif j == target
                c[i][k] = abs(h[i])
            end

        end
    end
    push!(c, zeros(degree(dg, source)))
    push!(c, zeros(degree(dg, target)))

    for (k,j) in enumerate(neighbors(dg, source))
        c[source][k] = abs(h[j])
    end

    return dg, c
end