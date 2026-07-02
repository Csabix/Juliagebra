
# ? ---------------------------------
# ! Worker0
# ? ---------------------------------

function processUntilClosed!(self::EvalWorker0, model::Model)
    Base.resize!(self._processedIDs,0)
    Base.resize!(self._processedTimes,0)
    taken = length(self)

    for _ in 1:taken
        startTime = time_ns()
        
        nodeid::Int = take!(self)
        node::DependentDNA = getDependentNode(model,nodeid)
        _process1(self, model, node)

        pushEndTime!(self, nodeid, startTime)
    end
end

function _process1(::EvalWorker0, ::Model, d::DependentDNA)    
    @invokelatest node_eval!(d)
end

function _process1(self::EvalWorker0, model::Model, s::SubjectDNA)
    @invokelatest node_eval!(s)
    id::Int = getGraphID(s)
    put_as_w0!(getSynchronizer(model),id)
end

# ? ---------------------------------
# ! Workeri
# ? ---------------------------------

function process_until_closed!(self::EvalWorkeri, model::Model)
    for _ in self._signals # ? signal is always true
        for graphID in self._ids
            node::DependentDNA = getDependentNode(model,graphID)
            
            for parent in getGraphParents(node) 
                # ? Wait for parent to be completed. 
                wait(get_evaledcond(parent))
            end

            # ? Eval the node.
            startTime = time_ns()
            eval_node!(self, model, node)
            pushEndTime!(self, graphID, startTime)
        end
    end

    println("ThreadID($(Threads.threadid())): EvalWorkeri Ended!")
end

function eval_node!(::EvalWorkeri, model::Model, node::DependentDNA)
    @invokelatest node_eval!(node)
    notify(get_evaledcond(node))
    increment(getScheduler(model)._evalgoal)
end

function eval_node!(::EvalWorkeri, model::Model, node::SubjectDNA)
    @invokelatest node_eval!(node)
    notify(get_evaledcond(node))
    increment(getScheduler(model)._evalgoal)

    # ? Send Subject to Synchronizer.
    put_as_wi!(getSynchronizer(model), getGraphID(node))
end

