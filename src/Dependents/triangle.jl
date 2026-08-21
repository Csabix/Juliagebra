
# ? ---------------------------------
# ! Triangle node
# ? ---------------------------------

struct TriangleDrawData
    handle::UInt32
    color::UInt32
end

convert_callback_result(::PTriangle, result::PTriangle)                = result
convert_callback_result(::PTriangle, result::Tuple{Vec3D,Vec3D,Vec3D}) = PTriangle(result[1],result[2],result[3])
convert_callback_result(::PTriangle, ::Nothing)                        = PTriangle(Vec3DNan,Vec3DNan,Vec3DNan)

function render_node(triangle::PTriangle, draw_data::TriangleDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::TriangleDrawData
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    vertices = [triangle.v0, triangle.v1, triangle.v2]
    if draw_data.handle == 0
        handle = add!(triangle_renderer, vertices, mat4(1.0f0), draw_data.color, true, id)
        return TriangleDrawData(handle, draw_data.color)
    else
        update_coords!(triangle_renderer, draw_data.handle, vertices)
        return draw_data
    end
end

# ? ---------------------------------
# ! Triangle intersection
# ? ---------------------------------

struct PTriangleOfTriangle <: PrimitivesOf{PTriangle}
    triangle::PTriangle
end
PrimitivesOf(self::PTriangle) = PTriangleOfTriangle(self)

Base.length(self::PTriangleOfTriangle) = 1
Base.iterate(self::PTriangleOfTriangle, index::Integer = 1) = index == 1 ? (self.triangle, (index + 1)) : nothing

# ? ---------------------------------
# ! Triangle constructors
# ? ---------------------------------

_get_parent_triangle(parent::NodeHandle,::Bool) = parent
# _get_parent_triangle(parent,create_vertex::Bool=false;color="g") =
#     create_vertex ? Point(p -> p,[parent];color=color,size=50) : add_node!(Vec3D(parent))
_get_parent_triangle(parent,::Bool) = add_node!(Vec3D(parent))

function Triangle(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing,color_data::Union{Nothing,String}=nothing;
    face::Bool=true,edges::Bool=false,vertices::Bool=false,color="g")::NodeHandle

    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return add_node!(callback, PTriangle(Vec3DNan,Vec3DNan,Vec3DNan); draw_data=TriangleDrawData(UInt32(0), c), parents=parents)
end

function Triangle(A,B,C,color_data::Union{Nothing,String}=nothing;
    face::Bool=true,edges::Bool=false,vertices::Bool=false,color="g")

    parents = NodeHandle[
        _get_parent_triangle(A,vertices),
        _get_parent_triangle(B,vertices),
        _get_parent_triangle(C,vertices),
    ]

    result = Any[]
    if (face)
        ABC = Triangle(parents,color_data;color=color,face=face,edges=edges,vertices=vertices) do v0,v1,v2
            return (v0,v1,v2)
        end
        push!(result, ABC)
    end

    if (edges)
        AB = Segment(A,B; color=color)
        BC = Segment(B,C; color=color)
        CA = Segment(C,A; color=color)
        push!(result, (AB,BC,CA))
    end
    if (vertices)
        push!(result, Tuple(parents))
    end

    return length(result) == 1 ? result[1] : Tuple(result)
end

export Triangle