
# ? ---------------------------------
# ! InsertionTopoSubgraph
# ! OrderedTopoSubgraph
# ? ---------------------------------

@kwdef mutable struct Schedule
    _ids::Vector{Int} = Vector{Int}()
end

Base.length(self::Schedule) = return length(self._ids)
Base.getindex(self::Schedule, idx::Int)::Int = return self._ids[idx]
Base.iterate(self::Schedule, state=1) = state<=length(self) ? (return (self._ids[state],state+1)) : (return nothing)
get_ids(self::Schedule)::Vector{Int} = return self._ids
get_set(self::Schedule)::Set{Int} = return Set(self._ids)

function enchain!(self::Schedule, id::Int)
    @assert (length(self)>0) ? (id>self._ids[end]) : true "IDs must be increasing!"
    push!(self._ids,id)
end

function enchain!(self::Schedule, item::DependentDNA)
    id::Int = getGraphID(item)
    enchain!(self,id)
end

function Base.merge(s1::Schedule, s2::Schedule)::Schedule
    s = Schedule()
    idx1 = 1
    idx2 = 1
    len1 = length(s1)
    len2 = length(s2)

    while (idx1<=len1) && (idx2<=len2)        
        id1 = s1[idx1]
        id2 = s2[idx2]
        
        if (id1 < id2)
            enchain!(s,id1)
            idx1+=1
        elseif (id1 > id2)
            enchain!(s,id2)
            idx2+=1
        else # ? id1 == id2
            @assert id1 === id2 "IDs must be equal!"
            enchain!(s,id1)
            idx1+=1
            idx2+=1
        end
    end

    while (idx1<=len1)
        enchain!(s,s1[idx1])
        idx1+=1
    end 
        
    while (idx2<=len2)
        enchain!(s,s2[idx2])
        idx2+=1
    end

    return s
end

Base.merge(schedules::Vector{Schedule})::Schedule = return foldl(Base.merge,schedules)

