
# ? ---------------------------------
# ! ParametricSurfaceDependent
# ? ---------------------------------

mutable struct ParametricSurfaceDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _uvValues::FlatMatrix{Vec3D}
    _uvNormals::FlatMatrix{Vec3D}
    _layer::Int

    _uRange::AbstractRange{Float64}
    _vRange::AbstractRange{Float64}

    _color::Vec3F
    _transparent::Bool

    # YELLOW Thread
    function ParametricSurfaceDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        uRange::AbstractRange{Float64},
        vRange::AbstractRange{Float64},
        color::Vec3F,
        transparent::Bool
        )

        rd = RenderedDependent(callback,dependents)
        uvValues = FlatMatrix{Vec3D}(length(uRange),length(vRange))        
        uvNormals = FlatMatrix{Vec3D}(length(uRange),length(vRange))

        new(rd,
            uvValues,
            uvNormals,
            0,
            uRange,
            vRange,
            color,transparent)
    end
end

_RenderedDependent_(self::ParametricSurfaceDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::ParametricSurfaceDependent) = return "ParametricSurface"

evalCallbackDpReturn(self::ParametricSurfaceDependent,value,u,v) = self._uvValues[u,v] = Vec3D(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Tuple,u,v) = self._uvValues[u,v] = Vec3D(value...)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3F,u,v) = self._uvValues[u,v] = Vec3D(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3D,u,v) = self._uvValues[u,v] = value
evalCallbackDpReturn(self::ParametricSurfaceDependent,::Nothing,u,v) = self._uvValues[u,v] = Vec3DNan

function setInlandNormal(self::ParametricSurfaceDependent,u,v)
    uVec = self._uvValues[u+1,v  ] - self._uvValues[u-1,v  ]
    vVec = self._uvValues[u  ,v+1] - self._uvValues[u  ,v-1]
    self._uvNormals[u,v] = normalize(cross(uVec,vVec))
end

function setEdgeNormal(self::ParametricSurfaceDependent,u,v)
    self._uvNormals[u,v] = Vec3F(0,0,0)
end

function setNormal(self::ParametricSurfaceDependent,u,v;
    right=self._uvValues[u+1,v  ],
    left =self._uvValues[u-1,v  ],
    down =self._uvValues[u  ,v+1],
    up   =self._uvValues[u  ,v-1])

    # TODO: Clampekkel megoldva?
    # TODO: Fuggosegi normalvektor szamitas, kicsi 0.0001 eplszilonokkal, helyben szamitva

    uVec = right - left
    vVec = down - up
    self._uvNormals[u,v] = normalize(cross(uVec,vVec))
end

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricSurfaceDependent)
    for v in eachindex(self._vRange)
        for u in eachindex(self._uRange)
            uf = self._uRange[u]
            vf = self._vRange[v]
            
            evalCallbackDp(self;callbackParams = (uf,vf), returnParams = (u,v))
        end
    end
    
    for v in 2:(height(self._uvValues)-1)
        for u in 2:(width(self._uvValues)-1)
            setNormal(self,u,v)
        end
    end

    # * Upper row, (u=u;v=1)
    for u in 2:(width(self._uvValues)-1)
        setNormal(self,u,1,
        up=self._uvValues[u,1])
    end

    # * Bottom row, (u=u;v=height)
    for u in 2:(width(self._uvValues)-1)
        setNormal(self,u,height(self._uvValues),
        down=self._uvValues[u,height(self._uvValues)])
    end

    # * Left column, (u=1;v=v)
    for v in 2:(height(self._uvValues)-1)
        setNormal(self,1,v,
        left=self._uvValues[1,v])
    end

    # * Right column, (u=width;v=v)
    for v in 2:(height(self._uvValues)-1)
        setNormal(self,width(self._uvValues),v,
        right=self._uvValues[width(self._uvValues),v])
    end

    # * (1,1)
    setNormal(self,1,1,
        left = self._uvValues[1,1],
        up   = self._uvValues[1,1])

    # * (width,1)
    setNormal(self,width(self._uvValues),1,
        right = self._uvValues[width(self._uvValues),1],
        up    = self._uvValues[width(self._uvValues),1])

    # * (1,height)
    setNormal(self,1,height(self._uvValues),
        left  = self._uvValues[1,height(self._uvValues)],
        down  = self._uvValues[1,height(self._uvValues)])

    # * (width,height)
    setNormal(self,width(self._uvValues),height(self._uvValues),
        right = self._uvValues[width(self._uvValues),height(self._uvValues)],
        down  = self._uvValues[width(self._uvValues),height(self._uvValues)])

