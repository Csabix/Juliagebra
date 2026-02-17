
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
        appState = Viewing()
        ConstructorAirLock = AirLock()
        new(appState,ConstructorAirLock)
    end
end

getState(self::Synchronizer)::SynchronizerState = return self._appState

function decideState(self::Synchronizer)
    ConstructorState = getAirLockState(self._ConstructorAirLock)
    outsideAirLockProtocol(self._ConstructorAirLock,ConstructorState)
    ConstructorStateDecide(self,ConstructorState)
end

function ConstructorStateDecide(self::Synchronizer,::AtExit)
    self._appState = Adding
end

function ConstructorStateDecide(self::Synchronizer,::AtEntrance)
    self._appState = Constructing
end

function ConstructorStateDecide(self::Synchronizer,::ThreadInside)
    self._appState = Constructing
end

function ConstructorStateDecide(self::Synchronizer,::NoThreadsAtEntrance)
    self._appState = Viewing
end
