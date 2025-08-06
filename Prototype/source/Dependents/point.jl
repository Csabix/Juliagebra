# ? This file contains the code of the Point Dependable.
# ? It is a very good starting point to understand how one can create
# ? a Dependent, which is Rendered.

# ? ---------------------------------
# ! PointPlan
# ? ---------------------------------

# ? Firstly, for creating a Dependent, we have to design a Plan for it.
# ? The main purpose of a Plan is, to have an objects, which is in the memory space, of the
# ? user's script.
# ? Also, the data, which is required for constructing a dependent should go here.
# ? A Plan for a Rendered Dependentent must inherit from RenderedPlanDNA.
mutable struct PointPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    
    _x::Float64
    _y::Float64
    _z::Float64
    

    function PointPlan(callback::Function,plans::Vector{T},x,y,z) where {T<:PlanDNA}
        new(RenderedPlan(callback,plans),
            x,y,z)
    end
end

# ? To complete the DNA inheritance, we need to define the acces for the compositional RenderedPlan struct in
# ? the "_RenderedPlan_" function.
_RenderedPlan_(self::PointPlan)::RenderedPlan = return self._plan
Base.string(self::PointPlan)::String = return "PointPlan[$(string(length(self._plans)))] -> $(string(_Plan_(self)._dependent))"

# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

# ? After we've defined a Plan, we need the Dependent itself.
# ? Since it's a rendered dependent, it should inherit from RenderedDependentDNA.
mutable struct PointDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _x::Float64
    _y::Float64
    _z::Float64    

    function PointDependent(plan::PointPlan)
        a = RenderedDependent(plan)
        x = plan._x
        y = plan._y
        z = plan._z
        new(a,x,y,z)
    end
end


# ? Every Dependent needs a "Plan2Dependent" function, which connects the above defined Dependent to the
# ? Plan We've defined at the beggining of the file. The function must be able to construct a Dependent from a Plan.
# ! Must have
function Plan2Dependent(plan::PointPlan)::PointDependent
    return PointDependent(plan)
end

_RenderedDependent_(self::PointDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointDependent) = "Point[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

function set(self::PointDependent,x::Float64,y::Float64,z::Float64)
    self._x = x
    self._y = y
    self._z = z
    
    flag!(self)
    
    evalGraph(self)

end

# ? Below are some fancy getter functions, enabling the "[:xyz]" syntax and so on.

getPointField(self::PointDependent,fieldVal) = error("Unrecognized Symbol for Point's field!")

getPointField(self::PointDependent,fieldVal::Val{:x}) = return self._x
getPointField(self::PointDependent,fieldVal::Val{:y}) = return self._y
getPointField(self::PointDependent,fieldVal::Val{:z}) = return self._z

getPointField(self::PointDependent,fieldVal::Val{:xyz}) = return (self._x,self._y,self._z)

Base.getindex(self::PointDependent,fieldSymbol::Symbol) = return getPointField(self,Val(fieldSymbol))

function Base.getindex(self::PointDependent,fieldSymbols...)
    
    fieldValues = []

    for fieldSymbol in fieldSymbols
        push!(fieldValues,self[fieldSymbol])
    end

    return tuple(fieldValues...)
end

# ? Now we need to define, how the Dependent should act, when everything it depends on changes.
# ? Note that for every Dependent, the "onGraphEval" only gets called once and in a way, where everything
# ? it depends on is up-to date.
# ? Since Point is a Dependent, for it to be able to depend on other objects, we have to define
# ? what will it do, when it should be evaluated in the graph, that's what
# ? "onGraphEval" does.
# ? dpEvalCallback is a helper function brought from DependentDNA, which helps dispatching on evaluating the callback function.
# ! Must have
onGraphEval(self::PointDependent) = dpEvalCallback(self)

# ? So for a Point we want to evaluate the User's callback once, then dispatch on the returned value
# ? (this is why "onGraphEval" is just a call to dpEvalCallback).
# ? now we must define how, with what parameters should the callback be called, and what modifications
# ? (in this case nothing) we should do on the return, before dispatching onto it.
function evalCallback(self::PointDependent)
    return _Dependent_(self)._callback(_Dependent_(self)._graphParents...)
end

# ? if "dpCallbackReturn" is defined for input types, then the returned value of "evalCallback" will be sipatched into this
# ? function, as the name suggests.
function dpCallbackReturn(self::PointDependent,v)
    x,y,z = v
    self._x = Float64(x)
    self._y = Float64(y)
    self._z = Float64(z)
    
    # ! flag should always be called, when data in RenderedDependents change, so that the Renderer
    # ! assigned to this dependent knows, to update data on the GPU.
    flag!(self)
