
# ? ---------------------------------
# ! Tetrahedra
# ? ---------------------------------

mutable struct Tetrahedron
    a::Vec3D
    b::Vec3D
    c::Vec3D
    d::Vec3D
    color::UInt32
    border_color::UInt32
    border_size::Float32
    border_style::UInt8
    face_handle::UInt32
    border_handle::UInt32

    function Tetrahedron(a::Vec3D,b::Vec3D,c::Vec3D,d::Vec3D,color::UInt32,b_color::UInt32,b_size::Float32,b_style::UInt8)
        return new(a,b,c,d,color,b_color,b_size,b_style,UInt32(0),UInt32(0))
    end
end

convert_callback_entry(t::Tetrahedron)::NTuple{4,Vec3D} = ((t.a,t.b,t.c,t.d);t)

convert_callback_result(t::Tetrahedron, result::NTuple{4,Vec3D}) = (t.a=result[1];t.b=result[2];t.c=result[3];t.d=result[4]; t)
convert_callback_result(t::Tetrahedron, result::Tuple) = (t.a=Vec3D(result[1]...);t.b=Vec3D(result[2]...);t.c=Vec3D(result[3]...);t.d=Vec3D(result[4]...); t)
convert_callback_result(t::Tetrahedron, result::Vector) = (t.a=Vec3D(result[1]...);t.b=Vec3D(result[2]...);t.c=Vec3D(result[3]...);t.d=Vec3D(result[4]...); t)
convert_callback_result(t::Tetrahedron, ::Nothing) = (t.a=Vec3DNan;t.b=Vec3DNan;t.c=Vec3DNan;t.d=Vec3DNan; t)

function render_node(t::Tetrahedron, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    line_renderer::LineRenderer = renderers[LineRenderer]
    a = Vec3F(t.a)
    b = Vec3F(t.b)
    c = Vec3F(t.c)
    d = Vec3F(t.d)
    triangles = Vec3F[a,b,c,a,d,b,a,c,d,b,d,c]
    line = Vec3F[a,b,c,d,a,c,Vec3FNan,b,d]
    if t.face_handle == 0
        t.face_handle = add!(triangle_renderer,triangles,mat4(1.0f0),t.color,id)
        t.border_handle = add!(line_renderer,line,Iterators.cycle((t.border_color,)),Iterators.cycle((id,)),t.border_size,t.border_style)
    else
        update_coords!(triangle_renderer,t.face_handle,triangles)
        update_coords!(line_renderer,t.border_handle,line)
    end
    return nothing
end

_tetrahedron_func(a::Vec3D,b::Vec3D,c::Vec3D,d::Vec3D) = (a,b,c,d)
_get_parent_tetrahedron(parent::NodeHandle) = parent
_get_parent_tetrahedron(parent) = add_node!(Vec3D(parent))

function Tetrahedron(a,b,c,d,color_data::Union{Nothing,String}=nothing;
    color="g",
    border_color="c",border_style="-",border_size=3.0)
    nodes = NodeHandle[
        _get_parent_tetrahedron(a),
        _get_parent_tetrahedron(b),
        _get_parent_tetrahedron(c),
        _get_parent_tetrahedron(d)
    ]
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    (b_c,b_s) = parse_line_colors_style(nothing,border_color,border_style)
    add_node!(_tetrahedron_func,Tetrahedron(Vec3DNan,Vec3DNan,Vec3DNan,Vec3DNan,c,b_c[1],Float32(border_size),b_s),nodes)
end

export Tetrahedron