end

# ? For Intersectable ParametricSurfaces.

struct PTrianglesOfSurface <: PrimitivesOf{PTriangle}
    _surfaceTriangleIterator::TrianglesOf
end
PrimitivesOf(self::ParametricSurfaceDependent) = return PTrianglesOfSurface(TrianglesOf(self._uvValues))

Base.length(self::PTrianglesOfSurface) = return length(self._surfaceTriangleIterator)

Base.getindex(self::PTrianglesOfSurface, index::UInt)::PTriangle = return self._surfaceTriangleIterator[index]

Base.iterate(self::PTrianglesOfSurface, state = (1,1,1)) = return iterate(self._surfaceTriangleIterator,state)   

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

mutable struct ParametricSurfaceRenderer <: RendererDNA{ParametricSurfaceDependent}
    _renderer::Renderer{ParametricSurfaceDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _shader_transparent::ShaderProgram

    _buffer_opaque::IndexedBufferArray
    _buffer_transparent::IndexedBufferArray

    _indexes_opaque::Vector{UInt32}
    _vertexes_opaque::FlatMatrixManager{Vec3F}
    _normals_opaque::FlatMatrixManager{Vec3F}
    _colors_opaque::FlatMatrixManager{Vec3F}

    _indexes_transparent::Vector{UInt32}
    _vertexes_transparent::FlatMatrixManager{Vec3F}
    _normals_transparent::FlatMatrixManager{Vec3F}
    _colors_transparent::FlatMatrixManager{Vec3F}

    # GREEN Thread
    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceDependent}(context)
        
        shader_id = ShaderProgram(["surface/surface_id.vert","surface/surface_id.frag"],["VP"])
        shader_opaque = ShaderProgram(["surface/surface.vert","surface/surface_opaque.frag"],["VP","lightDirCam","lightDirSide"])
        shader_transparent = ShaderProgram(["surface/surface.vert","surface/surface_transparent.frag"],["VP","lightDirCam","lightDirSide"])

        new(renderer,
        shader_id,shader_opaque,shader_transparent,
        IndexedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}(MappedBuffer,MappedBuffer,Buffer),IndexedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}(MappedBuffer,MappedBuffer,Buffer),
        Vector{UInt32}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}(),
        Vector{UInt32}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}())
    end
end

_Renderer_(self::ParametricSurfaceRenderer) = return self._renderer
Base.string(self::ParametricSurfaceRenderer) = "ParametricSurfaceRenderer - [$(length(self._buffer))]"

# GREEN Thread
function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    width = length(surface._uRange)
    height = length(surface._vRange)
    color = surface._color

    vertexes = surface._transparent ? self._vertexes_transparent : self._vertexes_opaque
    normals = surface._transparent ? self._normals_transparent : self._normals_opaque
    colors = surface._transparent ? self._colors_transparent : self._colors_opaque
    indexes = surface._transparent ? self._indexes_transparent : self._indexes_opaque

    initMatrix(vertexes,width,height,Vec3FNan)
    initMatrix(normals,width,height,Vec3FNan)
    initMatrix(colors,width,height,color)
    triangulateInto!(indexes,vertexes,layers(vertexes))
    
    # ? copy values
    copy!(surface._uvValues,vertexes,layers(vertexes))
    copy!(surface._uvNormals,normals,layers(normals))
    surface._layer = layers(vertexes)

    #println(surface._uvValues._data)
end

# GREEN Thread
function addedAll!(self::ParametricSurfaceRenderer)
    upload!(self._buffer_opaque,1,data(self._vertexes_opaque),0)
    upload!(self._buffer_opaque,2,data(self._normals_opaque),0)
    upload!(self._buffer_opaque,3,data(self._colors_opaque),0)
    upload_index!(self._buffer_opaque,self._indexes_opaque,0)

    upload!(self._buffer_transparent,1,data(self._vertexes_transparent),0)
    upload!(self._buffer_transparent,2,data(self._normals_transparent),0)
    upload!(self._buffer_transparent,3,data(self._colors_transparent),0)
    upload_index!(self._buffer_transparent,self._indexes_transparent,0)
