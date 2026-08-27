const SOLID::UInt8          = 1
const DASHED::UInt8         = 2
const DOTTED::UInt8         = 3
const WAVE::UInt8           = 4
const DASH_DOT::UInt8       = 5
const ARROW::UInt8          = 6
const ARROW_REVERSED::UInt8 = 7
const _LINE_STYLE_COUNT     = 7

export SOLID, DASHED, DOTTED, WAVE, DASH_DOT, ARROW, ARROW_REVERSED

const _LINE_COLOR_MASK::UInt32 = ~(UInt32(0xff) << 24)
const _LINE_GROUP_MIN_CAPACITY::Int = 1 << 13

@inline function pack_color_style(color::UInt32, style::UInt8)::UInt32
    return (UInt32(style) << 24) | (color & _LINE_COLOR_MASK)
end

# ? ---------------------------------
# ! LineHandle
# ? ---------------------------------

struct LineHandle
    value::UInt32
    LineHandle() = new(0)
    LineHandle(value::UInt32) = new(value)
end

is_null(handle::LineHandle)::Bool = handle.value == 0

export LineHandle

# ? ---------------------------------
# ! Group
# ? ---------------------------------

mutable struct LineGroup
    style::UInt8
    positions::Vector{Vector{Vec3F}}
    colors::Vector{Vector{UInt32}}
    handles::Vector{UInt32}
    widths::Vector{Float32}

    capacity::Int
    used::Int
    dirty::Bool

    position_buffer::MappedBuffer{Vec4F}      # xyz + width
    color_style_buffer::MappedBuffer{UInt32}  # style + rgb
    distance_buffer::MappedBuffer{Float32}    # screen space distance along the line

    function LineGroup(style::UInt8, needed::Int)
        capacity = max(_LINE_GROUP_MIN_CAPACITY, needed + 1)
        position_buffer    = MappedBuffer{Vec4F}()
        color_style_buffer = MappedBuffer{UInt32}()
        distance_buffer    = MappedBuffer{Float32}()
        reserve!(position_buffer, capacity, 0)
        reserve!(color_style_buffer, capacity, 0)
        reserve!(distance_buffer, capacity, 0)
        position_buffer[1] = Vec4FNan
        return new(
            style,
            Vector{Vector{Vec3F}}(), Vector{Vector{UInt32}}(),
            Vector{UInt32}(), Vector{Float32}(),
            capacity, 1, true,
            position_buffer, color_style_buffer, distance_buffer)
    end
end

@inline _instance_count(self::LineGroup)::Int = self.used - 3

function _destroy_group!(self::LineGroup)::Nothing
    destroy!(self.position_buffer)
    destroy!(self.color_style_buffer)
    destroy!(self.distance_buffer)
    return nothing
end

function _flush_group!(self::LineGroup)::Nothing
    self.dirty || return nothing

    positions = self.position_buffer
    color_styles = self.color_style_buffer
    distances = self.distance_buffer

    positions[1] = Vec4FNan
    color_styles[1] = UInt32(0)
    distances[1] = 0.0f0
    index = 2

    style = self.style
    @inbounds for line in eachindex(self.positions)
        points = self.positions[line]
        colors = self.colors[line]
        width = self.widths[line]
        color_count = length(colors)
        color_index = 1
        for point in points
            positions[index] = Vec4F(point[1], point[2], point[3], width)
            color_styles[index] = pack_color_style(colors[color_index], style)
            color_index = isnan(point[1]) ? 1 : mod1(color_index + 1, color_count)
            index += 1
        end

        positions[index] = Vec4FNan
        color_styles[index] = UInt32(0)
        distances[index] = 0.0f0
        index += 1
    end

    self.used = index - 1
    self.dirty = false
    return nothing
end

# ? ---------------------------------
# ! Renderer
# ? ---------------------------------

