
# ? ---------------------------------
# ! Tetrahedra
# ? ---------------------------------

mutable struct Tetrahedron
    a::Vec3D
    b::Vec3D
    c::Vec3D
    d::Vec3D

    function Tetrahedron(a::Vec3D=Vec3DNan, b::Vec3D=Vec3DNan, c::Vec3D=Vec3DNan, d::Vec3D=Vec3DNan)
        return new(a, b, c, d)
    end
end

struct TetrahedronDrawData
    face_handle::UInt32
    border_handle::UInt32
    color::UInt32
    border_color::UInt32
    border_size::Float32
    border_style::UInt8
end

convert_callback_entry(t::Tetrahedron)::NTuple{4,Vec3D} = ((t.a,t.b,t.c,t.d);t)

convert_callback_result(t::Tetrahedron, result::NTuple{4,Vec3D}) = (t.a=result[1];t.b=result[2];t.c=result[3];t.d=result[4]; t)
convert_callback_result(t::Tetrahedron, result::Tuple) = (t.a=Vec3D(result[1]...);t.b=Vec3D(result[2]...);t.c=Vec3D(result[3]...);t.d=Vec3D(result[4]...); t)
convert_callback_result(t::Tetrahedron, result::Vector) = (t.a=Vec3D(result[1]...);t.b=Vec3D(result[2]...);t.c=Vec3D(result[3]...);t.d=Vec3D(result[4]...); t)
convert_callback_result(t::Tetrahedron, ::Nothing) = (t.a=Vec3DNan;t.b=Vec3DNan;t.c=Vec3DNan;t.d=Vec3DNan; t)

function render_node(t::Tetrahedron, data::TetrahedronDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::TetrahedronDrawData
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    line_renderer::LineRenderer = renderers[LineRenderer]
    a = Vec3F(t.a)
    b = Vec3F(t.b)
    c = Vec3F(t.c)
    d = Vec3F(t.d)
    triangles = Vec3F[a, b, c, a, d, b, a, c, d, b, d, c]
    line = Vec3F[a, b, c, d, a, c, Vec3FNan, b, d]

    if data.face_handle == 0
        face_handle = add!(triangle_renderer, triangles, mat4(1.0f0), data.color, false, id)
        border_handle = add!(line_renderer, line, Iterators.cycle((data.border_color,)), Iterators.cycle((id,)), data.border_size, data.border_style)
        return TetrahedronDrawData(face_handle, border_handle, data.color, data.border_color, data.border_size, data.border_style)
    else
        update_coords!(triangle_renderer, data.face_handle, triangles)
        update_coords!(line_renderer, data.border_handle, line)
        return data
    end
end

_tetrahedron_func(a::Vec3D,b::Vec3D,c::Vec3D,d::Vec3D) = (a,b,c,d)
_get_parent_tetrahedron(parent::NodeHandle) = parent
_get_parent_tetrahedron(parent) = add_node!(Vec3D(parent))

function Tetrahedron(a, b, c, d, color_data::Union{Nothing,String}=nothing;
    color="g", border_color="c", border_style="-", border_size=3.0)
    nodes = NodeHandle[
        _get_parent_tetrahedron(a),
        _get_parent_tetrahedron(b),
        _get_parent_tetrahedron(c),
        _get_parent_tetrahedron(d)
    ]
    c_val = isnothing(color_data) ? get_color(color) : get_color(color_data)
    (b_c, b_s) = parse_line_colors_style(nothing, border_color, border_style)
    draw_data = TetrahedronDrawData(UInt32(0), UInt32(0), c_val, b_c[1], Float32(border_size), b_s)
    add_node!(_tetrahedron_func, Tetrahedron(); draw_data=draw_data, parents=nodes)
end

export Tetrahedron