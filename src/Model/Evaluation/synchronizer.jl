
# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _w0_nodes::Queue{SubjectDNA} = Queue{SubjectDNA}()
    _wi_nodes::Channel{SubjectDNA} = Channel{SubjectDNA}(8192)
    _taken::Int = 0
end

put_as_w0(self::Synchronizer, subject::SubjectDNA) = push!(self._w0_nodes, subject)
put_as_wi(self::Synchronizer, subject::SubjectDNA) = put!(self._wi_nodes, subject)

