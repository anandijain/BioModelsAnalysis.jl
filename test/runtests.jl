@time_imports using BioModelsLoader, Test, SBML, JSON3, SBMLToolkit, ModelingToolkit, Base.Threads, TimerOutputs, CSV, DataFrames
gids_fn = "/Users/anand/.julia/dev/BioModelsLoader/gids.txt"
gids = readlines(gids_fn)

ode_dir = "/Users/anand/.julia/dev/BioModelsLoader/data/odes"
gid = gids[1]
fn = joinpath(ode_dir, "$gid.xml")
m = readSBML(fn, BioModelsLoader.DEFAULT_CONVERT_FUNCTION)

# we need to fix TTFX
@time ReactionSystem(m) #  28.182277 seconds (33.16 M allocations: 1.927 GiB, 15.95% gc time, 99.54% compilation time)
@time ReactionSystem(m) #   0.011952 seconds (29.73 k allocations: 1.410 MiB)
rs = ReactionSystem(m)
sys = structural_simplify(convert(ODESystem, rs))

get_ssys(m) = structural_simplify(convert(ODESystem, ReactionSystem(m)))

id_to_fn(id) = joinpath(ode_dir, "$id.xml")
fns = map(gid->joinpath(ode_dir, "$gid.xml"), gids)
@test all(isfile.(fns))

ids = gids[sortperm(fns;by=filesize,rev=true)]

ms = SBML.Model[]
Threads.@threads for id in ids[1:20]
    fn = joinpath(ode_dir, "$id.xml")
    @info fn
    # m = @timeit to "$id" readSBML(fn, BioModelsLoader.DEFAULT_CONVERT_FUNCTION)
    m = @timev readSBML(fn, BioModelsLoader.DEFAULT_CONVERT_FUNCTION)
    push!(ms, m)
end
const to = TimerOutput()

ms = SBML.Model[]
for id in ids[21:100]
    fn = joinpath(ode_dir, "$id.xml")
    @info fn
    m = @timeit to "$id" readSBML(fn, BioModelsLoader.DEFAULT_CONVERT_FUNCTION)
    push!(ms, m)
end

report_severities = ["Error"],
throw_severities = ["Fatal"]


##
rows = []
for (i, m) in enumerate(ms)
    props = [:compartments, :species, :reactions, :parameters, :events, :rules, :function_definitions]
    ps = [:id=>ids[i], (props .=> length.(getproperty.((m,), props)))...]
    nt = NamedTuple(ps)
    push!(rows, nt)
end
df = DataFrame(rows)
sort!(df, [:reactions, :species, :parameters];rev=true)
md = Dict(ids[1:20] .=> ms);
id = df.id[1]
fn = id_to_fn(id)
m = md[id]
@profview get_ssys(m)
gd = Dict(map(x->x[1][2] => x[2], g));
m = gd["MODEL1009150002"]

"MODEL1006230049" # this one is very slow 