mutable struct LineRenderer <: Renderer
    emptyVAO::VertexArray

    shaders_opaque::Vector{Pipeline}
    shaders_behind_opaque::Vector{Pipeline}
    shaders_transparent::Vector{Pipeline}

    pool::Vector{Union{Nothing,LineGroup}}
    handle_map::Vector{Tuple{UInt32,UInt32}} # handle -> (group index, index within group)
    free_handles::Vector{UInt32}

    # GREEN Thread
    function LineRenderer(loader::PipelineLoader)
        emptyVAO = VertexArray()

        shaders_opaque = Vector{Pipeline}()
        shaders_behind_opaque = Vector{Pipeline}()
        shaders_transparent = Vector{Pipeline}()

        for i in 0:(_LINE_STYLE_COUNT - 2)
            push!(shaders_opaque, create_graphics_pipeline!(loader;
                vert = spv"renderers/line/line.vert",
                frag = (spv"renderers/line/line_opaque.frag", Tuple{GLuint,GLuint}[(0, 0), (1, GLuint(i))])
            ))
            push!(shaders_behind_opaque, create_graphics_pipeline!(loader;
                vert = spv"renderers/line/line.vert",
                frag = (spv"renderers/line/line_opaque.frag", Tuple{GLuint,GLuint}[(0, 1), (1, GLuint(i))])
            ))
            push!(shaders_transparent, create_graphics_pipeline!(loader;
                vert = spv"renderers/line/line.vert",
                frag = (spv"renderers/line/line_transparent.frag", Tuple{GLuint,GLuint}[(0, 0), (1, GLuint(i))])
            ))
        end
        push!(shaders_opaque, create_graphics_pipeline!(loader;
            vert = (spv"renderers/line/line.vert",Tuple{GLuint,GLuint}[(0, reinterpret(GLuint, -1.0f0))]),
            frag = (spv"renderers/line/line_opaque.frag", Tuple{GLuint,GLuint}[(0, 0), (1, GLuint(ARROW-1))])
        ))
        push!(shaders_behind_opaque, create_graphics_pipeline!(loader;
            vert = (spv"renderers/line/line.vert",Tuple{GLuint,GLuint}[(0, reinterpret(GLuint, -1.0f0))]),
            frag = (spv"renderers/line/line_opaque.frag", Tuple{GLuint,GLuint}[(0, 1), (1, GLuint(ARROW-1))])
        ))
        push!(shaders_transparent, create_graphics_pipeline!(loader;
            vert = (spv"renderers/line/line.vert",Tuple{GLuint,GLuint}[(0, reinterpret(GLuint, -1.0f0))]),
            frag = (spv"renderers/line/line_transparent.frag", Tuple{GLuint,GLuint}[(0, 0), (1, GLuint(ARROW-1))])
        ))

        return new(
            emptyVAO,
            shaders_opaque, shaders_behind_opaque, shaders_transparent,
            Vector{Union{Nothing,LineGroup}}(),
            Vector{Tuple{UInt32,UInt32}}(),
            Vector{UInt32}()
        )
    end
end

function clear!(self::LineRenderer)::Nothing
    for group in self.pool
        group === nothing && continue
        _destroy_group!(group)
    end
    empty!(self.pool)
    empty!(self.handle_map)
    empty!(self.free_handles)
    return nothing
end

function destroy!(self::LineRenderer)::Nothing
    for group in self.pool
        group === nothing && continue
        _destroy_group!(group)
    end
    destroy!(self.emptyVAO)
    return nothing
end

# ? ---------------------------------
# ! Handles and placement
# ? ---------------------------------

function _acquire_handle!(self::LineRenderer)::LineHandle
    if isempty(self.free_handles)
        push!(self.handle_map, (UInt32(0), UInt32(0)))
        return LineHandle(UInt32(length(self.handle_map)))
    end
    value = pop!(self.free_handles)
    @inbounds self.handle_map[value] = (UInt32(0), UInt32(0))
    return LineHandle(value)
end

Base.@propagate_inbounds function _resolve_line(self::LineRenderer, handle::LineHandle)::Tuple{Int,Int}
    value = handle.value
    @boundscheck checkbounds(Bool, self.handle_map, value) || throw(BoundsError(self.handle_map, value))
    @inbounds (group_index, line_index) = self.handle_map[value]
    @boundscheck begin
        checkbounds(Bool, self.pool, group_index) && 
        self.pool[group_index] !== nothing && 
        checkbounds(Bool, self.pool[group_index].positions, line_index) || 
        throw(BoundsError(self.pool, (group_index, line_index)))
    end
    return (Int(group_index), Int(line_index))
end

# First group matching style with room, otherwise a new one sized to fit.
function _find_group!(self::LineRenderer, style::UInt8, needed::Int)::Int
    for index in eachindex(self.pool)
        @inbounds group = self.pool[index]
        group === nothing && continue
        if group.style == style && group.used + needed <= group.capacity
            return index
        end
    end

    group = LineGroup(style, needed)
    slot = findfirst(isnothing, self.pool)
    if slot === nothing
        push!(self.pool, group)
        return length(self.pool)
    end
    @inbounds self.pool[slot] = group
    return slot
