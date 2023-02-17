using BioModelsAnalysis, BioModelsLoader, Test, SBML, JSON3, SBMLToolkit, ModelingToolkit, Base.Threads, TimerOutputs, CSV, DataFrames, ProgressMeter, Suppressor

logdir = joinpath(@__DIR__, "logs")
mkpath(logdir)

N = 50
gids_fn = BioModelsAnalysis.data("gids.txt")
gids = readlines(gids_fn)
fns = map(x -> joinpath(BioModelsAnalysis.ODE_DIR, "$x.xml"), gids)
ids = gids[sortperm(fns; by=filesize, rev=true)]
ids = ids[1:N]

BioModelsLoader.get_archive(ids, BioModelsAnalysis.ODE_DIR)
@test all(isfile.(fns))
# running on all 520 good ODE models took 300.730831 seconds (11.49 M allocations: 508.212 MiB, 0.78% gc time, 6.04% compilation time)
gs, bs = @time BioModelsAnalysis.goodbadt(BioModelsAnalysis.timed_read_sbml, ids); 
@test length(gs) == 43 # ArgumentError("cannot convert NULL to string")

ms = map(x -> x[2][2], gs);
m = ms[end-2];
@test_logs (:warn,) match_mode = :any BioModelsAnalysis.get_ssys(m)
@test_nowarn @timed(@suppress_err(BioModelsAnalysis.get_ssys(m)))

# this takes hours so we only do a subset of biomodels 
gs2, bs2 = @time goodbadt(x -> @timed(@suppress_err(get_ssys(x))), ms);
# @test length(bs2) == 11 # if we tested on all of them 
# serialize(joinpath(logdir, "good_ssys.jls"), gs2)
# @test length(gs2) == 43
