using BioModelsAnalysis, BioModelsLoader, Test, SBML, JSON3, Base.Threads, TimerOutputs, CSV, DataFrames, ProgressMeter, Suppressor
# using SBMLToolkit, ModelingToolkit

logdir = joinpath(@__DIR__, "logs")
mkpath(logdir)

N = 50
# gids_fn = BioModelsAnalysis.data("gids.txt")
# gids = readlines(gids_fn)
dir = BioModelsAnalysis.ODE_DIR
fns = readdir(dir; join=true)
ids = map(x -> splitext(basename(x))[1], fns)
p = sortperm(fns; by=filesize, rev=true)

# running on all 520 good ODE models took 300.730831 seconds (11.49 M allocations: 508.212 MiB, 0.78% gc time, 6.04% compilation time)
f = x -> @timed(@suppress_err(readSBML(BioModelsAnalysis.id_to_fn(x), BioModelsLoader.DEFAULT_CONVERT_FUNCTION)))
(gs, bs) = @time BioModelsAnalysis.goodbadt(f, ids);

df = BioModelsAnalysis.meta_df(gs)
CSV.write("logs/meta_df.csv", df)

# "redesign this"
# function folded_goodbadt(fs, xs; kws...)
#     gs, bs = [], []
#     for f in fs
#         xs, b = goodbadt(f, xs; kws...)
#         push!(gs, xs)
#         push!(bs, b)
#     end
#     gs, bs
# end



# g = x -> @timed(@suppress_err(BioModelsAnalysis.get_ssys(x)))
# fs = [f, g]
# ys = folded_goodbadt(fs, ids[1:1])

#revisit this shit after writing 
# whats going on w the stochastic results here
# its almost certainly a threading issue, since `goodbad` returns consistent `length(gs)`
# (gs_, bs_) = @time BioModelsAnalysis.goodbadt(f, ids);
# @test_broken length(gs) == length(gs_)

# f = x -> @timed(@suppress_err(BioModelsAnalysis.get_ssys(x)))
# this takes hours so we only do a subset of biomodels 
# gs2, bs2 = @time BioModelsAnalysis.goodbadt(f, ms; verbose=true);
# @test length(gs2) == N

# @test length(bs2) == 11 # if we tested on all of them 
# serialize(joinpath(logdir, "good_ssys.jls"), gs2)
# @test length(gs2) == 43

# md = Dict(good_ids .=> ms);

# for id in good_ids
#     @test collect(mdf[findfirst(mdf.id .== id), 2:end]) == BioModelsAnalysis.model_metadata_nt(md[id])
# end
