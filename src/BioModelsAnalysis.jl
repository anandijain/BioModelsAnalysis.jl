module BioModelsAnalysis
using BioModelsLoader, Test, SBML, JSON3, SBMLToolkit, ModelingToolkit, Base.Threads, TimerOutputs, CSV, DataFrames, ProgressMeter, Suppressor

DATADIR = joinpath(@__DIR__, "..", "data")
data(x) = joinpath(DATADIR, x)
ODE_DIR = BioModelsAnalysis.data("odes")

get_ssys(m) = structural_simplify(convert(ODESystem, ReactionSystem(m)))
id_to_fn(id) = joinpath(data("odes"), "$id.xml")

function goodbadt(f, xs; verbose=false)
    n = length(xs)
    p = Progress(n)

    good = []
    bad = []
    Threads.@threads for (i, x) in collect(enumerate(xs))
        verbose && @info x
        try
            y = f(x)
            push!(good, (i, x) => y)
        catch e
            push!(bad, (i, x) => e)
        end
        next!(p)
    end
    good, bad
end

"todo get rid of this "
function timed_read_sbml(id)
    fn = joinpath(ODE_DIR, "$id.xml")
    m = @timed readSBML(fn, BioModelsLoader.DEFAULT_CONVERT_FUNCTION)
    time_nt = (; id, m[filter(!=(:value), keys(m))]...)
    val = m.value
    time_nt, val
end

"todo get rid of this "
function time_f_tup(f, x)
    y = @timed f(x)
    time_nt = (; id, y[filter(!=(:value), keys(y))]...)
    val = y.value
    time_nt, val
end

function model_metadata_nt(id_m_pair)
    id, m = id_m_pair
    props = [:compartments, :species, :reactions, :parameters, :events, :rules, :function_definitions]
    ps = [:id => id, (props .=> length.(getproperty.((m,), props)))...]
    NamedTuple(ps)
end

"given goods of timed_read_sbml, make a dataframe with model size metadata and timings"
function meta_df(gs)
    nts = map(x -> x[2][1], gs)
    ms = map(x -> x[2][2], gs);
    
    df = DataFrame(nts)
    sort!(df, :time; rev=true)
    df[!, :filesize] = filesize.(id_to_fn.(df.id))
    
    good_ids = map(x -> x[1][2], gs)
    id_m_pairs = good_ids .=> ms;
    len_nts = model_metadata_nt.(id_m_pairs);
    mdf = DataFrame(len_nts)
    big_df = innerjoin(mdf, df, on=:id)
    sort!(big_df, [:reactions, :species, :parameters]; rev=true)
    big_df
end

end # module BioModelsAnalysis
