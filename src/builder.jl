
const DEFAULT_CALLBACK_FUNC() = return nothing
const DEFAULT_DEPENDENTS = Vector{DependentDNA}()

# ? ---------------------------------
# ! Builder
# ? ---------------------------------

mutable struct Builder
    _recentlyBuilt::Union{DependentDNA,Nothing}

    function Builder()
        new(nothing)
    end
end

getRecentlyBuilt(self::Builder) = return self._recentlyBuilt

function build!(::Type{T};
    app::AppDNA = implicitApp,
    callback::Function = DEFAULT_CALLBACK_FUNC,
    dependents::Vector{<:DependentDNA} = DEFAULT_DEPENDENTS,
    data::Tuple = Tuple([]),
    data_named::NamedTuple = NamedTuple()
    ) where {T<:DependentDNA}

    local dependent::T

    al = getSynchronizer(app)._ConstructorAirLock
    self = getBuilder(app)
    insideAirLockProtocol(al) do 
        #println("Constructing: \"$(T)\"...")
        dependent = T(callback,dependents,data...;data_named...)
        _build(app,dependent)
        self._recentlyBuilt = dependent
        #println("Constructing Ended!")
    end

    return dependent
end

function _build(app::AppDNA,dependent::DependentDNA)
    graph = getGraph(app)
    add!!(graph,dependent)
end

function _build(app::AppDNA,observed::ObservedDNA)
    graph = getGraph(app)
    observer = getObserverFrom(app,observed)

    add!!(observer,observed)
    add!!(graph,observed)
    
    return observed
end

function _build(app::AppDNA, rendered::RenderedDependentDNA)
    graph = getGraph(app)
    renderer = getObserverFrom(app,rendered)

    add!!(renderer,rendered)
    add!!(graph,rendered)
    #setRenderedID!(renderer,rendered,getGraphID(rendered) + ID_LOWER_BOUND)
    
    return rendered
end

getObserverFrom(app::AppDNA,rendered::RenderedDependentDNA) = return Plan2Observer(getOpenGL(app),rendered)
getObserverFrom(app::AppDNA,rendered::GuiDependentDNA) = return Plan2Observer(getImGui(app),rendered)
