
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

# ? ---------------------------------
# ! ParametricSurfaceAlgebra
# ? ---------------------------------

mutable struct ParametricSurfaceAlgebra <: RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    
    _uvValues::FlatMatrix
    _uvNormals::FlatMatrix

    _unmanagedWidth::Int
    _unmanagedHeight::Int

    _uStart::Float64
    _uEnd::Float64
    
    _vStart::Float64
    _vEnd::Float64

    _color::Vec3F

    function ParametricSurfaceAlgebra(plan::ParametricSurfacePlan)
        renderedAlgebra = RenderedAlgebra(plan)
                
        unmanagedWidth = plan._width
        unmanagedHeight = plan._height
        
        uStart = plan._uStart
        uEnd = plan._uEnd
        
        vStart = plan._vStart
        vEnd = plan._vEnd
        
        color = plan._color

        new(renderedAlgebra,
            EMPTY_FlatMatrix,
            EMPTY_FlatMatrix,
            unmanagedWidth,unmanagedHeight,
            uStart,uEnd,
            vStart,vEnd,
            color)
    end
end

# ! Must have
function Plan2Algebra(plan::ParametricSurfacePlan)::ParametricSurfaceAlgebra
    return ParametricSurfaceAlgebra(plan)
end

_RenderedAlgebra_(self::ParametricSurfaceAlgebra)::RenderedAlgebra = return self._renderedAlgebra
Base.string(self::ParametricSurfaceAlgebra) = return "ParametricSurface"

function evalCallback(self::ParametricSurfaceAlgebra,u,v)
   
    uf = Float64(u-1) / Float64(width(self._uvValues)-1)
    vf = Float64(v-1) / Float64(height(self._uvValues)-1)

    uf = uf * (self._uEnd - self._uStart) + self._uStart
    vf = vf * (self._vEnd - self._vStart) + self._vStart

    #println("uf:$(uf) - vf:$(vf)")

    return _Algebra_(self)._callback(uf,vf,_Algebra_(self)._graphParents...)
end

function dpCallbackReturn(self::ParametricSurfaceAlgebra,u,v,value::Tuple)
    (x,y,z)=value
    self._uvValues[u,v] = Vec3F(x,y,z)
end

function dpCallbackReturn(self::ParametricSurfaceAlgebra,u,v,undef::Undef)
    self._uvValues[u,v] = Vec3FNan
end

function setInlandNormal(self::ParametricSurfaceAlgebra,u,v)
    uVec = self._uvValues[u+1,v  ] - self._uvValues[u-1,v  ]
    vVec = self._uvValues[u  ,v+1] - self._uvValues[u  ,v-1]
    self._uvNormals[u,v] = normalize(cross(uVec,vVec))
end

function setEdgeNormal(self::ParametricSurfaceAlgebra,u,v)
    self._uvNormals[u,v] = Vec3F(0,0,0)
end

function setNormal(self::ParametricSurfaceAlgebra,u,v;
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

function runCallbacks(self::ParametricSurfaceAlgebra)
    for v in 1:height(self._uvValues)
        for u in 1:width(self._uvValues)
            dpEvalCallback(self,u,v)
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

function onGraphEval(self::ParametricSurfaceAlgebra)
    runCallbacks(self)
    flag!(self)
end

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

mutable struct ParametricSurfaceRenderer <: RendererDNA{ParametricSurfaceAlgebra}
    _renderer::Renderer{ParametricSurfaceAlgebra}

    _shader::ShaderProgram
    _buffer::IndexedTypedBufferArray

    _indexes::Vector{UInt32}
    _vertexes::FlatMatrixManager{Vec3F}
    _normals::FlatMatrixManager{Vec3F}
    _colors::FlatMatrixManager{Vec3F}

    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceAlgebra}(context)
        
        shader = ShaderProgram(sp("mesh_direction.vert"),sp("mesh_direction.frag"),["VP","lightDir"])
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
function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceAlgebra)
    
    width = surface._unmanagedWidth
    height = surface._unmanagedHeight
    color = surface._color

    initMatrix(self._vertexes,width,height,Vec3FNan)
    initMatrix(self._normals,width,height,Vec3FNan)
    initMatrix(self._colors,width,height,color)
    triangulateInto!(self._indexes,self._vertexes,layers(self._vertexes))
    surface._uvValues  = FlatMatrix{layers(self._vertexes),Vec3F}(self._vertexes)
    surface._uvNormals = FlatMatrix{layers(self._vertexes),Vec3F}(self._normals)

    runCallbacks(surface)

    println("ParametricSurface added!")
end

# ! Must have
function addedUpload!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,data(self._vertexes),GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,data(self._normals),GL_DYNAMIC_DRAW)
    upload!(self._buffer,3,data(self._colors),GL_STATIC_DRAW)
    uploadIndexes!(self._buffer,self._indexes,GL_STATIC_DRAW)
end

# ! Must have
function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceAlgebra)
    println("Synced ParametricSurface!")
end

# ! Must have
function syncUpload!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,data(self._vertexes),GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,data(self._normals),GL_DYNAMIC_DRAW)
end

# ! Must have
function draw!(self::ParametricSurfaceRenderer,vp,selectedID,pickedID,cam,shrd)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"lightDir",normalize(cam._eye-cam._at))
    draw(self._buffer,GL_TRIANGLES)

    glEnable(GL_CULL_FACE)
end

# ! Must have
function destroy!(self::ParametricSurfaceRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Renderer(self::OpenGLData,plan::ParametricSurfacePlan)
    return SingleRendererTactic(self,ParametricSurfaceRenderer)
end
