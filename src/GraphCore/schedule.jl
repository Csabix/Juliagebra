
# ? ---------------------------------
# ! Schedule
# ? ---------------------------------

@kwdef mutable struct Schedule
    _vec::Vector{DependentDNA} = Vector{DependentDNA}()
end

Base.length(self::Schedule) = return length(self._vec)
Base.getindex(self::Schedule, idx::Int) = return self._vec[idx]
Base.iterate(self::Schedule, state=1) = state<=length(self) ? (return (self._vec[state],state+1)) : (return nothing)

function enchain!(self::Schedule,item::DependentDNA)
    @assert (length(self)>0) ? (getGraphID(item)>getGraphID(self._vec[end])) : true "IDs must be increasing!"
    push!(self._vec,item)
end

function enchain!(self::Schedule,item::SubjectDNA)
    observer = _Subject_(item)._observer
    @assert !isnothing(observer) "Observer of Subject can't be nothing!"
    @assert (length(self)>0) ? (getGraphID(item)>getGraphID(self._vec[end])) : true "IDs must be increasing!"
    push!(self._vec,item)
end

dependentsOf(self::Schedule) = return self._vec

function evalChain(self::Schedule)
    @invokelatest _evalChain(self)
end

function _evalChain(self::Schedule)
    for item in dependentsOf(self)
        beforeNodeEval(item)
        onNodeEval(item)
        afterNodeEval(item)
    end
    
    #for item in observersOf(self)
    #    postGraphEval(item)
    #end 
end

function Base.merge(s1::Schedule, s2::Schedule)::Schedule
    s = Schedule()
    idx1 = 1
    idx2 = 1
    len1 = length(s1)
    len2 = length(s2)

    while (idx1<=len1) && (idx2<=len2)        
        d1 = s1[idx1]
        d2 = s2[idx2]
        id1 = getGraphID(d1)
        id2 = getGraphID(d2)
        
        if (id1 < id2)
            enchain!(s,d1)
            idx1+=1
        elseif (id1 > id2)
            enchain!(s,d2)
            idx2+=1
        else # ? id1 == id2
            @assert d1 === d2 "Equal id must mean same Dependent!"
            enchain!(s,d1)
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

