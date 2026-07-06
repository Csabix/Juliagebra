

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
        # ? Build non-main-thread parts of the Node.
        node::DependentDNA = _build(model,item)

        # ? Forward the Node to the Adder.
        put!(getAdder(model),node)
    end
end

function _build(model::Model, dependent::DependentDNA)::DependentDNA
    @assert isUnbuilt(dependent) "Dependent is already built!"
    
    graph::DependentGraph = getGraph(model)

    startTime = time_ns()
    # ? Build InsertionTopoSubgraph for Node.
    add!!(graph,dependent)
    endTime = time_ns()
    # TODO: Save and Display theese times for benchmarks.    
    ccputime = (endTime-startTime)/1000000.0

    return dependent
end


function _build(model::Model, oo::Tuple{SubjectDNA,ObserverDNA})::SubjectDNA
    subject::SubjectDNA = oo[1]
    observer::ObserverDNA = oo[2]

    @assert isUnbuilt(subject) "Subject is already built!"

    graph::DependentGraph = getGraph(model)

    # ? Build Subject - Observer connection.
    add!!(observer,subject)

    startTime = time_ns()
    # ? Build InsertionTopoSubgraph for Node.
    add!!(graph,subject)
    endTime = time_ns()
    # TODO: Save and Display theese times for benchmarks.
    ccputime = (endTime-startTime)/1000000.0

    return subject
end