end

function dpCallbackReturn(self::PointDependent,::Nothing)
    
    self._x = NaN64
    self._y = NaN64
    self._z = NaN64
    
    flag!(self)
end

# ? Note that fancier callback evaluation can be seen in other Dependents than Point, that is why this system is needed.

# ? ---------------------------------
# ! PointRenderer
# ? ---------------------------------

# ? Now we can move on to creating a renderer, which uses GPU resources to render RenderedDependents.
mutable struct PointRenderer <:RendererDNA{PointDependent}
    _renderer::Renderer{PointDependent}

    _shader::ShaderProgram
    _buffer::TypedBufferArray    
    
    _coords::Vector{Vec3F}
    _ids::Vector{Float32}
    
    function PointRenderer(context::OpenGLData) 
        
        shader = ShaderProgram(sp("point.vert"),sp("point.frag"),["VP","selectedID","pickedID"])
        renderer = Renderer{PointDependent}(context)

        buffer = TypedBufferArray{Tuple{Vec3F,Float32}}()
        coords = Vector{Vec3F}()
        ids    = Vector{Float32}()

        new(
            renderer,
            shader,
            buffer,
            coords,
            ids)
    end
end

_Renderer_(self::PointRenderer) = return self._renderer
Base.string(self::PointRenderer) = return "PointRenderer($(length(self._ids)))"

# ? We need a function, which gets called, when a Dependent is assigned to this renderer.
# ? this "added!" function gets called every time a dependent is added.
# ? The function should be used to copy data to CPU datastructures used for GPU parsing.
# ! Must have
function added!(self::PointRenderer,point::PointDependent)
    aID = _Dependent_(point)._graphID

    x = point._x
    y = point._y
    z = point._z

    push!(self._coords,Vec3F(x,y,z))
    push!(self._ids,Float32(aID))

    println("Added point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(_RenderedDependent_(point)._rendererID)\taID: $(aID)")
end

# ? This function gets called if there was at least 1 or more Dependent which got assigned to this Renderer.
# ? Actual Data Transfer to GPU VRAM should happen here.
# ! Must have
function addedUpload!(self::PointRenderer)
    upload!(self._buffer,2,self._ids,GL_STATIC_DRAW)
    println("Uploaded ID buffer!")
end

# ? "sync!" is very much like "added!", but gets called when a Dependent was "flag!"-ed.
# ? So the function is used to copy Dependent data into CPU datastructures. 
# ? The function is called only once after change happens in that frame for every changed Dependent.
# ! Must have
function sync!(self::PointRenderer,point::PointDependent)
    id = point._renderedDependent._rendererID
    x = point._x
    y = point._y
    z = point._z
    self._coords[id] = Vec3F(x,y,z)
    println("Synced point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(id)")
end

# ? "syncUpload!" is much like "addedUpload!", where it gets called only once per frame for every dependent,
# ? but when 1 or more "flag!" happens
# ? Actual CPU to GPU data transfer happens here.
# ! Must have
function syncUpload!(self::PointRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    println("Uploaded Coordinate buffer!")
end

# ? Function to specify how a Renderer should render.
# ? Gets called every frame no matter what happens or not. 
# ! Must have
function draw!(self::PointRenderer,vp,selectedID,pickedID,cam,shrd) 
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"selectedID",selectedID)
    setUniform!(self._shader,"pickedID",pickedID)
    draw(self._buffer,GL_POINTS)
end

# ? Free GPU resources here.
# ! Must have
function destroy!(self::PointRenderer) 
    destroy!(self._shader)
    destroy!(self._buffer)
end

# ? And finally, connect the plan to a rendered with a function, so the library knows
# ? which Plan is connected to which Dependent and Renderer, and thus
# ? which Renderer renders which Dependents.
# ? Here we can also specify, when a plan arrives, if we should create a new renderer to manage it,
# ? or use an existing one.
# ? "SingleRendererTactic" basically allows only 1 Renderer to manage every type of Dependent
# ? constructed from the incoming Plan. 
# ! Must have
function Plan2Renderer(self::OpenGLData,plan::PointPlan)
    return SingleRendererTactic(self,PointRenderer)
end

# ? Of course, in the case of renderers using views passed to Dependents is a very fast way to handee things,
# ? for that, see examples in the "curve.jl" and "surface.jl" files.