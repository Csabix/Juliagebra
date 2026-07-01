
# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _w0_nodeids::Queue{Int} = Queue{Int}()
    _wi_nodeids::Channel{Int} = Channel{Int}(8192)
    _observers::Set{ObserverDNA} = Set{ObserverDNA}()
    _taken::Int = 0
end

put_as_w0!(self::Synchronizer, subjectid::Int) = push!(self._w0_nodeids, subjectid)
put_as_wi!(self::Synchronizer, subjectid::Int) = put!(self._wi_nodeids, subjectid)

