using BioModelsAnalysis, BioModelsLoader, Test, SBML, JSON3, Base.Threads, TimerOutputs, CSV, DataFrames, ProgressMeter, Suppressor
# using SBMLToolkit, ModelingToolkit

logdir = joinpath(@__DIR__, "logs")
mkpath(logdir)
mkpath(BioModelsAnalysis.ODE_DIR)

N = 50
gids_fn = BioModelsAnalysis.data("gids.txt")
gids = readlines(gids_fn)
fns = map(x -> joinpath(BioModelsAnalysis.ODE_DIR, "$x.xml"), gids)
p = sortperm(fns; by=filesize, rev=true)
ids = gids[p]

fns = fns[1:N]
ids = ids[1:N]

if !all(isfile.(fns))
    BioModelsLoader.get_archive(ids, BioModelsAnalysis.ODE_DIR)
end
@test all(isfile.(fns))

# running on all 520 good ODE models took 300.730831 seconds (11.49 M allocations: 508.212 MiB, 0.78% gc time, 6.04% compilation time)
f = x -> @timed(@suppress_err(readSBML(BioModelsAnalysis.id_to_fn(x), BioModelsLoader.DEFAULT_CONVERT_FUNCTION)))
(gs, bs) = @time BioModelsAnalysis.goodbadt(f, ids);

# whats going on w the stochastic results here
# its almost certainly a threading issue, since `goodbad` returns consistent `length(gs)`
# (gs_, bs_) = @time BioModelsAnalysis.goodbadt(f, ids);
# @test_broken length(gs) == length(gs_)

# this takes hours so we only do a subset of biomodels 
# f = x -> @timed(@suppress_err(BioModelsAnalysis.get_ssys(x)))
# gs2, bs2 = @time BioModelsAnalysis.goodbadt(f, ms; verbose=true);
# @test length(gs2) == N

# @test length(bs2) == 11 # if we tested on all of them 
# serialize(joinpath(logdir, "good_ssys.jls"), gs2)
# @test length(gs2) == 43

df = BioModelsAnalysis.meta_df(gs)
CSV.write("logs/meta_df.csv", df)

# md = Dict(good_ids .=> ms);

# for id in good_ids
#     @test collect(mdf[findfirst(mdf.id .== id), 2:end]) == BioModelsAnalysis.model_metadata_nt(md[id])
# end
