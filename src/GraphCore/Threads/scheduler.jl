
# ? ---------------------------------
# ! Scheduler
# ? ---------------------------------

const PER_FRAME_MERGE::Int = 1

"""
Handles Graph evaluation
"""
@kwdef mutable struct Scheduler
    _in::Queue{DependentDNA} = Queue{DependentDNA}(1)
end

Base.schedule(self::Scheduler,dependent::DependentDNA) = push!(self._in,dependent)
Base.isempty(self::Scheduler)::Bool = return isempty(self._in)
isFinished(self::Scheduler)::Bool = return true

function graphEvalScheduled!(self::Scheduler)        
    q::Queue{DependentDNA} = self._in
    ds::Vector{DependentDNA} = []

    for _ in 1:length(q)
        d::DependentDNA = popfirst!(q)
        push!(ds,d)
    end

    if !isempty(ds)
        # TODO: implement merging.
        @assert length(ds)==1 "Merging not supported currently $([typeof(d) for d in ds])!"
        evalGraph(ds[1])
    end
end