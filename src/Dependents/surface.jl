
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
    
    function ParametricSurfacePlan(callback::Function,plans::Vector{T},width,height,uStart,uEnd,vStart,vEnd,color) where {T<:PlanDNA}
        
        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])
        
        new(RenderedPlan(callback,plans),
            width,height,
            uStart,uEnd,
            vStart,vEnd,
            Vec3F(r,g,b))
    end
end

_RenderedPlan_(self::ParametricSurfacePlan)::RenderedPlan = return self._plan
Base.string(self::ParametricSurfacePlan)::String = return "Surface"

# ? For automatic intersections.
TOfPrimitivesOf(::ParametricSurfacePlan) = PTriangle

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

    function ParametricSurfaceDependent(plan::ParametricSurfacePlan)
        renderedDependent = RenderedDependent(plan)
                
        unmanagedWidth = plan._width
        unmanagedHeight = plan._height
        
        uStart = plan._uStart
        uEnd = plan._uEnd
        
        vStart = plan._vStart
        vEnd = plan._vEnd
        
        color = plan._color

        new(renderedDependent,
            EMPTY_FlatMatrix,
            EMPTY_FlatMatrix,
            unmanagedWidth,unmanagedHeight,
            uStart,uEnd,
            vStart,vEnd,
            color)
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

    _shader::ShaderProgram
    _buffer::IndexedTypedBufferArray

    _indexes::Vector{UInt32}
    _vertexes::FlatMatrixManager{Vec3F}
    _normals::FlatMatrixManager{Vec3F}
    _colors::FlatMatrixManager{Vec3F}

    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceDependent}(context)
        
        shader = ShaderProgram(sp("mesh_direction.vert"),sp("mesh_direction.frag"),["VP","lightDirCam","lightDirSide"])
        buffer = IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}()

        indexes = Vector{UInt32}()

        vertexes = FlatMatrixManager{Vec3F}()
        normals = FlatMatrixManager{Vec3F}()
        colors = FlatMatrixManager{Vec3F}()

        new(renderer,shader,buffer,indexes,vertexes,normals,colors)
    end
end

_Renderer_(self::ParametricSurfaceRenderer) = return self._renderer
Base.string(self::ParametricSurfaceRenderer) = "ParametricSurfaceRenderer - [$(length(self._buffer))]"

# ! Must have
function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    
    width = surface._unmanagedWidth
    height = surface._unmanagedHeight
    color = surface._color

    initMatrix(self._vertexes,width,height,Vec3FNan)
    initMatrix(self._normals,width,height,Vec3FNan)
    initMatrix(self._colors,width,height,color)
    triangulateInto!(self._indexes,self._vertexes,layers(self._vertexes))
    surface._uvValues  = FlatMatrix{layers(self._vertexes),Vec3F}(self._vertexes)
    surface._uvNormals = FlatMatrix{layers(self._vertexes),Vec3F}(self._normals)

    onNodeEval(surface)

    @log "ParametricSurface added!" INFO
end

setRenderedID!(renderer::ParametricSurfaceRenderer,dependent::ParametricSurfaceDependent,id) = return nothing

# ! Must have
function addedAll!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,data(self._vertexes),GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,data(self._normals),GL_DYNAMIC_DRAW)
    upload!(self._buffer,3,data(self._colors),GL_STATIC_DRAW)
    uploadIndexes!(self._buffer,self._indexes,GL_STATIC_DRAW)
end

# ! Must have
function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    @log "Synced ParametricSurface!" INFO
end

# ! Must have
function syncAll!(self::ParametricSurfaceRenderer)
    @time_cpu_begin Dependent Surface
    upload!(self._buffer,1,data(self._vertexes),GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,data(self._normals),GL_DYNAMIC_DRAW)
    @time_cpu_end Dependent Surface
end

# ! Must have
function draw!(self::ParametricSurfaceRenderer,vp,selectedID,pickedID,cam,shrd)
    (cam_light, side_light) = get_lights(cam)
    
    glDisable(GL_CULL_FACE)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    #setUniform!(self._shader,"lightDir",normalize(cam._eye-cam._at))
    setUniform!(self._shader,"lightDirCam",-cam_light)
    setUniform!(self._shader,"lightDirSide",-side_light)
    @time_gpu_begin Dependent Surface
    draw(self._buffer,GL_TRIANGLES)
    @time_gpu_end Dependent Surface

    glEnable(GL_CULL_FACE)
end

# ! Must have
function destroy!(self::ParametricSurfaceRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Observer(self::OpenGLData,plan::ParametricSurfacePlan)
    return SingleRendererTactic(self,ParametricSurfaceRenderer)
end
