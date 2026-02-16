
# ? ---------------------------------
# ! AirLockStates
# ? ---------------------------------

abstract type AirLockStates end

struct BeforeExitOpens <: AirLockStates end
struct AfterExitOpens <: AirLockStates end
struct BeforeEntranceOpens <: AirLockStates end
struct AfterEntranceOpens <: AirLockStates end
struct ThreadWorkingInside <: AirLockStates end
struct NoThreadsAtEntrance <: AirLockStates end

# ? ---------------------------------
# ! AirLock
# ? ---------------------------------

mutable struct AirLock
    _lock::ReentrantLock
    @atomic _entranceClosed::Bool   # ? false if opened, true if closed
    @atomic _entranceButton::Bool   # ? false if unpressed, true if pressed
    @atomic _exitClosed::Bool       # ? false if opened, true if closed
    @atomic _exitButton::Bool       # ? false if unpressed, true if pressed
    @atomic _hasThreadInside::Bool

    function AirLock()
        lock = ReentrantLock()
        entranceClosed = true 
        entranceButton = false
        
        exitClosed = false
        exitButton = true

        hasThreadInside = false

        new(lock,entranceClosed,entranceButton,exitClosed,exitButton,hasThreadInside)
    end
end

function wait4Entrance(self::AirLock)
    @atomic self._entranceButton = true
    while (@atomic self._entranceClosed) end
end

function wait4Exit(self::AirLock)
    @atomic self._exitButton = true
    while (@atomic self._exitClosed) end
end

function checkEntrance(self::AirLock)::Bool
    return @atomic self._entranceButton
end

function checkExit(self::AirLock)::Bool
    return @atomic self._exitButton
end

function openEntrance(self::AirLock)
    # ! close exit before letting other thread in.
    @atomic self._exitClosed = true
    # ! re-arm exit button before letting other thread in.
    @atomic self._exitButton = false
    # ! finally, open entrance.
    @atomic self._entranceClosed = false
end

function openExit(self::AirLock)
    # ! close entrance before letting other thread out.
    @atomic self._entranceClosed = true
    # ! re-arm entrance button before letting other thread out.
    @atomic self._entranceButton = false
    # ! finally, open exit.
    @atomic self._exitClosed = false
end

function getHasThreadInside(self::AirLock)::Bool
    return @atomic self._hasThreadInside
end

function insideAirLockProtocol(callback::Function, self::AirLock)
    lock(self._lock)
    wait4Entrance(self)
    @atomic self._hasThreadInside = true

    callback()

    wait4Exit(self)
    @atomic self._hasThreadInside = false
    unlock(self._lock)
end

function outsideAirLockProtocol(callback::Function, self::AirLock)
    # ? check if someone is inside the AirLock.
    if (getHasThreadInside(self))
        # ? check if someone is at the exit of the AirLock.
        if (checkExit(self))
            callback(BeforeExitOpens())
            openExit(self)
            callback(AfterExitOpens())
        else
            callback(ThreadWorkingInside())
        end
    # ? check if someone is at the entrance of the AirLock.
    elseif (checkEntrance(self))
        callback(BeforeEntranceOpens())
        openEntrance(self)
        callback(AfterEntranceOpens())
    else
        callback(NoThreadsAtEntrance())
    end
end