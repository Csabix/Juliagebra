# ? ---------------------------------
# ! MeshAlgebra
# ? ---------------------------------

mutable struct MeshAlgebra <: RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    
    _vertexes::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _color::Vec3F

    # TODO: make vectoring dynamic like in ParametricCurve

    function MeshAlgebra(renderer,dependents::Vector{PlanDNA},callback::Function)
        renderedAlgebra = RenderedAlgebra(renderer,dependents,callback)
        new(renderedAlgebra,[],[],Vec3FNan)
    end
end

_RenderedAlgebra_(self::MeshAlgebra) = self._renderedAlgebra
Base.string(self::MeshAlgebra)::String = "MeshAlgebra - [$(length(self._positions))]"

onGraphEval(self::MeshAlgebra) = nothing

# ? ---------------------------------
# ! MeshAlgebraPlan
# ? ---------------------------------

mutable struct MeshAlgebraPlan <:PlanDNA
    _plan::Plan
    _vertexes::Vector{Tuple{Real,Real,Real}}
    _normals::Vector{Tuple{Real,Real,Real}}
    _color::Vec3F

    function MeshAlgebraPlan(vertexes,normals,color)
        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])
        
        new(Plan(),vertexes,normals,Vec3F(r,g,b))
    end
end

_Plan_(self::MeshAlgebraPlan)::Plan = return self._plan

# ? ---------------------------------
# ! MeshAlgebraRenderer
# ? ---------------------------------

mutable struct MeshAlgebraRenderer <: RendererDNA{MeshAlgebra}
    _renderer::Renderer{MeshAlgebra}

    _shader::ShaderProgram
    _buffer::TypedBufferArray

    _vertexes::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _colors::Vector{Vec3F}

    function MeshAlgebraRenderer(context::OpenGLData)
        renderer = Renderer{MeshAlgebra}(context)
        
        shader = ShaderProgram(sp("mesh_direction.vert"),sp("mesh_direction.frag"),["VP","lightDir"])
        buffer = TypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}()

        vertexes = Vector{Vec3F}()
        normals = Vector{Vec3F}()
        colors = Vector{Vec3F}()

        new(renderer,shader,buffer,vertexes,normals,colors)
    end
end

_Renderer_(self::MeshAlgebraRenderer) = return self._renderer
Base.string(self::MeshAlgebraRenderer) = "MeshAlgerbaRenderer - [$(length(self._buffer))]"

function destroy!(self::MeshAlgebraRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

function added!(self::MeshAlgebraRenderer,mesh::MeshAlgebra)
    # TODO: make this dynamic like in ParametricCurve
    
    color = mesh._color
    
    for i in 1:length(mesh._vertexes)
        vertex = mesh._vertexes[i]
        normal = mesh._normals[i]

        push!(self._vertexes,vertex)
        push!(self._normals,normal)
        push!(self._colors,color)
    end
end

function addedUpload!(self::MeshAlgebraRenderer)
    upload!(self._buffer,1,self._vertexes,GL_STATIC_DRAW)
    upload!(self._buffer,2,self._normals,GL_STATIC_DRAW)
    upload!(self._buffer,3,self._colors,GL_STATIC_DRAW)
end

function sync!(self::MeshAlgebraRenderer,curve::MeshAlgebra)
# TODO: Finish this.
end

function syncUpload!(self::MeshAlgebraRenderer)
# TODO: Finish this.
end

function draw!(self::MeshAlgebraRenderer,vp,selectedID,pickedID,cam,shrd)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"lightDir",normalize(cam._eye-cam._at))
    draw(self._buffer,GL_TRIANGLES)

    glEnable(GL_CULL_FACE)
end

function plan2Algebra(self::MeshAlgebraRenderer,plan::MeshAlgebraPlan)::MeshAlgebra
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

function recruit!(self::OpenGLData,plan::MeshAlgebraPlan)::MeshAlgebra
    myVector = get!(self._renderOffices,MeshAlgebraRenderer,Vector{MeshAlgebraRenderer}())
    if(length(myVector)!=1)
        push!(myVector,MeshAlgebraRenderer(self))
    end
    
    mesh = assignPlan!(myVector[1],plan)
    return mesh
end