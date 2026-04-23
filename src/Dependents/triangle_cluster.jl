# ? ---------------------------------
# ! TriangleClusterDependent
# ? ---------------------------------

mutable struct TriangleClusterDependent <: RenderedDependentDNA
    _dependent::RenderedDependent
    _mesh::Mesh
    _transform::Mat4T{Float64}
    _color::UInt32
    
    function TriangleClusterDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        mesh::BaseMesh,transform,color
    )
        _mesh = Mesh(get_positions(mesh),get_indices(mesh))
        dependent = RenderedDependent(callback,dependents)
        new(dependent,_mesh,transform,color)
    end
end

_RenderedDependent_(self::TriangleClusterDependent)::RenderedDependent = return self._dependent

onNodeEval(self::TriangleClusterDependent) = evalCallbackDp(self)

evalCallbackDpReturn(self::TriangleClusterDependent,triangles::Vector{Vec3D}) = self._mesh = Mesh(triangles)
evalCallbackDpReturn(self::TriangleClusterDependent,triangles::Vector) = self._mesh = Mesh([Vec3D(v[1],v[2],v[3]) for v in triangles])
function evalCallbackDpReturn(self::TriangleClusterDependent,position_indices::Tuple{Any,Vector{UInt32}})
    evalCallbackDpReturn(self, position_indices[1])
    self._mesh = Mesh(self._mesh.positions,position_indices[2])
end
function evalCallbackDpReturn(self::TriangleClusterDependent,position_indices::Tuple{Any,Vector})
    evalCallbackDpReturn(self, position_indices[1])
    self._mesh = Mesh(self._mesh.positions,UInt32.position_indices[2])
end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Mesh) = self._mesh = v
evalCallbackDpReturn(self::TriangleClusterDependent,v::AbstractMatrix) = self._transform = Mat4T{Float64}(v)
evalCallbackDpReturn(self::TriangleClusterDependent,::Nothing) = self._transform = dmat4(0.0)


function _get_positions(self::TriangleClusterDependent)
    return isnothing(self._mesh.indices) ? [Vec4F(pos...,1) for pos in self._mesh.positions] : [Vec4F(self._mesh.positions[index+1]...,1) for index in self._mesh.indices]
end

struct TriangleCluster
    _mesh::Mesh
    _transform::Mat4T{Float64}

    TriangleCluster(dep::TriangleClusterDependent) = new(dep._mesh,dep._transform)
end

function get_triangles(triangle_cluster::TriangleCluster)
    p = isapprox(triangle_cluster._transform, mat4(1.0)) ? 
        triangle_cluster._mesh.positions : 
        [begin
         pp = triangle_cluster._transform * Vec4D(p.x,p.y,p.z,1.0)
         Vec3D(pp.x,pp.y,pp.z)
         end
         for p in triangle_cluster._mesh.positions]

    let ind = triangle_cluster._mesh.indices
        if isnothing(ind)
            return ((p[i], p[i+1], p[i+2]) for i in 1:3:length(p))
        else
            return ((p[ind[i]+1], p[ind[i+1]+1], p[ind[i+2]+1]) for i in 1:3:length(ind))
        end
    end
end

function get_positions(triangle_cluster::TriangleCluster)::Vector{Vec3D}
    p = isapprox(triangle_cluster._transform, mat4(1.0)) ? 
        triangle_cluster._mesh.positions : 
        [begin
         pp = triangle_cluster._transform * Vec4D(p.x,p.y,p.z,1.0)
         Vec3D(pp.x,pp.y,pp.z)
         end
         for p in triangle_cluster._mesh.positions]

    return isnothing(triangle_cluster._mesh.indices) ? p : unique(p)
end

evalCallbackDpEntry(self::TriangleClusterDependent)::TriangleCluster = TriangleCluster(self)

# ? ---------------------------------
# ! TriangleClusterRenderer
# ? ---------------------------------

mutable struct TriangleClusters <: RendererDNA{TriangleClusterDependent}
    _renderer::Renderer{TriangleClusterDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    function TriangleClusters(context::OpenGLData)
        renderer = Renderer{TriangleClusterDependent}(context)
        refs = Vector{UInt32}()
        new(renderer, context._renderers, refs)
    end
end

_Renderer_(self::TriangleClusters)::Renderer = return self._renderer

# GREEN Thread
function added!(self::TriangleClusters,cluster::TriangleClusterDependent)
    aID = UInt32(getGraphID(cluster) + ID_LOWER_BOUND)
    triangulated = if isnothing(cluster._mesh.indices)
        [Vec3F(pos) for pos in cluster._mesh.positions]
    else
        [Vec3F(cluster._mesh.positions[ind+1]) for ind in cluster._mesh.indices]
    end

    ref = add!(
        self._renderers.triangle,
        triangulated,
        Mat4T{Float32}(cluster._transform),
        unpack_color(cluster._color),
        aID)
    push!(self._refs, ref)
end

# GREEN Thread
function sync!(self::TriangleClusters,cluster::TriangleClusterDependent)
    triangulated = if isnothing(cluster._mesh.indices)
        [Vec3F(pos) for pos in cluster._mesh.positions]
    else
        [Vec3F(cluster._mesh.positions[ind+1]) for ind in cluster._mesh.indices]
    end
    ref = self._refs[getObserverID(cluster)]
    update_coords!(self._renderers.triangle,ref,triangulated)
    update_color!(self._renderers.triangle,ref,unpack_color(cluster._color))
    update_transform!(self._renderers.triangle,ref,cluster._transform)
end

# ! Must have
function destroy!(self::TriangleClusters)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::TriangleClusterDependent)::TriangleClusters = getDependentObservers(app)[_TRIANGLE_CLUSTERS]

export TriangleCluster
export get_triangles
export get_positions

# ? ---------------------------------
# ! TriangleCluster
# ? ---------------------------------

# YELLOW Thread
TriangleCluster(callback::Function,mesh::BaseMesh,dependents::Vector{<:DependentDNA}=DependentDNA[];
                color="c") =
build!(TriangleClusterDependent(callback,dependents,mesh,dmat4(1.0),get_color(color)))

TriangleCluster(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[];
                color="c") =
build!(TriangleClusterDependent(callback,dependents,Mesh(),dmat4(1.0),get_color(color)))

TriangleCluster(mesh::BaseMesh;
                color="c") =
build!(TriangleClusterDependent(DEFAULT_CALLBACK,Vector{DependentDNA}(),mesh,dmat4(1.0),get_color(color)))

export TriangleCluster