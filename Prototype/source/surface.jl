# ? ---------------------------------
# ! ParametricSurfaceAlgebra
# ? ---------------------------------

mutable struct ParametricSurfaceAlgebra <: RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra

    _width::Int
    _height::Int
    # TODO: maybe change tp veiws or create a custom view?
    _offset::Int 

    _uStart::Float64
    _uEnd::Float64
    _vStart::Float64
    _vEnd::Float64

    _positions::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _color::Vec3F

    function ParametricSurfaceAlgebra(renderer,dependents::Vector{PlanDNA},callback::Function)
        renderedAlgebra = RenderedAlgebra(renderer,dependents,callback)
        new(renderedAlgebra,
            0,0,0,
            0,0,0,0,
            [],[],Vec3FNan)
    end
end

# ? ---------------------------------
# ! ParametricSurfacePlan
# ? ---------------------------------

mutable struct ParametricSurfacePlan <:PlanDNA
    _plan::Plan
    
    _plans::Vector{PlanDNA}
    _callback::Function
    _color::Vec3F
    
    function ParametricSurfacePlan(plans::Vector{T},callback::Function,color) where {T<:PlanDNA}
        
        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])
        
        new(Plan(),plans,callback,Vec3F(r,g,b))
    end
end

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

mutable struct ParametricSurfaceRenderer <: RendererDNA{ParametricSurfaceAlgebra}
    _renderer::Renderer{ParametricSurfaceAlgebra}

    _shader::ShaderProgram
    _buffer::IndexedTypedBufferArray

    _indexes::Vector{UInt32}
    _vertexes::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _colors::Vector{Vec3F}

    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceAlgebra}(context)
        
        shader = ShaderProgram(sp("mesh_direction.vert"),sp("mesh_direction.frag"),["VP","lightDir"])
        buffer = IndexedTypedBufferArray{Vec3F,Vec3F,Vec3F}()

        indexes = Vector{Vec3F}()
        vertexes = Vector{Vec3F}()
        normals = Vector{Vec3F}()
        colors = Vector{Vec3F}()

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
    
    for i in 1:length(mesh._vertexes)
        push!(self._vertexes,Vec3FNan)
        push!(self._normals,Vec3FNan)
        push!(self._colors,color)
    end
    println("ParametricSurface added!")
end

function addedUpload!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,self._vertexes,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._normals,GL_DYNAMIC_DRAW)
    upload!(self._buffer,3,self._colors,GL_STATIC_DRAW)
    uploadIndexes!(self._buffer,self._indexes,GL_STATIC_DRAW)
end

function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceAlgebra)
    println("Synced ParametricSurface!")
end

function syncUpload!(self::ParametricSurfaceRenderer)
    upload!(self._buffer,1,self._vertexes,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._normals,GL_DYNAMIC_DRAW)
end

function draw!(self::ParametricSurfaceRenderer,vp,selectedID,pickedID,cam,shrd)
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"lightDir",normalize(cam._eye-cam._at))
    draw(self._buffer,GL_TRIANGLES)
end

function plan2Algebra(self::ParametricSurfaceRenderer,plan::ParametricSurfacePlan)::ParametricCurveAlgebra
    mesh = MeshAlgebra(self,Vector{PlanDNA}(),() -> ())

    mesh._color = plan._color
    
    for i in 1:length(plan._vertexes)
        x = Float32(plan._vertexes[i][1])
        y = Float32(plan._vertexes[i][2])
        z = Float32(plan._vertexes[i][3])
        push!(mesh._vertexes,Vec3F(x,y,z))
        
        x = Float32(plan._normals[i][1])
        y = Float32(plan._normals[i][2])
        z = Float32(plan._normals[i][3])
        push!(mesh._normals,normalize(Vec3F(x,y,z)))
    end

    return mesh
end

function recruit!(self::OpenGLData,plan::ParametricSurfacePlan)::ParametricCurveAlgebra
    myVector = get!(self._renderOffices,CurveRenderer,Vector{ParametricSurfaceRenderer}())
    if(length(myVector)!=1)
        push!(myVector,ParametricSurfaceRenderer(self))
    end

    mesh = assignPlan!(myVector[1],plan)
    return mesh
end
