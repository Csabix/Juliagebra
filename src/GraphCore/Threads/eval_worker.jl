
# ? ---------------------------------
# ! EvalWorker
# ? ---------------------------------

"""
Calls onNodeEval() on put nodes, then sends them to synchronizer.
"""
mutable struct EvalWorker{T<:Union{Queue{DependentDNA}, Channel{DependentDNA}}}
    _in::T
    _taken::Int

    function EvalWorker(in::T) where {T}#<:Union{Queue{DependentDNA}, Channel{DependentDNA}}}
        new{T}(in,0)
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

function processUntilClosed!(self::EvalWorker0, model::ModelDNA)
    sy::Synchronizer = getSynchronizer(model)
    
    self._taken = length(self)

    for _ in 1:self._taken
        d::DependentDNA = take!(self)
        @invokelatest _process(self,d)
        
        if d isa ObservedDNA
            o::ObservedDNA = d
            put!(sy,o)
        end 
    end
end

function _process(::EvalWorker0, dependent::DependentDNA)
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

function Base.getindex(self::Workers, idx::Int)::Union{EvalWorker0, EvalWorkeri}
    if idx == 0
        return self._worker0
    else
        return self._workersi[idx]
    end
end

