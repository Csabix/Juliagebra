
# ? ---------------------------------
# ! SynchronizerState
# ? ---------------------------------

abstract type SynchronizerState end

struct Viewing <: SynchronizerState end
struct Constructing <: SynchronizerState end
struct Adding <: SynchronizerState end
struct Evaluating <: SynchronizerState end

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

mutable struct Synchronizer
    _appState::SynchronizerState
    _ConstructorAirLock::AirLock
    
    function Synchronizer()
        appState = Constructing()
        ConstructorAirLock = AirLock()
        new(appState,ConstructorAirLock)
    end
end

getState(self::Synchronizer)::SynchronizerState = return self._appState

function decideState(app::AppDNA)
    self = getSynchronizer(app)
    
    # ? Check the Current AirLock state:
    ConstructorAirLockState::AirLockStates = getAirLockState(self._ConstructorAirLock)
    
    if (ConstructorAirLockState === AtExit())
        #println("AtExit1")
        builder = getBuilder(app)
        #println("AtExit2")
        recentlyBuilt = getRecentlyBuilt(builder)
        #println("AtExit3")
        observer = getObserver(recentlyBuilt)
        #println("AtExit4")

        # ? Call added events for recently built
        # ! Only works for Observed Dependents
        
        #println("AtExit5 $(typeof(observer)) - $(typeof(recentlyBuilt))")
        added!(observer,recentlyBuilt)
        
        #println("AtExit6")
        setRenderedID!(observer,recentlyBuilt,getGraphID(recentlyBuilt) + ID_LOWER_BOUND)

        #println("AtExit7 $(typeof(observer))")
        addedAll!(observer)
    end

    # ? Let the AirLock work, based on the checked state:
    outsideAirLockProtocol(self._ConstructorAirLock,ConstructorAirLockState)
    #return ConstructorStateDecide(self,ConstructorAirLockState)
    return ConstructorAirLockState
end

function ConstructorStateDecide(self::Synchronizer,::AtExit)
    self._appState = Adding()
end

function ConstructorStateDecide(self::Synchronizer,::AtEntrance)
    self._appState = Constructing()
end

function ConstructorStateDecide(self::Synchronizer,::ThreadInside)
    self._appState = Constructing()
end

function ConstructorStateDecide(self::Synchronizer,::NoThreadsWaiting)
    self._appState = Viewing()
end
