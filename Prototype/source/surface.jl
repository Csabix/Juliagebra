# ? ---------------------------------
# ! ParametricSurfaceAlgebra
# ? ---------------------------------

mutable struct ParametricSurfaceAlgebra <: RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    
    _unmanagedWidth::Int
    _unmanagedHeight::Int

    _uStart::Float64
    _uEnd::Float64
    
    _vStart::Float64
    _vEnd::Float64

    _uvValues::FlatMatrix
    _uvNormals::FlatMatrix

    _color::Vec3F

    function ParametricSurfaceAlgebra(renderer,dependents::Vector{PlanDNA},callback::Function)
        renderedAlgebra = RenderedAlgebra(renderer,dependents,callback)
        
        # TODO Heavy refactoring needed, to mitigate this solution!
        emptyStuff = FlatMatrix{0,Vec3F}(FlatMatrixManager{Vec3F}())
        
        new(renderedAlgebra,
            0,0,
            0,0,
            0,0,
            emptyStuff,
            emptyStuff,
            Vec3FNan)
    end
end

_RenderedAlgebra_(self::ParametricSurfaceAlgebra)::RenderedAlgebra = return self._renderedAlgebra
Base.string(self::ParametricSurfaceAlgebra) = return "ParametricSurface"

function evalCallback(self::ParametricSurfaceAlgebra,u,v)
   
    uf = Float64(u-1) / Float64(width(self._uvValues)-1)
    vf = Float64(v-1) / Float64(height(self._uvValues)-1)

    uf = uf * (self._uEnd - self._uStart) + self._uStart
    vf = vf * (self._vEnd - self._vStart) + self._vStart

    #println("uf:$(uf) - vf:$(vf)")

    return _Algebra_(self)._callback(uf,vf,_Algebra_(self)._dependents...)
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
    self._uvNormals[u,v] = cross(normalize(uVec),normalize(vVec))
end

function setEdgeNormal(self::ParametricSurfaceAlgebra,u,v)
    self._uvNormals[u,v] = Vec3F(0,0,0)
end

function runCallbacks(self::ParametricSurfaceAlgebra)
    for v in 1:height(self._uvValues)
        for u in 1:width(self._uvValues)
            dpEvalCallback(self,u,v)
        end
    end
    
    for v in 2:(height(self._uvValues)-1)
        for u in 2:(width(self._uvValues)-1)
            setInlandNormal(self,u,v)
        end
    end

    for v in [1,height(self._uvValues)]
        for u in 1:width(self._uvValues)
            setEdgeNormal(self,u,v)
        end
    end

    for v in 1:height(self._uvValues)
        for u in [1,width(self._uvValues)]
            setEdgeNormal(self,u,v)
        end
    end
end

function onGraphEval(self::ParametricSurfaceAlgebra)
    runCallbacks(self)
    flag!(self)
end

# ? ---------------------------------
# ! ParametricSurfacePlan
# ? ---------------------------------

mutable struct ParametricSurfacePlan <:PlanDNA
    _plan::Plan
    
    _plans::Vector{PlanDNA}
    _callback::Function
    
    _width::Int
    _height::Int
    
    _uStart::Float64
    _uEnd::Float64
    
    _vStart::Float64
    _vEnd::Float64

    _color::Vec3F
    
    function ParametricSurfacePlan(plans::Vector{T},callback::Function,width,height,uStart,uEnd,vStart,vEnd,color) where {T<:PlanDNA}
        
        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])
        
        new(Plan(),plans,callback,
            width,height,
            uStart,uEnd,
            vStart,vEnd,
            Vec3F(r,g,b))
    end
end

_Plan_(self::ParametricSurfacePlan)::Plan = return self._plan

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

function destroy!(self::ParametricSurfaceRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceAlgebra)
    
    color = surface._color
    
    width = surface._unmanagedWidth
    height = surface._unmanagedHeight

    initMatrix(self._vertexes,width,height,Vec3FNan)
    initMatrix(self._normals,width,height,Vec3FNan)
    initMatrix(self._colors,width,height,color)
    triangulateInto!(self._indexes,self._vertexes,layers(self._vertexes))
    surface._uvValues  = FlatMatrix{layers(self._vertexes),Vec3F}(self._vertexes)
    surface._uvNormals = FlatMatrix{layers(self._vertexes),Vec3F}(self._normals)

    runCallbacks(surface)

    #println("$(self._indexes)")

    println("ParametricSurface added!")
end

function addedUpload!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,data(self._vertexes),GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,data(self._normals),GL_DYNAMIC_DRAW)
    upload!(self._buffer,3,data(self._colors),GL_STATIC_DRAW)
    uploadIndexes!(self._buffer,self._indexes,GL_STATIC_DRAW)
end

function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceAlgebra)
    println("Synced ParametricSurface!")
end

function syncUpload!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,data(self._vertexes),GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,data(self._normals),GL_DYNAMIC_DRAW)
end

function draw!(self::ParametricSurfaceRenderer,vp,selectedID,pickedID,cam,shrd)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"lightDir",normalize(cam._eye-cam._at))
    draw(self._buffer,GL_TRIANGLES)

    glEnable(GL_CULL_FACE)
end

function plan2Algebra(self::ParametricSurfaceRenderer,plan::ParametricSurfacePlan)::ParametricSurfaceAlgebra
    surface = ParametricSurfaceAlgebra(self,plan._plans,plan._callback)

    surface._color = plan._color
    surface._unmanagedWidth = plan._width
    surface._unmanagedHeight = plan._height
    surface._uStart = plan._uStart
    surface._uEnd = plan._uEnd
    surface._vStart = plan._vStart
    surface._vEnd = plan._vEnd
    
    return surface
end

function recruit!(self::OpenGLData,plan::ParametricSurfacePlan)::ParametricSurfaceAlgebra
    myVector = get!(self._renderOffices,CurveRenderer,Vector{ParametricSurfaceRenderer}())
    if(length(myVector)!=1)
        push!(myVector,ParametricSurfaceRenderer(self))
    end

    surface = assignPlan!(myVector[1],plan)
    return surface
end