end

# GREEN Thread
function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    vertexes = surface._transparent ? self._vertexes_transparent : self._vertexes_opaque
    normals = surface._transparent ? self._normals_transparent : self._normals_opaque
    layer = surface._layer

    copy!(surface._uvValues,vertexes,layer)
    copy!(surface._uvNormals,normals,layer)
end

# GREEN Thread
function syncAll!(self::ParametricSurfaceRenderer)
    @time_cpu_begin Dependent Surface
    wait(self._buffer_opaque[1])
    copyto!(self._buffer_opaque[1],data(self._vertexes_opaque))
    wait(self._buffer_opaque[2])
    copyto!(self._buffer_opaque[2],data(self._normals_opaque))
    
    wait(self._buffer_transparent[1])
    copyto!(self._buffer_transparent[1],data(self._vertexes_transparent))
    wait(self._buffer_transparent[2])
    copyto!(self._buffer_transparent[2],data(self._normals_transparent))
    @time_cpu_end Dependent Surface
end

function id_pass!(self::ParametricSurfaceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_id)
    uniform(self._shader_id,"VP",vp)
    @time_gpu_begin Dependent Surface ID_PASS
    if !isempty(self._indexes_opaque) draw(self._buffer_opaque,GL_TRIANGLES) end
    if !isempty(self._indexes_transparent) draw(self._buffer_transparent,GL_TRIANGLES) end
    @time_gpu_end Dependent Surface ID_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function opaque_pass!(self::ParametricSurfaceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if isempty(self._indexes_opaque) return nothing end
    (cam_light, side_light) = get_lights(cam)
    
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_opaque)
    uniform(self._shader_opaque,"VP",vp)
    uniform(self._shader_opaque,"lightDirCam",-cam_light)
    uniform(self._shader_opaque,"lightDirSide",-side_light)
    @time_gpu_begin Dependent Surface OPAQUE_PASS
    draw(self._buffer_opaque,GL_TRIANGLES)
    @time_gpu_end Dependent Surface OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    lock(self._buffer_opaque[1])
    lock(self._buffer_opaque[2])
    return nothing
end

function transparent_pass!(self::ParametricSurfaceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if isempty(self._indexes_transparent) return nothing end
    (cam_light, side_light) = get_lights(cam)
    
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_transparent)
    uniform(self._shader_transparent,"VP",vp)
    uniform(self._shader_transparent,"lightDirCam",-cam_light)
    uniform(self._shader_transparent,"lightDirSide",-side_light)
    @time_gpu_begin Dependent Surface TRANSPARENT_PASS
    draw(self._buffer_transparent,GL_TRIANGLES)
    @time_gpu_end Dependent Surface TRANSPARENT_PASS

    glEnable(GL_CULL_FACE)
    lock(self._buffer_transparent[1])
    lock(self._buffer_transparent[2])
    return nothing
end

# ! Must have
function destroy!(self::ParametricSurfaceRenderer)
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._shader_transparent)
    destroy!(self._buffer_opaque)
    destroy!(self._buffer_transparent)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricSurfaceDependent)::ParametricSurfaceRenderer = getOpenGL(app)._renderers[2]

# ? ---------------------------------
# ! ParametricSurface
# ? ---------------------------------

# YELLOW Thread
ParametricSurface(callback::Function,
uRange=range(0.0,1.0,50),vRange=range(0.0,1.0,50),
dependents::Vector{<:DependentDNA}=Vector{DependentDNA}();
transparent::Bool=false,color = Vec3F(0.8,0.0,0.3)) =
Build!(ParametricSurfaceDependent(callback,dependents,uRange,vRange,Vec3F(color...),transparent))

macro ParametricSurface(callback::Expr,uRange,vRange,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:transparent, :color], kw_args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
        (cb, deps) -> (cb, uRange, vRange, deps);
        parsed_kw_args...)
end

export ParametricSurface
export @ParametricSurface