using Base.Threads

struct WaitPool
    conditions::NTuple{32,Threads.Condition}

    function WaitPool()
        new(ntuple(_ -> Threads.Condition(ReentrantLock()), 32))
    end
end

_wait_pool_condition(pool::WaitPool, index::Int)::Threads.Condition = pool.conditions[mod1(index,32)]

function Base.wait(pool::WaitPool, node::GeometryPlotNode, index::Int)::Nothing
    c = _wait_pool_condition(pool, index)
    @lock c begin
        while (@atomic :acquire node.state) != NODE_VALID
            wait(c)
        end
    end
    return nothing
end

function Base.notify(pool::WaitPool, index::Int)::Nothing
    c = _wait_pool_condition(pool, index)
    @lock c begin
        notify(c)
    end
    return nothing
end

using Base.Threads

@kwdef mutable struct LockRW
    cond::Threads.Condition = Threads.Condition(ReentrantLock())
    readers::Int = 0
    writer_active::Bool = false
end

function lock_read(rw::LockRW)
    @lock rw.cond begin
        while rw.writer_active
            wait(rw.cond)
        end
        rw.readers += 1
    end
end

function unlock_read(rw::LockRW)
    @lock rw.cond begin
        rw.readers -= 1
        if rw.readers == 0
            notify(rw.cond; all=false)
        end
    end
end

function lock_write(rw::LockRW)
    @lock rw.cond begin
        while rw.readers > 0 || rw.writer_active
            wait(rw.cond)
        end
        rw.writer_active = true
    end
end

function unlock_write(rw::LockRW)
    @lock rw.cond begin
        rw.writer_active = false
        notify(rw.cond; all=true)
    end
end