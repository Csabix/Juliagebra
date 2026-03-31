
# ? ---------------------------------
# ! Scheduler
# ? ---------------------------------

const PER_FRAME_MERGE::Int = 25

"""
Manages correct graph evaluation scheduling.
"""
@kwdef mutable struct Scheduler
    _in::Queue{DependentDNA} = Queue{DependentDNA}(PER_FRAME_MERGE)
    _taken::Int = 0
    _schedule::Schedule = Schedule()
    _roots::Set{DependentDNA} = Set{DependentDNA}() 
end

Base.schedule(self::Scheduler,dependent::DependentDNA) = isfull(self) ? (@warn "Reached Scheduler max per frame capacity, ignoring Dependent!") : push!(self._in,dependent)
Base.isempty(self::Scheduler)::Bool = return isempty(self._in)
Base.length(self::Scheduler) = return length(self._in)
Base.isfull(self::Scheduler) = return length(self._in) == PER_FRAME_MERGE
isFinished(self::Scheduler)::Bool = return true

function startGraphWorkers!(self::Scheduler, app::AppDNA)
    self._taken = length(self)
    heads::Set{DependentDNA} = Set{DependentDNA}()
    schedules::Vector{Schedule} = []

    for _ in 1:self._taken
        d::DependentDNA = popfirst!(self._in)
        push!(schedules,getSchedule(d))
        push!(heads,d)
    end

    if !isempty(schedules)
        # TODO: maybe copy to avoid GC?
        self._schedule = merge(schedules)
        empty!(self._roots)

        for d in heads
            if !(d in dependentsOf(self._schedule))
                push!(self._roots,d)
            end
        end

        # ? Send head Dependents for synchronization,
        # ? since they are up to date from outside modifications.
        sy::Synchronizer = getSynchronizer(app)
        for d in self._roots
            put!(sy,d)
        end

        
        # ? Assign Dependents in the schedule to workers for onNodeEval() calls.
        w::GraphWorker = getWorker(app)
        for d in self._schedule
            put!(w,d)
        end
    end
end