end

function _place_line!(self::LineRenderer, handle_value::UInt32,
                    points::Vector{Vec3F}, colors::Vector{UInt32},
                    style::UInt8, width::Float32)::Nothing
    needed = length(points) + 1 # Point count + trailing NaN
    group_index = _find_group!(self, style, needed)
    @inbounds group::LineGroup = self.pool[group_index]::LineGroup

    push!(group.positions, points)
    push!(group.colors, colors)
    push!(group.handles, handle_value)
    push!(group.widths, width)

    group.used += needed
    group.dirty = true

    @inbounds self.handle_map[handle_value] = (UInt32(group_index), UInt32(length(group.positions)))
    return nothing
end

# Detaches the line from its group and gives its data back. The handle itself is
# not released, so a relocation can reuse it.
function _unplace_line!(self::LineRenderer, handle_value::UInt32)::Tuple{Vector{Vec3F},Vector{UInt32},UInt8,Float32}
    @inbounds (group_index_u, line_index_u) = self.handle_map[handle_value]
    group = self.pool[group_index_u]::LineGroup
    line_index = Int(line_index_u)

    points = group.positions[line_index]
    colors = group.colors[line_index]
    style  = group.style
    width  = group.widths[line_index]

    group.used -= length(points) + 1

    last_index = length(group.positions)
    if line_index != last_index
        @inbounds group.positions[line_index] = group.positions[last_index]
        @inbounds group.colors[line_index]    = group.colors[last_index]
        @inbounds group.handles[line_index]   = group.handles[last_index]
        @inbounds group.widths[line_index]    = group.widths[last_index]
        moved_handle = group.handles[line_index]
        @inbounds self.handle_map[moved_handle] = (group_index_u, UInt32(line_index))
    end

    pop!(group.positions)
    pop!(group.colors)
    pop!(group.handles)
    pop!(group.widths)

    group.dirty = true
    @inbounds self.handle_map[handle_value] = (UInt32(0), UInt32(0))

    if group.used == 1
        println("destroy called")
        @assert length(group.positions) == 0
        _destroy_group!(group)
        self.pool[group_index_u] = nothing
    end

    return (points, colors, style, width)
end

# ? ---------------------------------
# ! Input conversion
# ? ---------------------------------

@inline _as_vec3f(coord::Vec3F)::Vec3F = coord
@inline function _as_vec3f(coord)::Vec3F
    return length(coord) >= 3 ?
        Vec3F(Float32(coord[1]), Float32(coord[2]), Float32(coord[3])) :
        Vec3F(Float32(coord[1]), Float32(coord[2]), 0.0f0)
end

@inline _line_has_length(iter)::Bool = Base.IteratorSize(iter) isa Union{Base.HasLength,Base.HasShape}

function _assert_line_finite(iter, what::String)::Nothing
    if Base.IteratorSize(iter) isa Base.IsInfinite
        throw(ArgumentError("LineRenderer: $what must be finite - colors are cycled internally, " *
                            "pass the source vector instead of Iterators.cycle(...)"))
    end
    return nothing
end

_to_line_points(coords::Vector{Vec3F})::Vector{Vec3F} = copy(coords)
function _to_line_points(coords)::Vector{Vec3F}
    _assert_line_finite(coords, "coords")
    out = Vector{Vec3F}()
    _line_has_length(coords) && sizehint!(out, length(coords))
    for coord in coords
        push!(out, _as_vec3f(coord))
    end
    return out
end

_to_line_colors(colors::Vector{UInt32})::Vector{UInt32} = copy(colors)
function _to_line_colors(colors)::Vector{UInt32}
    _assert_line_finite(colors, "colors")
    out = Vector{UInt32}()
    _line_has_length(colors) && sizehint!(out, length(colors))
    for color in colors
        push!(out, UInt32(color))
    end
    return out
end

# ? ---------------------------------
# ! Public API
# ? ---------------------------------

function add!(self::LineRenderer, coords::Vector{Vec3F}, colors::Vector{UInt32},
              ids::Vector{UInt32}, style::UInt8, size::Float32)::LineHandle
    handle = _acquire_handle!(self)
    _place_line!(self, handle.value, copy(coords), copy(colors), style, size)
    return handle
end

function add!(self::LineRenderer, coords, colors, ids, style::UInt8, size::Float32)::LineHandle
    handle = _acquire_handle!(self)
    _place_line!(self, handle.value, _to_line_points(coords), _to_line_colors(colors), style, size)
    return handle
