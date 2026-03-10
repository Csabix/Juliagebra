
# ? ---------------------------------
# ! PointDependent
# ? ---------------------------------

mutable struct PointDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coord::Vec3D 

    # BLUE Thread
    function PointDependent(callback::Function,dependents::Vector{<:DependentDNA})
        renderedDependent = RenderedDependent(callback,dependents)
        coord = Vec3DNan
        new(renderedDependent,coord)
    end
end

_RenderedDependent_(self::PointDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointDependent) = "Point[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

function set(self::PointDependent,x::Float64,y::Float64,z::Float64)
    self._coord = Vec3D(x,y,z)
    evalGraph(self)
end

# BLUE Thread
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
    _buffer::TypedBufferArray    
    
    _coords::Vector{Vec3F}
    _ids::Vector{Float32}

    # GREEN Thread
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

# GREEN Thread
function added!(self::PointRenderer,point::PointDependent)
    aID = Float32(getGraphID(point) + ID_LOWER_BOUND)
    coord = point._coord
    
    push!(self._coords,Vec3F(coord))
    push!(self._ids,Float32(aID))
end

# GREEN Thread
function addedAll!(self::PointRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._ids,GL_STATIC_DRAW)
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
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    @time_cpu_end Dependent Point
    #@log "Uploaded Coordinate buffer!" INFO
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

# GREEN Thread
function destroy!(self::PointRenderer) 
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._buffer)
end

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

export Point
