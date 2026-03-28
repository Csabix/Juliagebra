
# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

mutable struct PointDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D 

    # YELLOW Thread
    function PointDependent(callback::Function,dependents::Vector{<:DependentDNA})
        renderedDependent = RenderedDependent(callback,dependents)
        coord = Vec3DNan
        new(renderedDependent,coord)
    end
end

_RenderedDependent_(self::PointDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointDependent) = "Point[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

# YELLOW Thread
# RED Thread
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

mutable struct PointRenderer <:RendererDNA{PointDependent}
    _renderer::Renderer{PointDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _buffer::BufferArray
    
    _coords::Vector{Vec3F}
    _ids::Vector{Float32}

    # GREEN Thread
    function PointRenderer(context::OpenGLData) 
        shader_id = ShaderProgram(["point/point_id.vert","point/point_id.frag"],["VP"])
        shader_opaque = ShaderProgram(["point/point.vert","point/point.frag"],["VP","selectedID","pickedID","lightDirSideView"])
        renderer = Renderer{PointDependent}(context)

        buffer = BufferArray{Tuple{Vec3F,Float32}}(MappedBuffer,Buffer)
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

# GREEN Thread
function added!(self::PointRenderer,point::PointDependent)
    aID = Float32(getGraphID(point) + ID_LOWER_BOUND)
    coord = point._coord
    
    push!(self._coords,Vec3F(coord))
    push!(self._ids,Float32(aID))
end

# GREEN Thread
function addedAll!(self::PointRenderer)
    upload!(self._buffer,1,self._coords,0)
    upload!(self._buffer,2,self._ids,0)
end

# GREEN Thread
function sync!(self::PointRenderer,point::PointDependent)
    id = getObserverID(point)
    coord = point._coord

    self._coords[id] = Vec3F(coord)
end

# GREEN Thread
function syncAll!(self::PointRenderer)
    @time_cpu_begin Dependent Point
    wait(self._buffer[1])
    copyto!(self._buffer[1],self._coords)
    @time_cpu_end Dependent Point
end

function id_pass!(self::PointRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._shader_id)
    uniform(self._shader_id,"VP",vp)
    @time_gpu_begin Dependent Point ID_PASS
    draw(self._buffer,GL_POINTS)
    @time_gpu_end Dependent Point ID_PASS
    return nothing
end

function opaque_pass!(self::PointRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (_, view, _) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    activate(self._shader_opaque)
    uniform(self._shader_opaque,"VP",vp)
    uniform(self._shader_opaque,"selectedID",shrd._selectedID)
    uniform(self._shader_opaque,"pickedID",shrd._pickedID)
    uniform(self._shader_opaque,"lightDirSideView", view[1:3,1:3] * side_light)
    @time_gpu_begin Dependent Point OPAQUE_PASS
    draw(self._buffer,GL_POINTS)
    @time_gpu_end Dependent Point OPAQUE_PASS
    lock(self._buffer[1])
    return nothing
end

is_occluder(self::PointRenderer)::Bool = false

# GREEN Thread
function destroy!(self::PointRenderer) 
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._buffer)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointDependent) = getOpenGL(app)._renderers[4]

# ? ---------------------------------
# ! Point
# ? ---------------------------------

# YELLOW Thread
Point(x::Real,y::Real,z::Real)::PointDependent =
build!(PointDependent(() -> (return Vec3D(x,y,z)),Vector{DependentDNA}()))

# YELLOW Thread
Point(callback::Function,dependents::Vector{<:DependentDNA}) = 
build!(PointDependent(callback,dependents))

# YELLOW Thread
macro Point(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point)
end

export Point
export @Point
