
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
    schedules::Vector{Schedule} = []

    for _ in 1:length(q)
        d::DependentDNA = popfirst!(q)
        # TODO: Remove this afterNodeEval!
        afterNodeEval(d)
        push!(schedules,getSchedule(d))
    end

    if !isempty(schedules)
        s::Schedule = merge(schedules)
        println("$(s)")
        evalChain(s)
    end
end