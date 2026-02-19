
# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

mutable struct PointDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D 

    function PointDependent(callback::Function,dependents::Vector{<:DependentDNA},xyz::Vec3D)
        a = RenderedDependent(plan)
        coord = xyz
        new(a,coord)
    end
end

getX(self::PointDependent) = return self._coord.x
getY(self::PointDependent) = return self._coord.y
getZ(self::PointDependent) = return self._coord.z
getCoord(self::PointDependent) = return self._coord

_RenderedDependent_(self::PointDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointDependent) = "Point[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

function set(self::PointDependent,x::Float64,y::Float64,z::Float64)
    self._coord = Vec3D(x,y,z)
    evalGraph(self)
end


onNodeEval(self::PointDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::PointDependent)::Vec3D = self._coord

evalCallbackDpReturn(self::PointDependent,value) = self._coord = Vec3D(value)
evalCallbackDpReturn(self::PointDependent,value::Tuple) = self._coord = Vec3D(value...)
evalCallbackDpReturn(self::PointDependent,value::Vector) = self._coord = Vec3D(value...)
evalCallbackDpReturn(self::PointDependent,value::Vec3F) = self._coord = Vec3D(value)
evalCallbackDpReturn(self::PointDependent,value::Vec3D) = self._coord = value
evalCallbackDpReturn(self::PointDependent,::Nothing) = self._coord = Vec3DNan

# ? ---------------------------------
# ! PointRenderer
# ? ---------------------------------

# ? Now we can move on to creating a renderer, which uses GPU resources to render RenderedDependents.
mutable struct PointRenderer <:RendererDNA{PointDependent}
    _renderer::Renderer{PointDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _buffer::TypedBufferArray    
    
    _coords::Vector{Vec3F}
    _ids::Vector{Float32}
    
    function PointRenderer(context::OpenGLData) 
        shader_id = ShaderProgram(sp("./point/point_id.vert"), sp("./point/point_id.frag"),["VP"])
        shader_opaque = ShaderProgram(sp("./point/point.vert"), sp("./point/point.frag"),["VP","selectedID","pickedID","lightDirSideView"])
        renderer = Renderer{PointDependent}(context)

        buffer = TypedBufferArray{Tuple{Vec3F,Float32}}()
        coords = Vector{Vec3F}()
        ids    = Vector{Float32}()

        new(
            renderer,
            shader_id,shader_opaque,
            buffer,
            coords,
            ids)
    end
end

_Renderer_(self::PointRenderer) = return self._renderer
Base.string(self::PointRenderer) = return "PointRenderer($(length(self._ids)))"

function setRenderedID!(self::PointRenderer,item::PointDependent,id)
    self._ids[getObserverID(item)] = Float32(id)
end

# ? We need a function, which gets called, when a Dependent is assigned to this renderer.
# ? this "added!" function gets called every time a dependent is added.
# ? The function should be used to copy data to CPU datastructures used for GPU parsing.
# ! Must have
function added!(self::PointRenderer,point::PointDependent)
    onNodeEval(point)
    
    aID = 0
    coord = point._coord

    push!(self._coords,Vec3F(coord))
    push!(self._ids,Float32(aID))
end

# ? This function gets called if there was at least 1 or more Dependent which got assigned to this Renderer.
# ? Actual Data Transfer to GPU VRAM should happen here.
# ! Must have
function addedAll!(self::PointRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._ids,GL_STATIC_DRAW)
end

# ? "sync!" is very much like "added!", but gets called when a Dependent was "flag!"-ed.
# ? So the function is used to copy Dependent data into CPU datastructures. 
# ? The function is called only once after change happens in that frame for every changed Dependent.
# ! Must have
function sync!(self::PointRenderer,point::PointDependent)
    id = getObserverID(point)
    coord = point._coord

    self._coords[id] = Vec3F(coord)
end

# ? "syncUpload!" is much like "addedUpload!", where it gets called only once per frame for every dependent,
# ? but when 1 or more "flag!" happens
# ? Actual CPU to GPU data transfer happens here.
# ! Must have
function syncAll!(self::PointRenderer)
    @time_cpu_begin Dependent Point
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    @time_cpu_end Dependent Point
    @log "Uploaded Coordinate buffer!" INFO
end

function id_pass!(self::PointRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._shader_id)
    setUniform!(self._shader_id,"VP",vp)
    @time_gpu_begin Dependent Point ID_PASS
    draw(self._buffer,GL_POINTS)
    @time_gpu_end Dependent Point ID_PASS
    return nothing
end

function opaque_pass!(self::PointRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (_, view, _) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    activate(self._shader_opaque)
    setUniform!(self._shader_opaque,"VP",vp)
    setUniform!(self._shader_opaque,"selectedID",shrd._selectedID)
    setUniform!(self._shader_opaque,"pickedID",shrd._pickedID)
    setUniform!(self._shader_opaque,"lightDirSideView", view[1:3,1:3] * side_light)
    @time_gpu_begin Dependent Point OPAQUE_PASS
    draw(self._buffer,GL_POINTS)
    @time_gpu_end Dependent Point OPAQUE_PASS
    return nothing
end

is_occluder(self::PointRenderer)::Bool = false

# ? Free GPU resources here.
# ! Must have
function destroy!(self::PointRenderer) 
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
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
function Plan2Observer(self::OpenGLData,::PointDependent)
    return SingleRendererTactic(self,_POINT_RENDERER,PointRenderer)::PointRenderer
end

# ? Of course, in the case of renderers using views passed to Dependents is a very fast way to handee things,
# ? for that, see examples in the "curve.jl" and "surface.jl" files.

# ? ---------------------------------
# ! Point
# ? ---------------------------------

function _Point(;
                _app::AppDNA = implicitApp,
                _call::Function = DEFAULT_CALLBACK,
                _deps::DependentsT = Vector{PlanDNA}(),
                _x = 0,
                _y = 0,
                _z = 0,
                )::PointDependent
    
    if (_call === DEFAULT_CALLBACK)
        _call = () -> (return Vec3D(_x,_y,_z))
    end
                
    plan = PointPlan(_call,_deps,_x,_y,_z)
    submit!(_app,plan)
    return plan
end

function Point(x::Real,y::Real,z::Real)
    println("Here1")
    return build!(PointDependent; data=Tuple([Vec3D(x,y,z)]))
end

Point(callback::Function,dependents::Vector) = 
build!(PointDependent; callback=callback, dependents=dependents, data=Tuple([Vec3DNan]))
