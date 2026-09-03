mutable struct TriangleCluster
    mesh::Mesh
    transform::Mat4T{Float64}

    function TriangleCluster(mesh::BaseMesh, transform::Mat4T{Float64})
        new(Mesh(get_positions(mesh), get_indices(mesh)), transform)
    end
end

struct TriangleClusterDrawData
    handle::UInt32
    color::UInt32
end

convert_callback_entry(t::TriangleCluster)::TriangleCluster = t

convert_callback_result(t::TriangleCluster,triangles::Vector{Vec3D}) = (t.mesh = Mesh(triangles);t)
convert_callback_result(t::TriangleCluster,triangles::Vector) = (t.mesh = Mesh([Vec3D(v[1],v[2],v[3]) for v in triangles]);t)
function convert_callback_result(t::TriangleCluster,position_indices::Tuple{Any,Vector{UInt32}})
    convert_callback_result(t, position_indices[1])
    t.mesh = Mesh(triangles.mesh.positions,position_indices[2])
    return t
end
function convert_callback_result(t::TriangleCluster,position_indices::Tuple{Any,Vector})
    convert_callback_result(t, position_indices[1])
    t.mesh = Mesh(t.mesh.positions,UInt32.(position_indices[2]))
    return t
end
convert_callback_result(t::TriangleCluster,v::Mesh) = (t.mesh = v;t)
convert_callback_result(t::TriangleCluster,v::AbstractMatrix) = (t.transform = Mat4T{Float64}(v);t)
convert_callback_result(t::TriangleCluster,::Nothing) = (t.transform = dmat4(0.0);t)

function get_triangles(triangles::TriangleCluster)
    p = isapprox(triangles.transform, mat4(1.0)) ? 
        triangles.mesh.positions : 
        [begin
         pp = triangles.transform * Vec4D(p.x,p.y,p.z,1.0)
         Vec3D(pp.x,pp.y,pp.z)
         end
         for p in triangles.mesh.positions]

    let ind = triangles.mesh.indices
        if isnothing(ind)
            return ((p[i], p[i+1], p[i+2]) for i in 1:3:length(p))
        else
            return ((p[ind[i]+1], p[ind[i+1]+1], p[ind[i+2]+1]) for i in 1:3:length(ind))
        end
    end
end

function get_positions(triangles::TriangleCluster)::Vector{Vec3D}
    p = isapprox(triangles.transform, mat4(1.0)) ? 
        triangles.mesh.positions : 
        [begin
         pp = triangles.transform * Vec4D(p.x,p.y,p.z,1.0)
         Vec3D(pp.x,pp.y,pp.z)
         end
         for p in triangles.mesh.positions]

    return isnothing(triangles.mesh.indices) ? p : unique(p)
end

function render_node(triangles::TriangleCluster, data::TriangleClusterDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::TriangleClusterDrawData
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    triangulated = if isnothing(triangles.mesh.indices)
            [Vec3F(pos) for pos in triangles.mesh.positions]
        else
            [Vec3F(triangles.mesh.positions[ind+1]) for ind in triangles.mesh.indices]
        end
    if data.handle == 0
        handle = add!(triangle_renderer, triangulated, Mat4T{Float32}(triangles.transform), data.color, false, id)
        return TriangleClusterDrawData(handle, data.color)
    else
        update_coords!(triangle_renderer, data.handle, triangulated)
        update_color!(triangle_renderer, data.handle, data.color)
        update_transform!(triangle_renderer, data.handle, triangles.transform)
        return data
    end
end

struct PTrianglesOfTriangleCluster <: PrimitivesOf{PTriangle}
    _triangles::Vector{Vec3D}
end
PrimitivesOf(self::TriangleCluster) = PTrianglesOfTriangleCluster(self.mesh.positions)

Base.length(self::PTrianglesOfTriangleCluster) = convert(Integer, length(self._triangles) / 3)
function Base.getindex(self::PTrianglesOfTriangleCluster, index::Integer)
    if (index <= length(self))
        v0 = self._triangles[index * 3 - 2]
        v1 = self._triangles[index * 3 - 1]
        v2 = self._triangles[index * 3]
        return PTriangle(v0,v1,v2)
    else
        return nothing
    end
end
function Base.iterate(self::PTrianglesOfTriangleCluster, index::Integer = 1)
    value = self[index]
    if (value !== nothing)
        return (value, index + 1)
    else
        return nothing
    end
end

export TriangleCluster
export get_triangles
export get_positions

function TriangleCluster(callback::Function, mesh::BaseMesh, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_data::Union{Nothing,String}=nothing;
    color="g")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    draw_data = TriangleClusterDrawData(UInt32(0), c)
    return add_node!(callback, TriangleCluster(mesh, dmat4(1.0)); draw_data=draw_data, parents=parents)
end

TriangleCluster(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_data::Union{Nothing,String}=nothing;
                color="g")::NodeHandle = TriangleCluster(callback,Mesh(),parents,color_data;color=color)

function TriangleCluster(mesh::BaseMesh, color_data::Union{Nothing,String}=nothing;
                color="g")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    draw_data = TriangleClusterDrawData(UInt32(0), c)
    return add_node!(TriangleCluster(mesh, dmat4(1.0)); draw_data=draw_data)
end

function _TriangleCluster(callback::Function,parents::Vector{NodeHandle}, args...; color="g")
    mesh = Mesh()
    color_data::Union{Nothing,String}=nothing
    for arg in args
        if arg isa BaseMesh
            mesh = arg
        else
            color_data = arg
        end
    end
    TriangleCluster(callback,mesh,parents,color_data;color=color)
end

macro TriangleCluster(callback::Expr,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:mesh, :color_data),(:color,), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra._TriangleCluster,
                                positional_args,kw_args)
end

export TriangleCluster
export @TriangleCluster
