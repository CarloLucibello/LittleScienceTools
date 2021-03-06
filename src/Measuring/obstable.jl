const Ord = Base.Order.ForwardOrdering
const ObsData = SortedDict{Tuple, OrderedDict{String,Observable}, Ord}

mutable struct ObsTable
    data::ObsData
    par_names::OrderedSet{String}
end

## TODO deprecate, no table should be initialized
ObsTable() = ObsTable(ObsData(Ord()), OrderedSet{String}())

function ObsTable(::Type{Params}) where Params
    t = ObsTable(string.(fieldnames(Params)))
    t
end
ObsTable(params::T) where {T} = ObsTable(T)
ObsTable(pnames::Vector) = ObsTable(string.(pnames))
ObsTable(pnames::Tuple) = ObsTable(collect(pnames))

function ObsTable(pnames::Vector{String})
    t = ObsTable()
    set_params_names!(t, pnames)
    t
end

==(t1::ObsTable, t2::ObsTable) = t1.data==t2.data && t1.par_names==t2.par_names

#set_params_names!(t::ObsTable, a) = set_params_names!(fieldnames(a))
set_params_names!(t::ObsTable, keys...) = set_params_names!(t, collect(keys))
set_params_names!(t::ObsTable, keys::Vector{Symbol}) = set_params_names!(t, string.(keys))
set_params_names!(t::ObsTable, keys::Vector) = error("non valid keys")

function set_params_names!(t::ObsTable, keys::Vector{<:AbstractString})
    length(t.par_names) != 0 && Error("Can be done only once!")
    t.par_names = OrderedSet(String.(keys))
end

params_names(t::ObsTable) = t.par_names

function obs_names(t::ObsTable)
    names = OrderedSet{String}()
    for (k,v) in t.data
        push!(names, keys(v)...)
    end
    names
end

function nsamples(t::ObsTable, par::Tuple)
    haskey(t, par) || return 0
    return first(t[par])[2].t
end

# Indexing inteface
getindex(t::ObsTable, i...) = get!(t.data, to_index(t, i), OrderedDict{String,Observable}())
setindex!(t::ObsTable, v, i...) = setindex!(t.data, v, to_index(t, i))

getindex(t::ObsTable, i) = get!(t.data, to_index(t, i), OrderedDict{String,Observable}())
setindex!(t::ObsTable, v, i) = setindex!(t.data, v, to_index(t, i))

splat(a) = [getfield(a,f) for f in fieldnames(typeof(a))]


function to_index(t, i::Tuple)  
    @assert length(params_names(t)) == length(i) "wrong number of params in indexing"
    i
end

to_index(t, i::Vector) = to_index(t, (i...,))
function to_index(t, i)
    if length(fieldnames(typeof(i))) == 0 #it is not a composite type
        return to_index(t, (i,))
    else
        return to_index(t, (splat(i)...,))
    end
end

# SOME type piracy here
getindex(d::OrderedDict{String,Observable}, i::String) = get!(d, i, Observable())
getindex(d::OrderedDict{String,Observable}, i::Symbol) = get!(d, string(i), Observable())
setindex!(d::OrderedDict{String,Observable}, x, i::Symbol) = setindex!(d, x, string(i))

endof(t::ObsTable) = endof(t.data)

haskey(t::ObsTable, k) = haskey(t.data, k)

# Iterable inteface
Base.iterate(t::ObsTable, x...) = iterate(t.data, x...)
eltype(::Type{ObsTable}) = eltype(typeof(t.data))
length(t::ObsTable) = length(t.data)

"""
    header(t::ObsTable)

Returns a string containg the header of the printed table.
"""
function header(t::ObsTable; lenpar=9, lenobs=18)
    pnames= t.par_names
    onames = obs_names(t)
    h = ""
    i = 1
    for k in pnames
        s = i == 1 ? "# $i:$k " : "$i:$k "
        h *= rpad(s, lenpar)
        i+=1
    end
    h *= rpad("$i:num ", lenpar)
    i+= 1
    for k in onames
        h *=  rpad("$i:$k ", lenobs)
        i +=2
    end
    return h
