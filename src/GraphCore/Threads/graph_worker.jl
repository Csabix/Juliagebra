
# ? ---------------------------------
# ! GraphWorker
# ? ---------------------------------

@kwdef mutable struct GraphWorker
    _in::Queue{DependentDNA} = Queue{DependentDNA}()
end

Base.put!(self::GraphWorker, d::DependentDNA) = push!(self._in,d)
Base.take!(self::GraphWorker)::DependentDNA = return popfirst!(self._in)
Base.length(self::GraphWorker) = return length(self._in)

function processUntilClosed!(self::GraphWorker, synchronizer::Synchronizer)
    println("worker: $(length(self._in))")
    takeNum = length(self)
    
    for _ in 1:takeNum
        d::DependentDNA = take!(self)
        @invokelatest _process(self,d)
        put!(synchronizer,d)
    end
end

function _process(::GraphWorker, dependent::DependentDNA)
    beforeNodeEval(dependent)
    onNodeEval(dependent)
    afterNodeEval(dependent)
end
