
# ? ---------------------------------
# ! WorkerFood
# ? ---------------------------------

struct WorkerFood{T<:Union{DependentDNA, SyncFood}}
    conditions::Vector{CompletedCondition}
    data::T
    evaled::CompletedCondition

    function WorkerFood(conditions::Vector{CompletedCondition}, data::T, evaled::CompletedCondition) where {T<:Union{DependentDNA, SyncFood}}
        new{T}(conditions, data, evaled)
    end
end

getDependent(self::WorkerFood{<:DependentDNA})::DependentDNA = return self.data
getDependent(self::WorkerFood{SyncFood})::ObservedDNA = return self.data.observed

# ? ---------------------------------
# ! EvalWorker
# ? ---------------------------------

function pushEndTime!(self::EvalWorker, id::Int, startTime::UInt64)
    ids::Vector{Int} = getProcessedIDs(self)
    ts::Vector{Float64} = getProcessedTimes(self)
    
    push!(ids,id)
    push!(ts,(time_ns()-startTime)/1000000.0)
end

# ? ---------------------------------
# ! EvalWorker0
# ? ---------------------------------

"""
Calls onNodeEval() on put nodes, then sends them to synchronizer.
"""
@kwdef mutable struct EvalWorker0 <: EvalWorker
    _in::Queue{DependentDNA} = Queue{DependentDNA}()
    _processedIDs::Vector{Int} = []
    _processedTimes::Vector{Float64} = []
end

Base.put!(self::EvalWorker0, d::DependentDNA) = push!(self._in,d)
Base.take!(self::EvalWorker0)::DependentDNA = return popfirst!(self._in)
Base.length(self::EvalWorker0) = return length(self._in)
getProcessedIDs(self::EvalWorker0)::Vector{Int} = return self._processedIDs
getProcessedTimes(self::EvalWorker0)::Vector{Float64} = return self._processedTimes


function processUntilClosed!(self::EvalWorker0, model::ModelDNA)
    Base.resize!(self._processedIDs,0)
    Base.resize!(self._processedTimes,0)
    taken = length(self)

    for _ in 1:taken
        startTime = time_ns()
        
        d::DependentDNA = take!(self)
        _process1(self, model, d)

        pushEndTime!(self, getGraphID(d), startTime)
    end
end

function _process1(self::EvalWorker0, ::ModelDNA, d::DependentDNA)    
    @invokelatest _process2(d)
end

function _process1(self::EvalWorker0, model::ModelDNA, o::ObservedDNA)    
    @invokelatest _process2(o)
    put!(getSynchronizer(model),o)
end

function _process2(dependent::DependentDNA)
    beforeNodeEval(dependent)
    onNodeEval(dependent)
    afterNodeEval(dependent)
end

# ? ---------------------------------
# ! EvalWorkeri
# ? ---------------------------------

"""
Calls onNodeEval() on put nodes, then sends them to synchronizer.
"""
@kwdef mutable struct EvalWorkeri <: EvalWorker
    _in::Channel{Vector{WorkerFood}} = Channel{Vector{WorkerFood}}(1)
    _processedIDs::Vector{Int} = []
    _processedTimes::Vector{Float64} = []
end

Base.put!(self::EvalWorkeri, fs::Vector{WorkerFood}) = put!(self._in,fs)
Base.take!(self::EvalWorkeri)::DependentDNA = return take!(self._in)
destroy!(self::EvalWorkeri) = close(self._in)
getProcessedIDs(self::EvalWorkeri)::Vector{Int} = return self._processedIDs
getProcessedTimes(self::EvalWorkeri)::Vector{Float64} = return self._processedTimes
    
function processUntilClosed!(self::EvalWorkeri, model::ModelDNA)
    for foods in self._in
        Base.resize!(self._processedIDs,0)
        Base.resize!(self._processedTimes,0)
        
        for food in foods 
            conditions::Vector{CompletedCondition} = food.conditions

            # ? Wait for parents to be completed. 
            for c in conditions
                wait(c)
            end
            
            startTime = time_ns()
            
            _process1(self, model, food.evaled, food.data)
            
            pushEndTime!(self, getGraphID(getDependent(food)), startTime)
        end
    end

    println("ThreadID($(Threads.threadid())): EvalWorkeri Ended!")
end

function _process1(self::EvalWorkeri, model::ModelDNA, evaled::CompletedCondition, d::DependentDNA)
    @invokelatest _process2(d)
    notify(evaled)
    increment(getScheduler(model)._evaledGoal)
end

function _process1(self::EvalWorkeri, model::ModelDNA, evaled::CompletedCondition, data::SyncFood)
    o::ObservedDNA = data.observed
    
    @invokelatest _process2(o)
    notify(evaled)
    increment(getScheduler(model)._evaledGoal)

    put!(getSynchronizer(model),data)
end

# ? ---------------------------------
# ! Workers
# ? ---------------------------------

MAX_WORKER_NUM() = max(1,Threads.threadpoolsize()-2)

@kwdef mutable struct Workers
    _workersi::Vector{EvalWorkeri} = Vector{EvalWorkeri}([EvalWorkeri() for i in 1:MAX_WORKER_NUM()])
    _worker0::EvalWorker0 = EvalWorker0()
end

Base.length(self::Workers) = return length(self._workersi)

function destroy!(self::Workers)
    for workeri in self._workersi
        destroy!(workeri)
    end
end

function Base.getindex(self::Workers, idx::Int)::Union{EvalWorker0, EvalWorkeri}
    if idx == 0
        return self._worker0
    else
        return self._workersi[idx]
    end
end

