
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
Base.length(self::Scheduler) = return length(self._in)
isFinished(self::Scheduler)::Bool = return true

function startGraphWorkers!(self::Scheduler, app::AppDNA)
    println("scheduler: $(length(self._in))")
    takeNum = length(self)
    heads::Set{DependentDNA} = Set{DependentDNA}()
    schedules::Vector{Schedule} = []

    for _ in 1:takeNum
        d::DependentDNA = popfirst!(self._in)
        push!(schedules,getSchedule(d))
        push!(heads,d)
    end

    if !isempty(schedules)
        s::Schedule = merge(schedules)
        roots::Set{DependentDNA} = Set{DependentDNA}()

        for d in heads
            if !(d in dependentsOf(s))
                push!(roots,d)
            end
        end
        
        #println("schedule: $([getGraphID(d) for d in dependentsOf(s)])")
        #println("roots: $([getGraphID(d) for d in roots])")

        sy::Synchronizer = getSynchronizer(app)
        for d in heads
            put!(sy,d)
        end

        # TODO: refine.
        w::GraphWorker = getWorker(app)
        for d in s
            put!(w,d)
        end
    end
end