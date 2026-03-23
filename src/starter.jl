
# ? ---------------------------------
# ! Initializer
# ? ---------------------------------

mutable struct Starter
    _condition::Threads.Condition
    @atomic _started::Bool

    function Starter()
        condition = Threads.Condition(ReentrantLock())
        started = false
        new(condition,started)
    end
end

isStarted(self::Starter)::Bool = return @atomic self._started

function Base.wait(self::Starter)
    lock(self._condition)
    while (!isStarted(self))
        wait(self._condition)
    end
    unlock(self._condition)
end

function Base.notify(self::Starter)
    lock(self._condition)
    @atomic self._started = true
    notify(self._condition)
    unlock(self._condition)
end

function startOpengl(app::AppDNA)
    play!(app)
    println("ThreadID($(Threads.threadid())): App Ended!")
end

function startApp(app::AppDNA)
    task = ThreadPinning.@spawnat 1 begin
        startOpengl(app)
    end
    errormonitor(task)

    wait(getStarter(app))
    
    return task
end

