
# ? ---------------------------------
# ! SyncFood
# ? ---------------------------------

struct SyncFood
    subject::SubjectDNA
    syncedIdx::Int
end

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _internal::Queue{SubjectDNA} = Queue{SubjectDNA}()
    _external::Channel{SyncFood} = Channel{SyncFood}(8192)
    _taken::Int = 0
end

Base.put!(self::Synchronizer, subject::SubjectDNA) = push!(self._internal, subject)
Base.put!(self::Synchronizer, f::SyncFood) = put!(self._external, f)

