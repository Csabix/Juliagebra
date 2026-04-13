
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

"""
Calls onNodeEval() on put nodes, then sends them to synchronizer.
"""
mutable struct EvalWorker{T<:Union{Queue{DependentDNA}, Channel{Vector{WorkerFood}}}}
    _in::T
    _processed::Vector{Float32}

    function EvalWorker(in::T) where {T}#<:Union{Queue{DependentDNA}, Channel{DependentDNA}}}
        new{T}(in,[])
    end

    function EvalWorker{Queue{DependentDNA}}()
        return EvalWorker(Queue{DependentDNA}())
    end

    function EvalWorker{Channel{Vector{WorkerFood}}}()
        return EvalWorker(Channel{Vector{WorkerFood}}(1))
    end
end

# ? ---------------------------------
# ! EvalWorker0
# ? ---------------------------------

const EvalWorker0 = EvalWorker{Queue{DependentDNA}}

Base.put!(self::EvalWorker0, d::DependentDNA) = push!(self._in,d)
Base.take!(self::EvalWorker0)::DependentDNA = return popfirst!(self._in)
Base.length(self::EvalWorker0) = return length(self._in)

function processUntilClosed!(self::EvalWorker0, model::ModelDNA)
    taken = length(self)
    Base.resize!(self._processed,0)

    for _ in 1:taken
        _process1(self, model, take!(self))
    end
end

function _process1(self::EvalWorker0, ::ModelDNA, d::DependentDNA)
    startTime = time()
    @invokelatest _process2(d)
    endTime = time()-startTime

    push!(self._processed, Float32(endTime * 1000))
end

function _process1(self::EvalWorker0, model::ModelDNA, o::ObservedDNA)
    startTime = time()
    @invokelatest _process2(o)
    put!(getSynchronizer(model),o)
    endTime = time()-startTime

    push!(self._processed, Float32(endTime * 1000))
end

function _process2(dependent::DependentDNA)
    beforeNodeEval(dependent)
    onNodeEval(dependent)
    afterNodeEval(dependent)
end

# ? ---------------------------------
# ! EvalWorkeri
# ? ---------------------------------



const EvalWorkeri = EvalWorker{Channel{Vector{WorkerFood}}}

Base.put!(self::EvalWorkeri, fs::Vector{WorkerFood}) = put!(self._in,fs)
Base.take!(self::EvalWorkeri)::DependentDNA = return take!(self._in)
destroy!(self::EvalWorkeri) = close(self._in)
    
function processUntilClosed!(self::EvalWorkeri, model::ModelDNA)
    for foods in self._in
        for food in foods 
            conditions::Vector{CompletedCondition} = food.conditions

            # ? Wait for parents to be completed. 
            for c in conditions
                wait(c)
            end

            _process1(self, model, food.evaled, food.data)
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

@kwdef mutable struct Workers
    _workersi::Vector{EvalWorkeri} = Vector{EvalWorkeri}([EvalWorkeri() for i in 1:8])
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

