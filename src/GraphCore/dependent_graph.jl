# ? ---------------------------------
# ! DependentGraph
# ? ---------------------------------

mutable struct DependentGraph <: DependentGraphDNA
    _dependentObjects::Vector{DependentDNA}

    function DependentGraph()
        new(Vector{DependentDNA}())
    end

end

_DependentGraph_(self::DependentGraphDNA)::DependentGraph = error("Missing \"_DependentGraph_\" func for type of \"$(typeof(self))\"!")
_DependentGraph_(self::DependentGraph)::DependentGraph = return self

# TODO: idotol valo fugges, timestep alapu osszefesulessel

function add!!(self::DependentGraphDNA,asset::T) where T<:DependentDNA
    
    graph = _DependentGraph_(self)
    assetDependent = _Dependent_(asset)

    for graphItem in graph._dependentObjects
        graphItemChain = getChain(graphItem)
        for assetParent in assetDependent._graphParents
            if (assetParent in dependentsOf(graphItemChain)) || assetParent === graphItem
                enchain!(graphItemChain,asset)
                break
            end
        end
    end
    
    push!(graph._dependentObjects,asset)
    assetDependent._graphID = length(graph._dependentObjects) + ID_LOWER_BOUND
end

function buildFromPlan!(plan::PlanDNA,graph::DependentGraphDNA)
    dependent = Plan2Dependent(plan)
    
    add!!(graph,dependent)
    _Plan_(plan)._dependent = dependent

    return dependent
end

function buildFromPlan!(plan::ObservedPlanDNA,graph::DependentGraphDNA,builder::ObserverBuilderDNA)
    observer = Plan2Observer(builder,plan)
    observed = Plan2Dependent(plan) 

    add!!(observer,observed)
    add!!(graph,observed)
    _Plan_(plan)._dependent = observed

    return (observer,observed)
end

function fetch(self::DependentGraphDNA,id::Integer)::DependentDNA
    graph = _DependentGraph_(self)
    return graph._dependentObjects[id - ID_LOWER_BOUND]
end

function to_string(self::DependentGraphDNA)
    graph = _DependentGraph_(self)
    outStr = ""

    for dependent in graph._dependentObjects
        outStr *= "$(to_string(dependent))\n"
    end

    outStr = outStr[1:end-1]

    return outStr
end