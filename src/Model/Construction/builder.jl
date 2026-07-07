
# ? ---------------------------------
# ! Builder
# ? ---------------------------------

const BUILDER_IN_CHANNEL_SIZE = 8192
const _BuilderT = Union{DependentDNA,Tuple{SubjectDNA,ObserverDNA}}

"""
Builds un-built non-main-thread parts of Dependents.
- Calculates data pararell to script/jupyter notebook/repl.
- Forwards nodes to Adder.
"""
@kwdef mutable struct Builder
    _in::Channel{_BuilderT} = Channel{_BuilderT}(BUILDER_IN_CHANNEL_SIZE)
    _lock::ReentrantLock = ReentrantLock()
    _model_has_lock::Bool = false
end

destroy!(self::Builder) = close(self._in)
Base.put!(self::Builder,node::_BuilderT) = put!(self._in,node)
Base.lock(self::Builder) = lock(self._lock)
Base.lock(f::Function, self::Builder) = lock(f,self._lock)
Base.unlock(self::Builder) = unlock(self._lock)
Base.trylock(self::Builder)::Bool = return trylock(self._lock)
islocked_by_model(self::Builder)::Bool = return self._model_has_lock
trylock_by_model(self::Builder)::Bool = trylock(self._lock) ? (self._model_has_lock=true ; return true) : return false
unlock_by_model(self::Builder) = (self._model_has_lock=false ; unlock(self._lock) )

