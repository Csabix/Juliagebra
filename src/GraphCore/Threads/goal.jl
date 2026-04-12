
# ? ---------------------------------
# ! Goal
# ? ---------------------------------

mutable struct Goal
    @atomic _count::Int
    _goal::Int

    function Goal()
        new(0,0)
    end
end

function isReached(self::Goal)::Bool
    count = @atomic self._count
    return count == self._goal
end

function increment(self::Goal)
    @atomic self._count += 1
end

function reset!(self::Goal, goal::Int)
    @atomic self._count = 0
    self._goal = goal
end

function Base.string(self::Goal)::String
    count = @atomic self._count
    return "$(count)/$(goal)"
end