
# ? ---------------------------------
# ! CompletedCondition
# ? ---------------------------------


"""
Used for waiting on a node to be completed.
- Use Base.wait() to wait until completed.
- Use Base.notify() to wake waiters.
"""
mutable struct CompletedCondition
    _condition::Threads.Condition
    @atomic _completed::Bool

    function CompletedCondition()
        new(Threads.Condition(ReentrantLock()), false)
    end
end

isCompleted(self::CompletedCondition)::Bool = return @atomic self._completed

function reset!(self::CompletedCondition)
    @atomic self._completed = false
end

function Base.wait(self::CompletedCondition)
    if !(@atomic self._completed)
        lock(self._condition)
        while !(@atomic self._completed)
            wait(self._condition)
        end
        unlock(self._condition)
    end
end

function Base.notify(self::CompletedCondition)
    lock(self._condition)
    @atomic self._completed = true
    notify(self._condition)
    unlock(self._condition)
end