

function processUntilClosed!(self::Builder, model::Model)
    for node in self._in
        # ? Must wait for Model to be in BuildingState.
        lock(self) do 
            @invokelatest _build(model,node)
        end
    end

    println("ThreadID($(Threads.threadid())): Builder Ended!")
end


function _build(model::Model, dependent::DependentDNA)
    @assert isUnbuilt(dependent) "Dependent is already built!"
    
    graph::DependentGraph = getGraph(model)

    startTime = time_ns()
    add!!(graph,dependent)
    endTime = time_ns()
    # TODO: Save and Display theese times for benchmarks.    
    ccputime = (endTime-startTime)/1000000.0

    setEntryNodes(dependent)
    onNodeEval(dependent)
end


function _build(model::Model, oo::Tuple{SubjectDNA,ObserverDNA})
    subject::SubjectDNA = oo[1]
    observer::ObserverDNA = oo[2]

    @assert isUnbuilt(subject) "Subject is already built!"

    graph::DependentGraph = getGraph(model)
    adder::Adder = getAdder(model)

    add!!(observer,subject)

    startTime = time_ns()
    add!!(graph,subject)
    endTime = time_ns()
    # TODO: Save and Display theese times for benchmarks.
    ccputime = (endTime-startTime)/1000000.0

    setEntryNodes(subject)
    onNodeEval(subject)

    # ? Forward the Subject to the Adder.
    put!(adder,subject)
end