const POINT_NONE::UInt8 = 0
const POINT_PLUS::UInt8 = 1

@bitflag PointPropertyUpdate::UInt8 begin
    _POINT_PROP_NONE = 0x0
    _POINT_PROP_COORD = 0x1
    _POINT_PROP_COLOR_SIZE = 0x2
    _POINT_PROP_STYLE_ID = 0x4
end

struct PointHandle
    value::UInt
end
PointHandle(::Val{true}, handle::UInt) = PointHandle(handle | (one(UInt) << (Sys.WORD_SIZE - 1)))
PointHandle(::Val{false}, handle::UInt) = PointHandle(handle)
@inline resizeable(handle::PointHandle) = (handle.value & (one(UInt) << (Sys.WORD_SIZE - 1))) != zero(UInt)
@inline index(handle::PointHandle) = handle.value & ~(one(UInt) << (Sys.WORD_SIZE - 1))

function _pack_point_data(a::UInt32, b::UInt8)::UInt32
    lower_mask = ~(UInt32(0xff) << 24)
    return (UInt32(b) << 24) | (a & lower_mask)
end
function _merge_point_data(current::UInt32, lower::UInt32)::UInt32
    upper_mask = UInt32(0xff) << 24
    lower_mask = ~upper_mask
    return (current & upper_mask) | (lower & lower_mask)
end
function _merge_point_data(current::UInt32, upper::UInt8)::UInt32
    upper_mask = UInt32(0xff) << 24
    lower_mask = ~upper_mask
    return (current & lower_mask) | (UInt32(upper) << 24)
end

function _point_renderer_buffer_array()
    attributes = Union{Nothing,Vector{VertexAttrib}}[nothing,
        VertexAttrib[VertexAttrib(false, 4, GL_UNSIGNED_BYTE, GL_TRUE, 0)],   # loc 1: color+size (4 normalized bytes)
        VertexAttrib[VertexAttrib(true, 1, GL_UNSIGNED_INT, GL_FALSE, 0)]]    # loc 2: style_id   (1 uint, offset 0)
    return BufferArray{Tuple{MappedBuffer{Vec3F},MappedBuffer{UInt32},MappedBuffer{UInt32}}}(attributes)
end

@kwdef struct PointsData
    buffer::BufferArray{Tuple{MappedBuffer{Vec3F},MappedBuffer{UInt32},MappedBuffer{UInt32}}} = _point_renderer_buffer_array()
    positions::Vector{Vec3F} = Vector{Vec3F}()
    color_sizes::Vector{UInt32} = Vector{UInt32}()
    style_ids::Vector{UInt32} = Vector{UInt32}()
end

destroy!(points_data::PointsData) = destroy!(points_data.buffer)
Base.length(points_data::PointsData)::Int = length(points_data.positions)

mutable struct PointRenderer
    shader::Pipeline
    shader_behind::Pipeline
    points::Vector{PointsData}
    updates::Vector{PointPropertyUpdate}
end

@inline function _get_slice_and_flag_index(renderer::PointRenderer, handle::PointHandle, len::Int)
    idx = index(handle)
    if resizeable(handle)
        return renderer.points[idx], 1, idx
    else
        return renderer.points[1], Int(idx), 1
    end
end

function _add!(points::PointsData, position::Vec3F, color::UInt32, style::UInt8, size::UInt8, id::UInt32)::Nothing
    push!(points.positions, position)
    push!(points.color_sizes, _pack_point_data(color, size))
    push!(points.style_ids, _pack_point_data(id, style))
    return nothing
end

function _add!(points::PointsData, positions, colors, styles, sizes, id::UInt32)::Nothing
    last_length = length(points.positions)
    append!(points.positions, positions)
    positions_length = length(points.positions) - last_length
    for (color, style, size) in Iterators.take(zip(Iterators.cycle(colors), Iterators.cycle(styles), Iterators.cycle(sizes)), positions_length)
        push!(points.color_sizes, _pack_point_data(color, size))
        push!(points.style_ids, _pack_point_data(id, style))
    end
    return nothing
end

function _add!(points::PointsData, positions, colors, styles, sizes, ids)::Nothing
    last_length = length(points.positions)
    append!(points.positions, positions)
    positions_length = length(points.positions) - last_length
    for (color, style, size, id) in Iterators.take(zip(Iterators.cycle(colors), Iterators.cycle(styles), Iterators.cycle(sizes), Iterators.cycle(ids)), positions_length)
        push!(points.color_sizes, _pack_point_data(color, size))
        push!(points.style_ids, _pack_point_data(id, style))
    end
    return nothing
end

function add!(renderer::PointRenderer, position::Vec3F, color::UInt32, style::UInt8, size::UInt8, id::UInt32)::PointHandle
    _add!(renderer.points[1], position, color, style, size, id)
    return PointHandle(Val(false), UInt(length(renderer.points[1].positions)))
end
add!(renderer::PointRenderer, position::Vec3D, color::UInt32, style::UInt8, size::UInt8, id::UInt32)::PointHandle =
    add!(renderer, Vec3F(position), color, style, size, id)

