
# ? ---------------------------------
# ! ParametricSurfacePlan
# ? ---------------------------------

mutable struct ParametricSurfacePlan <:RenderedPlanDNA
    _plan::RenderedPlan
     
    _width::Int
    _height::Int
    
    _uStart::Float64
    _uEnd::Float64
    
    _vStart::Float64
    _vEnd::Float64

    _color::Vec3F
    _transparent::Bool
    
    function ParametricSurfacePlan(callback::Function,plans::Vector{T},width,height,uStart,uEnd,vStart,vEnd,color,transparent) where {T<:PlanDNA}
        
        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])
        
        new(RenderedPlan(callback,plans),
            width,height,
            uStart,uEnd,
            vStart,vEnd,
            Vec3F(r,g,b),transparent)
    end
end

_RenderedPlan_(self::ParametricSurfacePlan)::RenderedPlan = return self._plan
Base.string(self::ParametricSurfacePlan)::String = return "Surface"

# ? ---------------------------------
# ! ParametricSurfaceDependent
# ? ---------------------------------

mutable struct ParametricSurfaceDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _uvValues::FlatMatrix
    _uvNormals::FlatMatrix

    _unmanagedWidth::Int
    _unmanagedHeight::Int

    _uStart::Float64
    _uEnd::Float64
    
    _vStart::Float64
    _vEnd::Float64

    _color::Vec3F
    _transparent::Bool

    function ParametricSurfaceDependent(plan::ParametricSurfacePlan)
        renderedDependent = RenderedDependent(plan)
                
        unmanagedWidth = plan._width
        unmanagedHeight = plan._height
        
        uStart = plan._uStart
        uEnd = plan._uEnd
        
        vStart = plan._vStart
        vEnd = plan._vEnd
        
        color = plan._color
        transparent = plan._transparent

        new(renderedDependent,
            EMPTY_FlatMatrix,
            EMPTY_FlatMatrix,
            unmanagedWidth,unmanagedHeight,
            uStart,uEnd,
            vStart,vEnd,
            color,transparent)
    end
end

# ! Must have
function Plan2Dependent(plan::ParametricSurfacePlan)::ParametricSurfaceDependent
    return ParametricSurfaceDependent(plan)
end

_RenderedDependent_(self::ParametricSurfaceDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::ParametricSurfaceDependent) = return "ParametricSurface"

function evalCoordAtUV(self::ParametricSurfaceDependent,u,v)
   
    uf = Float64(u-1) / Float64(width(self._uvValues)-1)
    vf = Float64(v-1) / Float64(height(self._uvValues)-1)

    uf = uf * (self._uEnd - self._uStart) + self._uStart
    vf = vf * (self._vEnd - self._vStart) + self._vStart

    return evalCallbackDp(self;callbackParams = (uf,vf), returnParams = (u,v))
end

evalCallbackDpReturn(self::ParametricSurfaceDependent,value,u,v) = self._uvValues[u,v] = Vec3F(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Tuple,u,v) = self._uvValues[u,v] = Vec3F(value...)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3D,u,v) = self._uvValues[u,v] = Vec3F(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3F,u,v) = self._uvValues[u,v] = value
evalCallbackDpReturn(self::ParametricSurfaceDependent,::Nothing,u,v) = self._uvValues[u,v] = Vec3FNan

function evalCallbackDpReturn(self::ParametricSurfaceDependent,u,v,::Nothing)
    self._uvValues[u,v] = Vec3FNan
end

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

function runCallbacks(self::ParametricSurfaceDependent)
    for v in 1:height(self._uvValues)
        for u in 1:width(self._uvValues)
            evalCoordAtUV(self,u,v)
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

function onNodeEval(self::ParametricSurfaceDependent)
    runCallbacks(self)
end

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

mutable struct ParametricSurfaceRenderer <: RendererDNA{ParametricSurfaceDependent}
    _renderer::Renderer{ParametricSurfaceDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _shader_transparent::ShaderProgram

    _buffer_opaque::IndexedTypedBufferArray
    _buffer_transparent::IndexedTypedBufferArray

    _indexes_opaque::Vector{UInt32}
    _vertexes_opaque::FlatMatrixManager{Vec3F}
    _normals_opaque::FlatMatrixManager{Vec3F}
    _colors_opaque::FlatMatrixManager{Vec3F}

    _indexes_transparent::Vector{UInt32}
    _vertexes_transparent::FlatMatrixManager{Vec3F}
    _normals_transparent::FlatMatrixManager{Vec3F}
    _colors_transparent::FlatMatrixManager{Vec3F}

    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceDependent}(context)
        
        shader_id = ShaderProgram(sp(".\\surface\\surface_id.vert"),sp(".\\surface\\surface_id.frag"),["VP"])
        shader_opaque = ShaderProgram(sp(".\\surface\\surface.vert"),sp(".\\surface\\surface_opaque.frag"),["VP","lightDirCam","lightDirSide"])
        shader_transparent = ShaderProgram(sp(".\\surface\\surface.vert"),sp(".\\surface\\surface_transparent.frag"),["VP","lightDirCam","lightDirSide"])

        new(renderer,
        shader_id,shader_opaque,shader_transparent,
        IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}(),IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}(),
        Vector{UInt32}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}(),
        Vector{UInt32}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}())
    end
