using Base.Threads

struct WaitPool
    conditions::NTuple{32,Threads.Condition}

    function WaitPool()
        new(ntuple(_ -> Threads.Condition(ReentrantLock()), 32))
    end
end

_wait_pool_condition(pool::WaitPool, index::Int)::Threads.Condition = pool.conditions[mod1(index,32)]

function Base.wait(pool::WaitPool, node::GeometryPlotNode, index::Int, wait_value::NodeState)::Nothing
    c = _wait_pool_condition(pool, index)
    lock(c)
    try
        while (@atomic :monotonic node.state) == wait_value
            wait(c)
        end
    finally
        unlock(c)
    end
    return nothing
end

function Base.notify(pool::WaitPool, index::Int)::Nothing
    c = _wait_pool_condition(pool, index)
    lock(c)
    try
        notify(c)
    finally
        unlock(c)
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
    lock(rw.cond)
    try
        while rw.writer_active
            wait(rw.cond)
        end
        rw.readers += 1
    finally
        unlock(rw.cond)
    end
end

function unlock_read(rw::LockRW)
    lock(rw.cond)
    try
        rw.readers -= 1
        if rw.readers == 0
            notify(rw.cond; all=false)
        end
    finally
        unlock(rw.cond)
    end
end

function lock_write(rw::LockRW)
    lock(rw.cond)
    try
        while rw.readers[] > 0 || rw.writer_active[]
            wait(rw.cond)
        end
        rw.writer_active = true
    finally
        unlock(rw.cond)
    end
end

function unlock_write(rw::LockRW)
    lock(rw.cond)
    try
        rw.writer_active = false
        notify(rw.cond; all=true)
    finally
        unlock(rw.cond)
    end
end