function add!(renderer::PointRenderer, positions, colors, styles, sizes, id::UInt32, resizeable::Bool=false)::PointHandle
    if resizeable
        push!(renderer.points, PointsData())
        push!(renderer.updates, _POINT_PROP_COORD | _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID)
        points = last(renderer.points)
        _add!(points, positions, colors, styles, sizes, id)
        return PointHandle(Val(true), UInt(length(renderer.points)))
    else
        points = renderer.points[1]
        idx = UInt(length(points.positions) + 1)
        _add!(points, positions, colors, styles, sizes, id)
        renderer.updates[1] = _POINT_PROP_COORD | _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID
        return PointHandle(Val(false), idx)
    end
end

function add!(renderer::PointRenderer, positions, colors, styles, sizes, ids, resizeable::Bool=false)::PointHandle
    if resizeable
        push!(renderer.points, PointsData())
        push!(renderer.updates, _POINT_PROP_COORD | _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID)
        points = last(renderer.points)
        _add!(points, positions, colors, styles, sizes, ids)
        return PointHandle(Val(true), UInt(length(renderer.points)))
    else
        points = renderer.points[1]
        idx = UInt(length(points.positions) + 1)
        _add!(points, positions, colors, styles, sizes, ids)
        _POINT_PROP_COORD | _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID
        return PointHandle(Val(false), idx)
    end
end

function _update_point_data!(renderer::PointRenderer, handle::PointHandle, values, len, flag::PointPropertyUpdate, ::Val{Field}) where Field
    target = if resizeable(handle)
        renderer.updates[index(handle)] |= flag
        view(getproperty(renderer.points[index(handle)], Field), UInt(1):UInt(len))
    else
        renderer.updates[1] |= flag
        view(getproperty(renderer.points[1], Field), UInt(index(handle)):UInt(index(handle)+len-1))
    end
    for (i, val) in enumerate(Iterators.take(Iterators.cycle(values), len))
        target[i] = _merge_point_data(target[i], val)
    end
    return nothing
end


function set_position!(renderer::PointRenderer, handle::PointHandle, position::Vec3F)::Nothing
    points, offset, update_idx = _get_slice_and_flag_index(renderer, handle, 1)
    points.positions[offset] = position
    renderer.updates[update_idx] |= _POINT_PROP_COORD
    return nothing
end
set_position!(renderer::PointRenderer, handle::PointHandle, position::Vec3D)::Nothing =
    set_position!(renderer, handle, Vec3F(position))

function set_position!(renderer::PointRenderer, handle::PointHandle, positions)::Nothing
    len = length(positions)
    points, offset, update_idx = _get_slice_and_flag_index(renderer, handle, len)
    copyto!(view(points.positions, offset:(offset+len-1)), positions)
    renderer.updates[update_idx] |= _POINT_PROP_COORD
    return nothing
end

function set_color!(renderer::PointRenderer, handle::PointHandle, color::UInt32)::Nothing
    color_sizes = renderer.points[1].color_sizes
    color_sizes[offset] = _merge_point_data(color_sizes[offset], color)
    renderer.updates[1] |= _POINT_PROP_COLOR_SIZE
    return nothing
end

function set_color!(renderer::PointRenderer, handle::PointHandle, colors, len::Int)::Nothing
    _update_point_data!(renderer, handle, colors, len, _POINT_PROP_COLOR_SIZE, Val(:color_sizes))
end

function set_style!(renderer::PointRenderer, handle::PointHandle, style::UInt8)::Nothing
    style_ids = points.style_ids[1]
    style_ids[index(handle)] = _merge_point_data(style_ids[index(handle)], style)
    renderer.updates[1] |= _POINT_PROP_STYLE_ID
    return nothing
end

function set_style!(renderer::PointRenderer, handle::PointHandle, styles, len::Int)::Nothing
    _update_point_data!(renderer, handle, styles, len, _POINT_PROP_STYLE_ID, Val(:style_ids))
end

function set_size!(renderer::PointRenderer, handle::PointHandle, size::UInt8)::Nothing
    color_sizes = points.color_sizes[1]
    color_sizes[index(handle)] = _merge_point_data(color_sizes[index(handle)], size)
    renderer.updates[1] |= _POINT_PROP_COLOR_SIZE
    return nothing
end

function set_size!(renderer::PointRenderer, handle::PointHandle, sizes, len::Int)::Nothing
    _update_point_data!(renderer, handle, sizes, len, _POINT_PROP_COLOR_SIZE, Val(:color_sizes))
end

function set_id!(renderer::PointRenderer, handle::PointHandle, id::UInt32)::Nothing
    points, offset, update_idx = _get_slice_and_flag_index(renderer, handle, 1)
    points.style_ids[offset] = _merge_point_data(points.style_ids[offset], id)
    renderer.updates[update_idx] |= _POINT_PROP_STYLE_ID
    return nothing
end

function set_id!(renderer::PointRenderer, handle::PointHandle, ids, len::Int)::Nothing
    _update_point_data!(renderer, handle, ids, len, _POINT_PROP_STYLE_ID, Val(:style_ids))
end