end

function remove!(self::LineRenderer, handle::LineHandle)::Nothing
    _resolve_line(self, handle)
    _unplace_line!(self, handle.value)
    push!(self.free_handles, handle.value)
    return nothing
end

Base.@propagate_inbounds function update_coords!(self::LineRenderer, handle::LineHandle, coords::Vector{Vec3F})::Nothing
    (group_index, line_index) = _resolve_line(self, handle)
    group = self.pool[group_index]::LineGroup
    points = group.positions[line_index]

    delta = length(coords) - length(points)

    if delta == 0
        copyto!(points, coords)
        group.dirty = true
        return nothing
    end

    if group.used + delta <= group.capacity
        Base.resize!(points, length(coords))
        copyto!(points, coords)
        group.used += delta
        group.dirty = true
        return nothing
    end

    # Does not fit any more: detach, resize, and re-place through normal allocation path.
    (old_points, colors, style, width) = _unplace_line!(self, handle.value)
    Base.resize!(old_points, length(coords))
    copyto!(old_points, coords)
    _place_line!(self, handle.value, old_points, colors, style, width)
    return nothing
end

Base.@propagate_inbounds function update_coords!(self::LineRenderer, handle::LineHandle, coords)::Nothing
    (group_index, line_index) = _resolve_line(self, handle)
    group = self.pool[group_index]::LineGroup
    points = group.positions[line_index]

    if _line_has_length(coords) && length(coords) == length(points)
        index = 1
        @inbounds for coord in coords
            points[index] = _as_vec3f(coord)
            index += 1
        end
        group.dirty = true
        return nothing
    end

    return update_coords!(self, handle, _to_line_points(coords))
end

Base.@propagate_inbounds function update_colors!(self::LineRenderer, handle::LineHandle, colors::Vector{UInt32})::Nothing
    (group_index, line_index) = _resolve_line(self, handle)
    group = self.pool[group_index]::LineGroup
    destination = group.colors[line_index]
    Base.resize!(destination, length(colors))
    copyto!(destination, colors)
    group.dirty = true
    return nothing
end

Base.@propagate_inbounds function update_colors!(self::LineRenderer, handle::LineHandle, colors)::Nothing
    return update_colors!(self, handle, _to_line_colors(colors))
end

Base.@propagate_inbounds function update_size!(self::LineRenderer, handle::LineHandle, size::Float32)::Nothing
    (group_index, line_index) = _resolve_line(self, handle)
    group = self.pool[group_index]::LineGroup
    group.widths[line_index] = size
    group.dirty = true
    return nothing
end

Base.@propagate_inbounds function update_style!(self::LineRenderer, handle::LineHandle, style::UInt8)::Nothing
    (group_index, line_index) = _resolve_line(self, handle)
    group = self.pool[group_index]::LineGroup
    group.style == style && return nothing

    # Relocate line to a group matching the target style
    (points, colors, _, width) = _unplace_line!(self, handle.value)
    _place_line!(self, handle.value, points, colors, style, width)
    return nothing
end

# ? ---------------------------------
# ! Distances
# ? ---------------------------------

@inline function _plane_dist(p::Vec4F, plane::Int)::Float32
    if plane == 1
        return p[3] + p[4]
    elseif plane == 2
        return p[1] + p[4]
    elseif plane == 3
        return p[4] - p[1]
    elseif plane == 4
        return p[2] + p[4]
    else
        return p[4] - p[2]
    end
end

@inline function _screen_segment_dist(c1::Vec3F, c2::Vec3F, vp::Mat4, wh::Vec2F)::Float32
    if isnan(c1[1]) || isnan(c2[1])
        return NaN32
    end

    a = vp * Vec4F(c1[1], c1[2], c1[3], 1.0f0)
    b = vp * Vec4F(c2[1], c2[2], c2[3], 1.0f0)

    for plane in 1:5
        da = _plane_dist(a, plane)
        db = _plane_dist(b, plane)

        if da < 0.0f0 && db < 0.0f0
            return NaN32
        elseif da < 0.0f0
            tt = da / (da - db)
            a = @. a * (1.0f0 - tt) + b * tt
        elseif db < 0.0f0
            tt = db / (db - da)
            b = @. b * (1.0f0 - tt) + a * tt
        end
    end

    (a[4] <= 0.0f0 || b[4] <= 0.0f0) && return NaN32

    a2 = Vec2F(a[1], a[2]) / a[4]
    a2 = @. (a2 * 0.5f0 + 0.5f0) * wh

    b2 = Vec2F(b[1], b[2]) / b[4]
    b2 = @. (b2 * 0.5f0 + 0.5f0) * wh

    d = norm(a2 - b2)
    return isnan(d) ? NaN32 : Float32(d)
