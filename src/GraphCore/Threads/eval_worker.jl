
# ? ---------------------------------
# ! EvalWorker
# ? ---------------------------------

"""
Calls onNodeEval() on put nodes, then sends them to synchronizer.
"""
mutable struct EvalWorker{T<:Union{Queue{DependentDNA}, Channel{DependentDNA}}}
    _in::T
    _processed::Vector{Float32}

    function EvalWorker(in::T) where {T}#<:Union{Queue{DependentDNA}, Channel{DependentDNA}}}
        new{T}(in,[])
    end

    function EvalWorker{Queue{DependentDNA}}()
        return EvalWorker(Queue{DependentDNA}())
    end

    function EvalWorker{Channel{DependentDNA}}()
        return EvalWorker(Channel{DependentDNA}(100))
    end
end

const EvalWorker0 = EvalWorker{Queue{DependentDNA}}
const EvalWorkeri = EvalWorker{Channel{DependentDNA}}

Base.put!(self::EvalWorker0, d::DependentDNA) = push!(self._in,d)
Base.take!(self::EvalWorker0)::DependentDNA = return popfirst!(self._in)
Base.length(self::EvalWorker0) = return length(self._in)

function destroy!(self::EvalWorkeri)
    close(self._in)
end

function processUntilClosed!(self::EvalWorker0, model::ModelDNA)
    taken = length(self)
    Base.resize!(self._processed,0)

    for _ in 1:taken
        _process1(self, model, take!(self))
    end
end

function processUntilClosed!(self::EvalWorkeri, model::ModelDNA)
    for d in self._in
        _process1(self, model, d)
    end

    println("ThreadID($(Threads.threadid())): EvalWorkeri Ended!")
end

function _process1(self::EvalWorker, ::ModelDNA, d::DependentDNA)
    startTime = time()
    @invokelatest _process2(d)
    endTime = time()-startTime

    push!(self._processed, Float32(endTime * 1000))
end

function _process1(self::EvalWorker, model::ModelDNA, o::ObservedDNA)
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
# ! Workers
# ? ---------------------------------

@kwdef mutable struct Workers
    _workersi::Vector{EvalWorkeri} = Vector{EvalWorkeri}([EvalWorkeri() for i in 1:1])
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

