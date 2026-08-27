const PLANE_N_LENGTH = ceil(Int16, log10(1000))
const PLANE_RANGE = range(-PLANE_N_LENGTH, PLANE_N_LENGTH, 2*PLANE_N_LENGTH + 1)

# ? ---------------------------------
# ! Plane node
# ? ---------------------------------

struct PlaneDrawData
    handle::UInt32
    color::UInt32
end

convert_callback_result(::PPlane, result::PPlane)             = result
convert_callback_result(::PPlane, result::Tuple{Vec3D,Vec3D}) = PPlane(result[1],normalize(result[2]))
convert_callback_result(::PPlane, ::Nothing)                  = PPlane(Vec3DNan,Vec3DNan)

function convert_result(::PPlane,uf::Real,vf::Real,origin::Vec3D,dir1::Vec3D,dir2::Vec3D)
    u = sign(uf) * 10^abs(uf)
    v = sign(vf) * 10^abs(vf)
    return origin + (dir1 * v + dir2 * u)
end
function render_node(plane::PPlane, pdata::PlaneDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::PlaneDrawData
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]

    vertices = FlatMatrixManager{Vec3F}()
    indexes = Vector{UInt32}()
    uvValues = FlatMatrix{Vec3D}(length(PLANE_RANGE), length(PLANE_RANGE))

    origin = plane.p
    dir1 = normalize(perpendicular_vector(plane.n))
    dir2 = normalize(cross(dir1, plane.n))
    for (v, vf) in enumerate(PLANE_RANGE), (u, uf) in enumerate(PLANE_RANGE)
        uvValues[u,v] = convert_result(plane, uf, vf, origin, dir1, dir2)
    end

    width = length(PLANE_RANGE)
    height = length(PLANE_RANGE)
    initMatrix(vertices, width, height, Vec3FNan)

    if pdata.handle == 0
        triangulateInto!(indexes, vertices, layers(vertices))
        copy!(uvValues, vertices, layers(vertices))
        triangles = get_triangulated(data(vertices, layers(vertices)), vertices, layers(vertices))
        handle = add!(triangle_renderer, triangles, mat4(1.0f0), pdata.color, true, id)
        return PlaneDrawData(handle, pdata.color)
    else
        copy!(uvValues, vertices, layers(vertices))
        triangles = get_triangulated(data(vertices, layers(vertices)), vertices, layers(vertices))
        update_coords!(triangle_renderer, pdata.handle, triangles)
        return pdata
    end
end

# ? ---------------------------------
# ! Plane intersection
# ? ---------------------------------

struct PPlaneOfPlane <: PrimitivesOf{PPlane}
    ray::PPlane
end
PrimitivesOf(self::PPlane) = PPlaneOfPlane(self)

Base.length(self::PPlaneOfPlane) = 1
Base.iterate(self::PPlaneOfPlane, index::Integer = 1) = index == 1 ? (self.ray, (index + 1)) : nothing

# ? ---------------------------------
# ! Plane constructors
# ? ---------------------------------

_get_parent_plane(parent::NodeHandle) = parent
_get_parent_plane(parent) = add_node!(Vec3D(parent))

function Plane(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,
    color_data::Union{Nothing,String}=nothing; color="g")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return add_node!(callback, PPlane(Vec3DNan,Vec3DNan); draw_data=PlaneDrawData(UInt32(0), c), parents=parents)
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
        n = cross(dir1,dir2)
        return (point,normalize(n))
    end
end

export Plane
