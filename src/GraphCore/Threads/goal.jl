
# ? ---------------------------------
# ! Goal
# ? ---------------------------------

@kwdef mutable struct Goal
    _count::Int = 0
    _goal::Int = 0
end

isReached(self::Goal)::Bool = return self._count == self._goal


increment(self::Goal) = self._count += 1

function reset!(self::Goal, goal::Int)
    self._count = 0
    self._goal = goal
end

Base.string(self::Goal)::String = return "$(self._count)/$(self._goal)"


# ? ---------------------------------
# ! AtomicGoal
# ? ---------------------------------

mutable struct AtomicGoal
    _condition::Threads.Condition
    @atomic _count::Int
    _goal::Int

    function AtomicGoal()
        new(Threads.Condition(ReentrantLock()),0,0)
    end
end

function isReached(self::AtomicGoal)::Bool
    count = @atomic self._count
    return count == self._goal
end

function increment(self::AtomicGoal)
    result = @atomic self._count += 1
    if result == self._goal
        lock(self._condition)
        notify(self._condition)
        unlock(self._condition)
    end
end

function Base.wait(self::AtomicGoal)
    if !(isReached(self))
        lock(self._condition)
        while !(isReached(self))
            wait(self._condition)
        end
        unlock(self._condition)
    end
end

function reset!(self::AtomicGoal, goal::Int)
    @atomic self._count = 0
    self._goal = goal
end

function Base.string(self::AtomicGoal)::String
    count = @atomic self._count
    return "$(count)/$(self._goal)"
end