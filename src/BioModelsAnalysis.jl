module BioModelsAnalysis
using BioModelsLoader, Test, SBML, JSON3, SBMLToolkit, ModelingToolkit, Base.Threads, TimerOutputs, CSV, DataFrames, ProgressMeter, Suppressor
using Pkg.Artifacts
DATADIR = joinpath(@__DIR__, "..", "data")
data(x) = joinpath(DATADIR, x)
ODE_DIR = artifact"odes"

get_ssys(m) = structural_simplify(convert(ODESystem, ReactionSystem(m)))
id_to_fn(id) = joinpath(ODE_DIR, "$id.xml")
unzip(xs) = first.(xs), last.(xs)

const MODEL_META_PROPS = [:compartments, :species, :reactions, :parameters, :events, :rules, :function_definitions]

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
            push!(bad, (i, x) => (e, current_exceptions()))
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

function split_timev(nt)
    nt[Not(:value)], nt[:value]
end

function model_metadata_nt(m)
    length.(getproperty.((m,), MODEL_META_PROPS))
end

"given goods of timed_read_sbml, make a dataframe with model size metadata and timings"
function meta_df(gs)
    nts, ms = unzip(map(BioModelsAnalysis.split_timev, last.(gs)))
    good_ids = map(x -> x[1][2], gs)
    df = DataFrame(nts)
    insertcols!(df, 1, :id => good_ids)
    sort!(df, :time; rev=true)
    df[!, :filesize] = filesize.(BioModelsAnalysis.id_to_fn.(df.id))

    lens = BioModelsAnalysis.model_metadata_nt.(ms);
    mdf = DataFrame(stack(lens;dims=1), BioModelsAnalysis.MODEL_META_PROPS)
    insertcols!(mdf, 1, :id => good_ids)
    big_df = innerjoin(mdf, df, on=:id)
    sort!(big_df, [:reactions, :species, :parameters]; rev=true)
    big_df
end


end # module BioModelsAnalysis
