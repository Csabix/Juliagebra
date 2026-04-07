
# ? ---------------------------------
# ! GraphWorker
# ? ---------------------------------

"""
Calls onNodeEval() on put nodes, then sends them to synchronizer.
"""
@kwdef mutable struct GraphWorker
    _in::Queue{DependentDNA} = Queue{DependentDNA}()
    _taken::Int = 0
end

Base.put!(self::GraphWorker, d::DependentDNA) = push!(self._in,d)
Base.take!(self::GraphWorker)::DependentDNA = return popfirst!(self._in)
Base.length(self::GraphWorker) = return length(self._in)

function processUntilClosed!(self::GraphWorker, model::ModelDNA)
    sy::Synchronizer = getSynchronizer(model)
    
    self._taken = length(self)
    
    for _ in 1:self._taken
        d::DependentDNA = take!(self)
        @invokelatest _process(self,d)
        put!(sy,d)
    end
end

function _process(::GraphWorker, dependent::DependentDNA)
    beforeNodeEval(dependent)
    onNodeEval(dependent)
    afterNodeEval(dependent)
end