end

function Base.show(io::IO, t::ObsTable)
    lenpar = 9
    lenobs = 21
    println(io, header(t, lenpar=lenpar, lenobs=lenobs))
    onames = obs_names(t)
    for (par, obs) in t
        for p in par
            print(io, rpad("$p ", lenpar))
        end

        print(io, rpad("$(nsamples(t, par)) ", lenpar))
        for name in onames    
            s = haskey(obs, name) ? "$(obs[name]) " : "NaN NaN "
            print(io, rpad(s, lenobs))
        end
        println(io)
    end
end

"""
    merge(t::ObsTables, ts::ObsTable...)
    merge!(t::ObsTables, ts::ObsTable...)

Fuse togheter the observations of many `ObsTable`s 
as if the where independent measurements.
"""
function merge(t1::ObsTable, ts::ObsTable...)
    t = deepcopy(t1)
    return merge!(t, ts...)
end

function merge!(t::ObsTable, ts::ObsTable...)
    for t2 in ts
        t.par_names = union(t.par_names, t2.par_names)
        for (k,v) in t2
            for (n, o) in v
                t[k][n] &= o
            end
        end
    end
    return t
end

"""
    tomatrices(t::ObsTable) -> (params, means, errs)

Converts `t` into three matrices, `params`,`means` and `errs`.
"""
function tomatrices(t::ObsTable)
    n = length(t)
    m1 = length(params_names(t))
    pars = zeros(n,m1)
    onames = obs_names(t)
    m2 = length(obs_names(t))
    y = zeros(n, m2)
    yerr = zeros(n, m2)
    i = 1
    for (p, olist) in t
        pars[i,:] = [p...]
        for (j, oname) in enumerate(onames)
            obs = olist[oname]
            y[i,j] = mean(obs)
            yerr[i,j] = err(obs)
        end
        i += 1
    end
    return pars, y, yerr
end


"""
    tomatrix(t::ObsTable)

Converts `t` into a matrix corresponding to the printed table.
See [`header`](@ref) for the meaning of the columns.
"""
function tomatrix(t::ObsTable)
    n = length(t)
    m1 = length(params_names(t))
    onames = obs_names(t)
    m2 = length(obs_names(t))
    y = zeros(n, m1 + 1 + 2m2) #condidering also #samples
    i = 1
    for (p, olist) in t
        y[i,1:m1] = [p...]
        y[i,m1+1] = nsamples(t, p)
        for (j, oname) in enumerate(onames)
            obs = olist[oname]
            j = 2j+m1
            y[i,j] = mean(obs)
            y[i,j+1] = err(obs)
        end
        i += 1
    end
    return y
end

"""
    ObsTable(datfile::String)

Read an observable from a properly formatted data file 
(i.e. the result of a `print(datfile,t::ObsTable)`).
"""
function ObsTable(datfile::String)
    f = open(datfile,"r")
    t = ObsTable()
    eof(f) && return t
    header = readline(f)
    header = split(header)
    @assert header[1] == "#"

    colnums = parse.(Int, map(x->split(x,':')[1], header[2:end]))
    names = map(x->split(x,':')[2], header[2:end])

    count = findlast(colnums .== 1:length(colnums))
    nparams = count - 2
    @assert names[nparams+1] ∈ ["num", "samples", "nsamples", "nsamp"]
    set_params_names!(t, names[1:nparams]...)
    eof(f) && return t    
    res = readdlm(f)
    close(f)
    onames = String.(names[count:end])
    for i=1:size(res,1)
        pars = (res[i,1:nparams]...,)
        nsamp = res[i,nparams+1]
        for j=count:2:size(res,2)-1
            m, e = res[i,j], res[i,j+1]
            name = onames[(j-count)÷2 + 1]
            if isfinite(m)
                t[pars][name] = obs_from_mean_err_samp(m, e, nsamp)
            end
        end
    end
    return t
end