end

_Renderer_(self::ParametricSurfaceRenderer) = return self._renderer
Base.string(self::ParametricSurfaceRenderer) = "ParametricSurfaceRenderer - [$(length(self._buffer))]"

# ! Must have
function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    width = surface._unmanagedWidth
    height = surface._unmanagedHeight
    color = surface._color

    vertexes = surface._transparent ? self._vertexes_transparent : self._vertexes_opaque
    normals = surface._transparent ? self._normals_transparent : self._normals_opaque
    colors = surface._transparent ? self._colors_transparent : self._colors_opaque
    indexes = surface._transparent ? self._indexes_transparent : self._indexes_opaque

    initMatrix(vertexes,width,height,Vec3FNan)
    initMatrix(normals,width,height,Vec3FNan)
    initMatrix(colors,width,height,color)
    triangulateInto!(indexes,vertexes,layers(vertexes))
    surface._uvValues  = FlatMatrix{layers(vertexes),Vec3F}(vertexes)
    surface._uvNormals = FlatMatrix{layers(vertexes),Vec3F}(normals)

    onNodeEval(surface)

    @log "ParametricSurface added!" INFO
end

setRenderedID!(renderer::ParametricSurfaceRenderer,dependent::ParametricSurfaceDependent,id) = return nothing

# ! Must have
function addedAll!(self::ParametricSurfaceRenderer)
    upload!(self._buffer_opaque,1,data(self._vertexes_opaque),GL_DYNAMIC_DRAW)
    upload!(self._buffer_opaque,2,data(self._normals_opaque),GL_DYNAMIC_DRAW)
    upload!(self._buffer_opaque,3,data(self._colors_opaque),GL_STATIC_DRAW)
    uploadIndexes!(self._buffer_opaque,self._indexes_opaque,GL_STATIC_DRAW)

    upload!(self._buffer_transparent,1,data(self._vertexes_transparent),GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,2,data(self._normals_transparent),GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,3,data(self._colors_transparent),GL_STATIC_DRAW)
    uploadIndexes!(self._buffer_transparent,self._indexes_transparent,GL_STATIC_DRAW)
end

# ! Must have
function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    @log "Synced ParametricSurface!" INFO
end

# ! Must have
function syncAll!(self::ParametricSurfaceRenderer)
    @time_cpu_begin Dependent Surface
    upload!(self._buffer_opaque,1,data(self._vertexes_opaque),GL_DYNAMIC_DRAW)
    upload!(self._buffer_opaque,2,data(self._normals_opaque),GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,1,data(self._vertexes_transparent),GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,2,data(self._normals_transparent),GL_DYNAMIC_DRAW)
    @time_cpu_end Dependent Surface
end

function id_pass!(self::ParametricSurfaceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_id)
    setUniform!(self._shader_id,"VP",vp)
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
    setUniform!(self._shader_opaque,"VP",vp)
    setUniform!(self._shader_opaque,"lightDirCam",-cam_light)
    setUniform!(self._shader_opaque,"lightDirSide",-side_light)
    @time_gpu_begin Dependent Surface OPAQUE_PASS
    draw(self._buffer_opaque,GL_TRIANGLES)
    @time_gpu_end Dependent Surface OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent_pass!(self::ParametricSurfaceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if isempty(self._indexes_transparent) return nothing end
    (cam_light, side_light) = get_lights(cam)
    
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_transparent)
    setUniform!(self._shader_transparent,"VP",vp)
    setUniform!(self._shader_transparent,"lightDirCam",-cam_light)
    setUniform!(self._shader_transparent,"lightDirSide",-side_light)
    @time_gpu_begin Dependent Surface TRANSPARENT_PASS
    draw(self._buffer_transparent,GL_TRIANGLES)
    @time_gpu_end Dependent Surface TRANSPARENT_PASS

    glEnable(GL_CULL_FACE)
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

# ! Must have
function Plan2Observer(self::OpenGLData,plan::ParametricSurfacePlan)
    return SingleRendererTactic(self,_SURFACE_RENDERER,ParametricSurfaceRenderer)::ParametricSurfaceRenderer
end
