
using BioModelsLoader, Test, SBML, JSON3
using ProgressMeter
using CSV, DataFrames

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

sbmls = JSON3.read(read(joinpath(@__DIR__, "logs/sbmls.json")))
odes = JSON3.read(read(joinpath(@__DIR__, "logs/odes.json")))

# m = BioModelsLoader.get_biomodel(odes[2].id)
# SBML.writeSBML(m, "model.xml")
# m2 = SBML.readSBMLFromString(SBML.writeSBML(m))
# SBML.writeSBML(m2, "model2.xml")

model_str = BioModelsLoader.string_from_url(BioModelsLoader.biomodel_url(odes[2].id))
# write("model_str.xml", model_str)
# m2 = read("model2.xml", String) == model_str

# Threads.@threads for ode in odes
#     id = ode.id
#     fn = joinpath(@__DIR__, "../data/odes/$id.xml")
#     isfile(fn) && continue
#     @info id
#     s = BioModelsLoader.download_biomodel(id)
#     write(fn, s)
#     # m = SBML.readSBMLFromString(s, BioModelsLoader.default_convert_function(3, 2))
# end


ids = map(x -> x.id, odes)
fns = map(id->joinpath(@__DIR__, "../data/odes/$id.xml"), ids)
perm = sortperm(fns;by=filesize,rev=true)
ids = ids[perm] # sort by filesize biggest to smallest 
f = id -> SBML.readSBML(joinpath(@__DIR__, "../data/odes/$id.xml"), BioModelsLoader.default_convert_function(3, 2))
@time goodbadt(f, ids);
# 731.350226 seconds (14.67 M allocations: 762.883 MiB, 0.06% gc time, 2.15% compilation time: 1% of which was recompilation)

g, b = goodbadt(f, ids);

@test length(g) == 520
@test length(b) == 95

gids = map(x -> x[1][2], g)
write("gids.txt", join(gids, "\n"))
((i, x), m) = first(g)
rs = []

for ((i, x), m) in g
    props = [:compartments, :species, :reactions, :parameters, :events, :rules, :function_definitions]
    ps = [:id=>x, (props .=> length.(getproperty.((m,), props)))...]
    nt = NamedTuple(ps)
    push!(rs, nt)
end
df = DataFrame(rs)
sort!(df, [:reactions, :species, :parameters];rev=true)
gd = Dict(map(x->x[1][2] => x[2], g));
m = gd["MODEL1009150002"]

using SBML
fn  = "/Users/anand/.julia/dev/BioModelsLoader/data/odes/MODEL1009150002.xml"
m = readSBML(fn, DEFAULT_CONVERT_FUNCTION)
rs = ReactionSystem(m)
@time rs = ReactionSystem(m)
# 160.976134 seconds (101.39 M allocations: 5.025 GiB, 79.04% gc time)
rs = ReactionSystem(m)
sys = convert(ODESystem, rs)
ssys = structural_simplify(sys)
