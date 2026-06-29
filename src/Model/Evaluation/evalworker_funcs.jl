
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
    @invokelatest _process2(d)
end

function _process1(self::EvalWorker0, model::Model, s::SubjectDNA)
    @invokelatest _process2(s)
    put!(getSynchronizer(model),s)
end

function _process2(dependent::DependentDNA)
    beforeNodeEval(dependent)
    onNodeEval(dependent)
    afterNodeEval(dependent)
end

# ? ---------------------------------
# ! Workeri
# ? ---------------------------------

function processUntilClosed!(self::EvalWorkeri, model::Model)
    for _ in self._signals # ? signal is always true
        
        for graphID in self._ids
            node::DependentDNA = getDependentNode(model,graphID)
            
            for parent in getGraphParents(node) 
                # ? Wait for parent to be completed. 
                parent_cond::CompletedCondition = get_evaledcond(parent)
                wait(parent_cond)
            end

            # ? Eval the node.
            startTime = time_ns()
            eval_node!(self, model, node)
            pushEndTime!(self, getGraphID(getDependent(food)), startTime)
        end
    end

    println("ThreadID($(Threads.threadid())): EvalWorkeri Ended!")
end

function eval_node!(::EvalWorkeri, model::Model, node::DependentDNA)
    @invokelatest _process2(node)
    notify(get_evaledcond(node))
    increment(getScheduler(model)._evaledGoal)
end

function eval_node!(::EvalWorkeri, model::Model, node::SubjectDNA)
    @invokelatest _process2(node)
    notify(get_evaledcond(node))
    increment(getScheduler(model)._evaledGoal)

    # ? Send Subject to Synchronizer.
    put!(getSynchronizer(model),node)
end