function set_properties!(renderer::PointRenderer, handle::PointHandle, color::UInt32, style::UInt8, size::UInt8, id::UInt32)::Nothing
    set_color!(renderer, handle, color)
    set_size!(renderer, handle, size)
    set_style!(renderer, handle, style)
    set_id!(renderer, handle, id)
    return nothing
end

function set_properties!(renderer::PointRenderer, handle::PointHandle, colors, styles, sizes, ids, len::Int)::Nothing
    set_color!(renderer, handle, colors, len)
    set_size!(renderer, handle, sizes, len)
    set_style!(renderer, handle, styles, len)
    set_id!(renderer, handle, ids, len)
    return nothing
end

function set_properties!(renderer::PointRenderer, handle::PointHandle, positions, colors, styles, sizes, ids)::Nothing
    @assert resizeable(handle) "set_properties! is only supported for resizable point handles"
    idx = index(handle)
    points = renderer.points[idx]

    empty!(points.positions)
    empty!(points.color_sizes)
    empty!(points.style_ids)

    append!(points.positions, positions)
    for (color, style, size, id) in Iterators.take(zip(Iterators.cycle(colors), Iterators.cycle(styles), Iterators.cycle(sizes), Iterators.cycle(ids)), length(positions))
        push!(points.color_sizes, _pack_point_data(color, size))
        push!(points.style_ids, _pack_point_data(id, style))
    end

    renderer.updates[idx] = _POINT_PROP_COORD | _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID
    return nothing
end

function added_all!(points_data::PointsData)
    if length(points_data.buffer[1]) != length(points_data.positions)
        upload!(points_data.buffer, 1, points_data.positions, 0)
        upload!(points_data.buffer, 2, points_data.color_sizes, 0)
        upload!(points_data.buffer, 3, points_data.style_ids, 0)
    end
end

added_all!(self::PointRenderer)::Nothing = foreach(added_all!, self.points)

function sync_all!(points_data::PointsData, update_flags::PointPropertyUpdate)
    n = length(points_data.positions)

    if update_flags & _POINT_PROP_COORD == _POINT_PROP_COORD
        if n != length(points_data.buffer[1])
            reserve!(points_data.buffer, 1, n, 0)
        end
        copyto!(points_data.buffer[1], points_data.positions)
    end

    if update_flags & _POINT_PROP_COLOR_SIZE == _POINT_PROP_COLOR_SIZE
        if n != length(points_data.buffer[2])
            reserve!(points_data.buffer, 2, n, 0)
        end
        copyto!(points_data.buffer[2], points_data.color_sizes)
    end

    if update_flags & _POINT_PROP_STYLE_ID == _POINT_PROP_STYLE_ID
        if n != length(points_data.buffer[3])
            reserve!(points_data.buffer, 3, n, 0)
        end
        copyto!(points_data.buffer[3], points_data.style_ids)
    end
    return nothing
end

function sync_all!(self::PointRenderer)::Bool
    all(u -> u == _POINT_PROP_NONE, self.updates) && return false

    wait(self.points[1].buffer[1])
    for i in 1:length(self.points)
        if self.updates[i] != _POINT_PROP_NONE
            sync_all!(self.points[i], self.updates[i])
        end
        self.updates[i] = _POINT_PROP_NONE
    end
    return true
end

function opaque(self::PointRenderer, cam::Camera, window::GLFWData)::Nothing
    activate(self.shader)
    @time_gpu_begin Renderer Point
    for points_data in self.points
        if length(points_data.positions) != 0
            draw(points_data.buffer, GL_POINTS)
        end
    end
    @time_gpu_end Renderer Point
    lock(self.points[1].buffer[1])
    deactivate(self.shader)
    return nothing
end

function behind_opaque(self::PointRenderer, cam::Camera, window::GLFWData)::Nothing
    activate(self.shader_behind)
    for points_data in self.points
        if length(points_data.positions) != 0
            draw(points_data.buffer, GL_POINTS)
        end
    end
    deactivate(self.shader_behind)
    return nothing
end

function PointRenderer(loader::PipelineLoader)::PointRenderer
    shader::Pipeline = create_graphics_pipeline!(loader;
        vert=spv"renderers/point/point.vert",
        frag=(spv"renderers/point/point.frag", Tuple{GLuint,GLuint}[(0, 0)]))
    shader_behind::Pipeline = create_graphics_pipeline!(loader;
        vert=spv"renderers/point/point.vert",
        frag=(spv"renderers/point/point.frag", Tuple{GLuint,GLuint}[(0, 1)]))

    shader_behind.set_state = () -> begin
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        glColorMaski(1, GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)
    end
    shader_behind.unset_state = () -> begin
        glColorMaski(1, GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
        glDisable(GL_BLEND)
    end
    return PointRenderer(shader, shader_behind, PointsData[PointsData()], PointPropertyUpdate[_POINT_PROP_NONE])
end

function reset!(self::PointRenderer)::Nothing
    foreach(destroy!, self.points)
    self.points = PointsData[PointsData()]
    self.updates = PointPropertyUpdate[_POINT_PROP_NONE]
    return nothing
end

function destroy!(self::PointRenderer)::Nothing
    foreach(destroy!, self.points)
    return nothing
end