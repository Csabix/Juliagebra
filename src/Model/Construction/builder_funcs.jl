

function process_until_closed!(self::Builder, model::Model)
    for item in self._in
        process_item!(self, model, item)
    end

    println("ThreadID($(Threads.threadid())): Builder Ended!")
end

function process_avail!(self::Builder, model::Model)
    taken = Base.n_avail(self._in)

    for _ in 1:taken
        item::_BuilderT = take!(self._in)
        process_item!(self, model, item)
    end
end

function process_item!(self::Builder, model::Model, item::_BuilderT)
    # ? Must wait for Model to be in BuildingState.
    lock(self) do 
        @invokelatest _build(model,item)
    end
end



function _build(model::Model, dependent::DependentDNA)
    @assert isUnbuilt(dependent) "Dependent is already built!"
    
    graph::DependentGraph = getGraph(model)

    startTime = time_ns()
    add!!(graph,dependent)
    endTime = time_ns()
    # TODO: Save and Display theese times for benchmarks.    
    ccputime = (endTime-startTime)/1000000.0

    # TODO: Move this to another stage.
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

    # TODO: Move this to another stage.
    setEntryNodes(subject)
    onNodeEval(subject)

    # ? Forward the Subject to the Adder.
    put!(adder,subject)
end