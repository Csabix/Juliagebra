mutable struct Point
    coord::Vec3D

    function Point()
        new(Vec3DNan)
    end
    function Point(coord::Vec3D)
        new(coord)
    end
end

struct PointDrawData
    handle::UInt32
    color::UInt32
    style::UInt8
    size::UInt8
    constraints::UInt8
end

convert_callback_entry(point::Point)::Vec3D = point.coord

convert_callback_result(point::Point, result) = (point.coord=Vec3D(result); point)
convert_callback_result(point::Point, result::Tuple) = (point.coord=Vec3D(result...); point)
convert_callback_result(point::Point, result::Vector) = (point.coord=Vec3D(result...); point)
convert_callback_result(point::Point, result::Vec3F) = (point.coord=Vec3D(result...); point)
convert_callback_result(point::Point, result::Vec3D) = (point.coord=result; point)
convert_callback_result(point::Point, ::Nothing) = (point.coord=Vec3DNan; point)

function render_node(point::Point, data::PointDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::PointDrawData
    point_renderer::PointRenderer = renderers[PointRenderer]
    if data.handle == 0
        handle = add!(point_renderer, Vec3F(point.coord), data.color, data.style, data.size, id)
        return PointDrawData(handle, data.color, data.style, data.size, data.constraints)
    else
        update_coords!(point_renderer, data.handle, Vec3F(point.coord))
        return data
    end
end

on_gizmo_select(point::Point,data::PointDrawData)::Tuple{UInt32,Vec3D,Any} = (UInt32(data.constraints), point.coord, nothing)
on_gizmo_move(point::Point, position::Vec3D, data::Any)::Tuple{Any,Any} = (point.coord = position;(point, nothing))

edit_node_overload(point::Point)::Bool = true
function edit_node(point::Point, data::PointDrawData, renderers::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Any,Int}
    result = EDIT_NODE_NONE
    coord = point.coord
    x_ref = Ref(Cdouble(coord.x))
    y_ref = Ref(Cdouble(coord.y))
    z_ref = Ref(Cdouble(coord.z))
    if CImGui.InputDouble("##x$handle", x_ref, 0.0, 0.0, "%.4f")
        point.coord = Vec3D(x_ref[],coord[2],coord[3])
        result |= EDIT_NODE_INVALIDATE
    end
    if CImGui.InputDouble("##y$handle", y_ref, 0.0, 0.0, "%.4f")
        point.coord = Vec3D(coord[1],y_ref[],coord[3])
        result |= EDIT_NODE_INVALIDATE
    end
    if CImGui.InputDouble("##z$handle", z_ref, 0.0, 0.0, "%.4f")
        point.coord = Vec3D(coord[1],coord[2],z_ref[])
        result |= EDIT_NODE_INVALIDATE
    end
    new_color = color_edit3(data.color, "##pcol$id")
        if new_color !== nothing
            data = PointDrawData(data.handle,new_color,data.style,data.style,data.constraints)
            update_colors!(renderers[PointRenderer]::PointRenderer,data.handle,new_color)
            result |= EDIT_NODE_RERENDER
        end
    return point, data, result
end

function Point(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
    color="m", style=".", size=25, axis_constraint=AXIS_NONE)::NodeHandle
    (c, s) = parse_point_color_style(color_style, color, style)
    return add_node!(callback,Point();draw_data=PointDrawData(zero(UInt32),c,s,round(UInt8, size),UInt8(axis_constraint)),parents=parents)
end

function Point(x::Real, y::Real, z::Real, color_style::Union{Nothing,String}=nothing;
    color="m", style=".", size=25, axis_constraint=AXIS_X|AXIS_Y|AXIS_Z)::NodeHandle
    (c, s) = parse_point_color_style(color_style, color, style)
    return add_node!(Point(Vec3D(x, y, z));draw_data=PointDrawData(zero(UInt32),c,s,round(UInt8, size),UInt8(axis_constraint)))
end

function Point(x::Real, y::Real, color_style::Union{Nothing,String}=nothing;
    color="m", style=".", size=25, axis_constraint=AXIS_X|AXIS_Y)::NodeHandle
    (c, s) = parse_point_color_style(color_style, color, style)
    return add_node!(Point(Vec3D(x, y, 0.0));draw_data=PointDrawData(zero(UInt32),c,s,round(UInt8, size),UInt8(axis_constraint)))
end

macro Point(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,), (:color, :style, :size, :axis_constraint), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Point,
        positional_args, kw_args)
end

export Point
export @Point