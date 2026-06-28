
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
getDependent(self::WorkerFood{SyncFood})::SubjectDNA = return self.data.subject

# ? ---------------------------------
# ! EvalWorker
# ? ---------------------------------

abstract type EvalWorker end

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
    _in::Queue{Int} = Queue{Int}()
    _processedIDs::Vector{Int} = []
    _processedTimes::Vector{Float64} = []
end

Base.put!(self::EvalWorker0, nodeid::Int) = push!(self._in,nodeid)
Base.take!(self::EvalWorker0)::Int = return popfirst!(self._in)
Base.length(self::EvalWorker0) = return length(self._in)
getProcessedIDs(self::EvalWorker0)::Vector{Int} = return self._processedIDs
getProcessedTimes(self::EvalWorker0)::Vector{Float64} = return self._processedTimes


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

