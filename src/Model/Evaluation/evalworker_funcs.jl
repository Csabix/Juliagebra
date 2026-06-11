
# ? ---------------------------------
# ! Worker0
# ? ---------------------------------

function processUntilClosed!(self::EvalWorker0, model::Model)
    Base.resize!(self._processedIDs,0)
    Base.resize!(self._processedTimes,0)
    taken = length(self)

    for _ in 1:taken
        startTime = time_ns()
        
        d::DependentDNA = take!(self)
        _process1(self, model, d)

        pushEndTime!(self, getGraphID(d), startTime)
    end
end

function _process1(self::EvalWorker0, ::Model, d::DependentDNA)    
    @invokelatest _process2(d)
end

function _process1(self::EvalWorker0, model::Model, o::SubjectDNA)
    @invokelatest _process2(o)
    put!(getSynchronizer(model),o)
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
    for foods in self._in
        Base.resize!(self._processedIDs,0)
        Base.resize!(self._processedTimes,0)
        
        for food in foods 
            conditions::Vector{CompletedCondition} = food.conditions

            # ? Wait for parents to be completed. 
            for c in conditions
                wait(c)
            end
            
            startTime = time_ns()
            
            _process1(self, model, food.evaled, food.data)
            
            pushEndTime!(self, getGraphID(getDependent(food)), startTime)
        end
    end

    println("ThreadID($(Threads.threadid())): EvalWorkeri Ended!")
end

function _process1(self::EvalWorkeri, model::Model, evaled::CompletedCondition, d::DependentDNA)
    @invokelatest _process2(d)
    notify(evaled)
    increment(getScheduler(model)._evaledGoal)
end

function _process1(self::EvalWorkeri, model::Model, evaled::CompletedCondition, data::SyncFood)
    o::SubjectDNA = data.subject

    @invokelatest _process2(o)
    notify(evaled)
    increment(getScheduler(model)._evaledGoal)

    put!(getSynchronizer(model),data)
end