end

function _calc_group_distances!(group::LineGroup, vp::Mat4, wh::Vec2F)::Nothing
    distances = group.distance_buffer
    distances[1] = NaN32
    index = 2

    @inbounds for positions in group.positions
        distance_sum::Float32 = 0.0f0
        len = length(positions)

        for i in 1:len
            p1 = positions[i]
            if isnan(p1[1])
                distances[index] = NaN32
                distance_sum = 0.0f0
            else
                distances[index] = distance_sum
                if i < len
                    p2 = positions[i + 1]
                    segment_dist = _screen_segment_dist(p1, p2, vp, wh)
                    
                    if isnan(segment_dist)
                        distance_sum = 0.0f0
                    else
                        distance_sum += segment_dist
                    end
                end
            end
            index += 1
        end
        distances[index] = NaN32
        index += 1
    end
    return nothing
end

function _calc_distances!(self::LineRenderer, vp::Mat4, wh::Vec2F)::Nothing
    @time_cpu_begin Renderer Line Distances
    Threads.@threads for group in self.pool
        group === nothing && continue
        isempty(group.positions) && continue
        _calc_group_distances!(group, vp, wh)
    end
    @time_cpu_end Renderer Line Distances
    return nothing
end

# ? ---------------------------------
# ! Frame
# ? ---------------------------------

function _has_drawable(self::LineRenderer)::Bool
    for group in self.pool
        group === nothing && continue
        _instance_count(group) > 0 && return true
    end
    return false
end

function pre_draw!(self::LineRenderer, cam::Camera, window::GLFWData)::Nothing
    _has_drawable(self) || return nothing

    for group_or_nothing in self.pool
        group_or_nothing === nothing && continue
        group::LineGroup = group_or_nothing
        wait(group.position_buffer)
        _flush_group!(group)
    end

    (vp, v, p) = get_matrices(cam)
    _calc_distances!(self, vp, Vec2F(window.width, window.height))
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)
    return nothing
end

function _draw_groups!(self::LineRenderer, shaders::Vector{Pipeline})::Nothing
    activate(self.emptyVAO)
    for style_idx in 1:_LINE_STYLE_COUNT
        shader = shaders[style_idx]
        shader_activated = false

        for group_or_nothing in self.pool
            group_or_nothing === nothing && continue
            group::LineGroup = group_or_nothing
            group.style == UInt8(style_idx) || continue

            instances = _instance_count(group)
            instances <= 0 && continue

            if !shader_activated
                activate(shader)
                shader_activated = true
            end

            bind_ssbo(group.distance_buffer, 0)
            bind_ssbo(group.color_style_buffer, 1)
            bind_ssbo(group.position_buffer, 2)
            glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, instances, 0)
        end
    end
    return nothing
end

function draw_opaque!(self::LineRenderer, ::Camera, ::GLFWData)::Nothing
    _has_drawable(self) || return nothing
    @time_gpu_begin Renderer Line Opaque
    _draw_groups!(self, self.shaders_opaque)
    @time_gpu_end Renderer Line Opaque
    return nothing
end

visible_behind_opaque(self::LineRenderer)::Bool = true
function draw_behind_opaque!(self::LineRenderer, ::Camera, ::GLFWData)::Nothing
    _has_drawable(self) || return nothing

    glEnable(GL_BLEND)
    glBlendColor(0.0, 0.0, 0.0, 0.4)
    glBlendFunc(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA)
    glColorMaski(1, GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)

    @time_gpu_begin Renderer Line Behind-Opaque
    _draw_groups!(self, self.shaders_behind_opaque)
    @time_gpu_end Renderer Line Behind-Opaque

    glColorMaski(1, GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glDisable(GL_BLEND)
    return nothing
end

function draw_transparent!(self::LineRenderer, ::Camera, ::GLFWData)::Nothing
    _has_drawable(self) || return nothing

    @time_gpu_begin Renderer Line Transparent
    _draw_groups!(self, self.shaders_transparent)
    @time_gpu_end Renderer Line Transparent

    for group_or_nothing in self.pool
        group_or_nothing === nothing && continue
        group::LineGroup = group_or_nothing
        lock(group.position_buffer)
    end
    return nothing
end