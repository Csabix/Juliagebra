const PLANE_N_LENGTH = ceil(Int16, log10(1000))
const PLANE_RANGE = range(-PLANE_N_LENGTH, PLANE_N_LENGTH, 2*PLANE_N_LENGTH + 1)

# ? ---------------------------------
# ! Plane node
# ? ---------------------------------

mutable struct Plane
    primitive::PPlane

    vertexes::FlatMatrixManager{Vec3F}
    indexes::Vector{UInt32}
    uvValues::FlatMatrix{Vec3D}
    uvNormals::FlatMatrix{Vec3D}
    layer::Int

    color::UInt32
    handle::UInt32

    function Plane(color::UInt32)
        vertexes = FlatMatrixManager{Vec3F}()
        indexes = Vector{UInt32}()
        uvValues = FlatMatrix{Vec3D}(length(PLANE_RANGE),length(PLANE_RANGE))
        uvNormals = FlatMatrix{Vec3D}(length(PLANE_RANGE),length(PLANE_RANGE))
        new(PPlane(Vec3DNan,Vec3DNan),vertexes,indexes,uvValues,uvNormals,0,color,UInt32(0))
    end
end

function convert_result(plane::Plane,u_idx,v_idx,uf,vf)
    p = plane.primitive.p
    n = plane.primitive.n
    vector = Vec3D(1,0,0)
    # ? picking a vector that is non collinear with the plane normal
    if (n.y == 0.0 && n.z == 0.0)
        vector = Vec3D(0,1,0)
    end

    dir1 = normalize(cross(vector, n))
    perp = normalize(cross(dir1, n))
    u = sign(uf) * 10^abs(uf)
    v = sign(vf) * 10^abs(vf)
    plane.uvValues[u_idx,v_idx] = p + (dir1 * v + perp * u)
end
function setFirstNormal!(plane::Plane, u::Int, v::Int, w::Int, h::Int)
    vals = plane.uvValues

    right = vals[min(u + 1, w), v]
    left  = vals[max(u - 1, 1), v]
    down  = vals[u, min(v + 1, h)]
    up    = vals[u, max(v - 1, 1)]

    uVec = right - left
    vVec = down - up
    plane.uvNormals[u, v] = normalize(cross(uVec, vVec))
end
function setNormalSameAsFirst!(plane::Plane, u::Int, v::Int)
    plane.uvNormals[u, v] = plane.uvNormals[1, 1]
end
function eval_node(plane::Plane, callback::Function, arguments::Vector{Any})::Any
    (p,n) = callback(arguments...)
    plane.primitive = PPlane(p,n)

    for (v, vf) in enumerate(PLANE_RANGE), (u, uf) in enumerate(PLANE_RANGE)
        convert_result(plane, u, v, uf, vf)
    end
    
    w = width(plane.uvValues)
    h = height(plane.uvValues)
    for v in 1:h, u in 1:w
        if (v == 1 && u == 1)
            setFirstNormal!(plane, u, v, w, h)
        else
            setNormalSameAsFirst!(plane, u, v)
        end
    end

    return plane
end

function render_node(ps::Plane, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    if ps.handle == 0
        width = length(PLANE_RANGE)
        height = length(PLANE_RANGE)
        initMatrix(ps.vertexes,width,height,Vec3FNan)
        triangulateInto!(ps.indexes,ps.vertexes,layers(ps.vertexes))
        copy!(ps.uvValues,ps.vertexes,layers(ps.vertexes))
        triangles = get_triangulated(data(ps.vertexes, layers(ps.vertexes)),ps.vertexes,layers(ps.vertexes))
        ps.handle = add!(triangle_renderer,triangles,mat4(1.0f0),ps.color,true,id)
    else
        copy!(ps.uvValues,ps.vertexes,layers(ps.vertexes))
        triangles = get_triangulated(data(ps.vertexes, layers(ps.vertexes)),ps.vertexes,layers(ps.vertexes))
        update_coords!(triangle_renderer,ps.handle,triangles)
    end
    return nothing
end

p0(plane::Plane) = plane.primitive.p
n(plane::Plane) = plane.primitive.n

# ? ---------------------------------
# ! Plane intersection
# ? ---------------------------------

struct PPlaneOfPlane <: PrimitivesOf{PPlane}
    ray::PPlane
end
PrimitivesOf(self::Plane) = PPlaneOfPlane(self.primitive)

Base.length(self::PPlaneOfPlane) = 1
Base.iterate(self::PPlaneOfPlane, index::Integer = 1) = index == 1 ? (self.ray, (index + 1)) : nothing

# ? ---------------------------------
# ! Plane constructors
# ? ---------------------------------

_get_parent_plane(parent::NodeHandle) = parent
_get_parent_plane(parent) = add_node!(Vec3D(parent))

function Plane(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,
    color_data::Union{Nothing,String}=nothing;color="g")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return add_node!(callback,Plane(c),parents)
end

function Plane(p0,p1,p2,color_data::Union{Nothing,String}=nothing;
    color="g")::NodeHandle

    parents = NodeHandle[
        _get_parent_plane(p0),
        _get_parent_plane(p1),
        _get_parent_plane(p2),
    ]

    return Plane(parents,color_data;color=color) do p0,p1,p2
        dir1 = p1 - p0
        dir2 = p2 - p0
        n = cross(dir1,dir2)
        return (p0,normalize(n))
    end
end

function Plane(point,line,color_data::Union{Nothing,String}=nothing;
    color="g")::NodeHandle

    parents = NodeHandle[
        _get_parent_plane(point),
        _get_parent_plane(line),
    ]

    return Plane(parents,color_data;color=color) do point,line
        dir1 = p0(line) - point
        dir2 = p1(line) - point
        normal = cross(dir1,dir2)
        return (point,normal)
    end
end

export Plane
export p0,n
