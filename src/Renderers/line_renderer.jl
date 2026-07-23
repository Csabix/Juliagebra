const SOLID::UInt8          = 1
const DASHED::UInt8         = 2
const DOTTED::UInt8         = 3
const WAVE::UInt8           = 4
const DASH_DOT::UInt8       = 5
const ARROW::UInt8          = 6
const ARROW_REVERSED::UInt8 = ARROW | (one(UInt8) << 7)
const _LINE_TYPE_COUNT::UInt8 = 6

export SOLID, DASHED, DOTTED, WAVE, DASH_DOT, ARROW, ARROW_REVERSED

@inline get_type_reversed(line_type::UInt8)::Tuple{UInt8,Bool} = 
    (line_type & ~0x80), ((line_type & 0x80) == 0x80)

@inline set_alpha_byte(color::UInt32, alpha::UInt32)::UInt32 = 
    (alpha << 24) | (color & ~(UInt32(0xff) << 24))

@inline pack_color_reversed(color::UInt32, reversed::Bool)::UInt32 = 
    set_alpha_byte(color, UInt32(reversed ? 0xff : 0x00))

@inline function apply_reversed_flag!(color_style, reversed::Bool)
    rev_val = UInt32(reversed ? 0xff : 0x00)
    map!(e -> set_alpha_byte(e, rev_val), color_style, color_style)
end

@bitflag LinePropertyUpdate::UInt8 begin
    _LINE_PROP_NONE        = 0x0
    _LINE_PROP_COORD       = 0x1
    _LINE_PROP_STYLE       = 0x2
    _LINE_PROP_COLOR_STYLE = 0x4
    _LINE_PROP_COORD_SIZE  = 0x8
end

struct LineHandle
    value::UInt
end
LineHandle(::Val{true}, handle::UInt)  = LineHandle(handle | (one(UInt) << (Sys.WORD_SIZE - 1)))
LineHandle(::Val{false}, handle::UInt) = LineHandle(handle)
@inline resizeable(handle::LineHandle) = (handle.value & (one(UInt) << (Sys.WORD_SIZE - 1))) != zero(UInt)
@inline index(handle::LineHandle)      = handle.value & ~(one(UInt) << (Sys.WORD_SIZE - 1))

mutable struct LineData
    coords_sizes::Vector{Vec4F}
    color_style::Vector{UInt32}
    distances::Vector{Float32}

    distance_buffer_in::MappedBuffer{Float32}
    color_style_buffer_in::Buffer{UInt32}
    position_width_buffer_in::MappedBuffer{Vec4F}
end

LineData(coords_sizes::Vector{Vec4F}, color_style::Vector{UInt32}) = LineData(
    coords_sizes, color_style, Float32[],
    MappedBuffer{Float32}(), Buffer{UInt32}(), MappedBuffer{Vec4F}()
)
LineData() = LineData(Vec4F[Vec4FNan], UInt32[0x0])

function destroy!(line_data::LineData)
    destroy!(line_data.distance_buffer_in)
    destroy!(line_data.color_style_buffer_in)
    destroy!(line_data.position_width_buffer_in)
end

@kwdef mutable struct LineOutputData
    position_distance_buffer::Buffer{Vec4F} = Buffer{Vec4F}()
    color_buffer::Buffer{UVec2}             = Buffer{UVec2}()
    begin_pos_rad_buffer::Buffer{Vec4F}     = Buffer{Vec4F}()
    sdf_buffer::Buffer{Vec4F}               = Buffer{Vec4F}()
    end_pos_rad_buffer::Buffer{Vec4F}       = Buffer{Vec4F}()
end

function destroy!(out::LineOutputData)
    destroy!(out.position_distance_buffer)
    destroy!(out.color_buffer)
    destroy!(out.begin_pos_rad_buffer)
    destroy!(out.sdf_buffer)
    destroy!(out.end_pos_rad_buffer)
end

function reserve!(out::LineOutputData, N::Int, flags::Int=0)
    reserve!(out.position_distance_buffer, 5 * N, flags)
    reserve!(out.color_buffer, N, flags)
    reserve!(out.begin_pos_rad_buffer, N, flags)
    reserve!(out.sdf_buffer, 5 * N, flags)
    reserve!(out.end_pos_rad_buffer, N, flags)
end

function bind_ssbo_output(out::LineOutputData, base_binding::Int = 0)
    bind_ssbo(out.position_distance_buffer, base_binding + 0)
    bind_ssbo(out.color_buffer,            base_binding + 1)
    bind_ssbo(out.begin_pos_rad_buffer,    base_binding + 2)
    bind_ssbo(out.sdf_buffer,              base_binding + 3)
    bind_ssbo(out.end_pos_rad_buffer,      base_binding + 4)
end

mutable struct LineRenderer
    emptyVAO::VertexArray
    
    shader_predraw::Pipeline
    shaders_opaque::Vector{Pipeline}
    shaders_behind_opaque::Vector{Pipeline}
    shaders_transparent::Vector{Pipeline}
    
    # Static
    updated::LinePropertyUpdate
    ranges::Vector{Tuple{Int,Int,Int}}
    draw_ranges::Vector{Tuple{Int,Int}}

    data_static::LineData
    output_static::LineOutputData

    gpu_gpu_sync::GLsync

    # Dynamic
    UBO::RepeatBufferUBO{GLuint}
    update_list::Vector{UInt32}
    types_dynamic::Vector{UInt8}
    draw_ranges_dynamic::Vector{Tuple{Int,Int}}
    data_dynamic::Vector{LineData}
    output_dynamic::LineOutputData
    gpu_gpu_sync_dynamic::GLsync

    function LineRenderer(loader::PipelineLoader)
        emptyVAO = VertexArray()
        
        shader_predraw = create_compute_pipeline!(loader,spv"renderers/line/line.comp")
        shaders_opaque = Vector{Pipeline}()
        shaders_behind_opaque = Vector{Pipeline}()
        shaders_transparent = Vector{Pipeline}()
        for i in 0:(_LINE_TYPE_COUNT - 1) 
            push!(shaders_opaque,create_graphics_pipeline!(loader;
                vert = spv"renderers/line/line.vert",
                frag = (spv"renderers/line/line_opaque.frag",Tuple{GLuint,GLuint}[(0,0),(1,GLuint(i))])
            ))
        end
        for i in 0:(_LINE_TYPE_COUNT - 1) 
            push!(shaders_behind_opaque,create_graphics_pipeline!(loader;
                vert = spv"renderers/line/line.vert",
                frag = (spv"renderers/line/line_opaque.frag",Tuple{GLuint,GLuint}[(0,1),(1,GLuint(i))])
            ))
        end
        for i in 0:(_LINE_TYPE_COUNT - 1) 
            push!(shaders_transparent,create_graphics_pipeline!(loader;
                vert = spv"renderers/line/line.vert",
                frag = (spv"renderers/line/line_transparent.frag",Tuple{GLuint,GLuint}[(0,0),(1,GLuint(i))])
            ))
        end

        return new(
            emptyVAO, shader_predraw, shaders_opaque, shaders_behind_opaque, shaders_transparent,
            _LINE_PROP_NONE, Vector{Tuple{Int,Int,Int}}(), fill((0,0), _LINE_TYPE_COUNT),
            LineData(), LineOutputData(), C_NULL,
            RepeatBufferUBO{GLuint}(), Vector{UInt32}(), Vector{UInt8}(), fill((0,0), _LINE_TYPE_COUNT),
            Vector{LineData}(), LineOutputData(), C_NULL
        )
    end
end

function destroy!(self::LineRenderer)::Nothing
    destroy!(self.emptyVAO)
    destroy!(self.data_static)
    destroy!(self.output_static)
    foreach(destroy!, self.data_dynamic)
    destroy!(self.output_dynamic)
    return nothing
end

function reset!(self::LineRenderer)::Nothing
    destroy!(self.data_static)
    destroy!(self.output_static)
    foreach(destroy!, self.data_dynamic)
    destroy!(self.output_dynamic)

    self.ranges = Vector{Tuple{Int,Int,Int}}()
    self.draw_ranges = fill((0,0), _LINE_TYPE_COUNT)
    self.data_static = LineData()
    self.output_static = LineOutputData()

    self.update_list = Vector{UInt32}()
    self.types_dynamic = Vector{UInt8}()
    self.draw_ranges_dynamic = fill((0,0), _LINE_TYPE_COUNT)
    self.data_dynamic = Vector{LineData}()
    self.output_dynamic = LineOutputData()
    return nothing
end

function _pack_line_data(coords, colors, width::Float32, reversed::Bool)
    coords_sizes = Vector{Vec4F}()
    color_style  = Vector{UInt32}()
    
    push!(coords_sizes, Vec4FNan)
    append!(coords_sizes, (Vec4F(c..., width) for c in coords))
    push!(coords_sizes, Vec4FNan)

    push!(color_style, 0x0)
    append!(color_style, (pack_color_reversed(c, reversed) for c in take(Iterators.cycle(colors), length(coords))))
    push!(color_style, 0x0)

    return coords_sizes, color_style
end
#=
function add!(self::LineRenderer, coords, colors, ids, width::Float32, type::UInt8)::UInt32
    (type, reversed) = get_type_reversed(type)
    first = length(self.data_static.coords_sizes) + 1
    
    append!(self.data_static.coords_sizes, (Vec4F(coord..., width) for coord in coords))
    push!(self.data_static.coords_sizes, Vec4FNan)

    append!(self.data_static.color_style, (pack_color_reversed(color, reversed) for color in take(colors, length(coords))))
    push!(self.data_static.color_style, UInt32(0))

    last = length(self.data_static.coords_sizes) - 1
    push!(self.ranges, (first, last, Int(type)))
    return UInt32(length(self.ranges))
end
=#
function add!(self::LineRenderer, positions, colors, style::UInt8, size::Float32, ids, resizeable::Bool = false)::LineHandle
    (style, reversed) = get_type_reversed(style)
    if resizeable
        coords_sizes, color_style = _pack_line_data(positions, colors, size, reversed)
        push!(self.types_dynamic, style)
        push!(self.data_dynamic, LineData(coords_sizes, color_style))
        return LineHandle(Val(true), UInt64(length(self.data_dynamic)))
    else
        first = length(self.data_static.coords_sizes) + 1
    
        append!(self.data_static.coords_sizes, (Vec4F(coord..., size) for coord in positions))
        push!(self.data_static.coords_sizes, Vec4FNan)

        append!(self.data_static.color_style, (pack_color_reversed(color, reversed) for color in Iterators.take(Iterators.cycle(colors),length(positions))))
        push!(self.data_static.color_style, UInt32(0))

        last = length(self.data_static.coords_sizes) - 1
        push!(self.ranges, (first, last, Int(style)))
        return LineHandle(Val(false), UInt64(length(self.ranges)))
    end
end
#=
function add_dynamic!(self::LineRenderer, coords, colors, ids, width::Float32, type::UInt8)::UInt32
    (type, reversed) = get_type_reversed(type)
    coords_sizes, color_style = _pack_line_data(coords, colors, width, reversed)

    push!(self.types_dynamic, type)
    push!(self.data_dynamic, LineData(coords_sizes, color_style))
    return UInt32(length(self.data_dynamic))
end
=#

function _sort_lines!(self::LineRenderer)
    range_groups = [Vector{Int}() for _ in 1:_LINE_TYPE_COUNT]
    for index = 1:length(self.ranges)
        push!(range_groups[self.ranges[index][3]], index)
    end

    coords_sizes = Vec4F[Vec4FNan]
    sizehint!(coords_sizes, length(self.data_static.coords_sizes))
    color_style = UInt32[0x0]
    sizehint!(color_style, length(self.data_static.coords_sizes))

    draw_first = 0
    @inbounds for (index, group) in enumerate(range_groups)
        draw_count = 0
        @inbounds for range_ind in group
            (first, last, type) = self.ranges[range_ind]
            draw_count += last - first + 2
            self.ranges[range_ind] = (length(coords_sizes) + 1, length(coords_sizes) + last - first + 1, type)
            
            append!(coords_sizes, view(self.data_static.coords_sizes, first:last))
            append!(color_style, view(self.data_static.color_style, first:last))
            
            push!(coords_sizes, Vec4FNan)
            push!(color_style, 0x0)
        end
        self.draw_ranges[index] = (draw_first, draw_count == 0 ? 0 : (draw_count - 2))
        draw_first += draw_count
    end

    self.data_static.coords_sizes = coords_sizes
    self.data_static.color_style = color_style
end

@inline function _compute_strip_distances!(distances::Vector{Float32}, coords_sizes::Vector{Vec4F}, first_idx::Int, last_idx::Int, vp::Mat4, wh::Vec2F)
    distance_sum::Float32 = 0.0f0
    @inbounds for i in first_idx:(last_idx-1)
        cw1::Vec4F = coords_sizes[i]
        cw2::Vec4F = coords_sizes[i+1]
        a::Vec4F = vp * Vec4F(cw1[1], cw1[2], cw1[3], 1.0f0)
        b::Vec4F = vp * Vec4F(cw2[1], cw2[2], cw2[3], 1.0f0)
        
        if a[3] + a[4] < 0.0f0 && b[3] + b[4] < 0.0f0 continue end
        
        t0::Float32 = a[3] + a[4]
        t1::Float32 = b[3] + b[4]
        
        if t0 < 0.0f0
            tt = t0 / (t0 - t1)
            a = @. a * (1 - tt) + b * tt
        elseif t1 < 0.0f0
            tt = t1 / (t1 - t0)
            b = @. b * (1 - tt) + a * tt
        end
        
        a2::Vec2F = Vec2F(a[1], a[2]) / a[4]
        a2 = @. a2 * 0.5f0 + 0.5f0
        a2 = @. a2 * wh

        b2::Vec2F = Vec2F(b[1], b[2]) / b[4]
        b2 = @. b2 * 0.5f0 + 0.5f0
        b2 = @. b2 * wh

        distances[i] = distance_sum
        segment_dist = norm(a2 - b2)::Float32
        distance_sum = !isnan(segment_dist) ? distance_sum + segment_dist : 0.0f0
    end
    @inbounds distances[last_idx] = distance_sum
end

function _calc_distances!(self::LineRenderer, vp::Mat4, wh::Vec2F)
    @time_cpu_begin Renderer Line Distances Static
    Threads.@threads for (first, last, _) in self.ranges
        _compute_strip_distances!(self.data_static.distances, self.data_static.coords_sizes, first, last, vp, wh)
    end
    @time_cpu_end Renderer Line Distances Static
    copyto!(self.data_static.distance_buffer_in, self.data_static.distances)
end

function _calc_distances_dynamic!(self::LineRenderer, vp::Mat4, wh::Vec2F)
    @time_cpu_begin Renderer Line Distances Dynamic
    Threads.@threads for index in 1:length(self.data_dynamic)
        d = self.data_dynamic[index]
        _compute_strip_distances!(d.distances, d.coords_sizes, 1, length(d.coords_sizes), vp, wh)
    end
    @time_cpu_end Renderer Line Distances Dynamic

    @inbounds for i in 1:length(self.data_dynamic)
        copyto!(self.data_dynamic[i].distance_buffer_in, self.data_dynamic[i].distances)
    end
end

function added_static!(self::LineRenderer)::Nothing
    _sort_lines!(self)
    upload!(self.data_static.position_width_buffer_in, self.data_static.coords_sizes, 0)
    upload!(self.data_static.color_style_buffer_in, self.data_static.color_style, 0)

    N = length(self.data_static.coords_sizes)
    self.data_static.distances = Vector{Float32}(undef, N)
    reserve!(self.data_static.distance_buffer_in, N, 0)
    reserve!(self.output_static, N - 3, 0)
    
    self.updated = _LINE_PROP_NONE
    return nothing
end

function added_dynamic!(self::LineRenderer)::Nothing
    for d in self.data_dynamic
        if isempty(d.distances)
            upload!(d.position_width_buffer_in, d.coords_sizes, 0)
            upload!(d.color_style_buffer_in, d.color_style, 0)
            N = length(d.coords_sizes)
            d.distances = Vector{Float32}(undef, N)
            reserve!(d.distance_buffer_in, N, 0)
        end
    end
    
    N = sum(d -> length(d.coords_sizes) <= 3 ? 0 : (length(d.coords_sizes) - 3), self.data_dynamic)
    reserve!(self.output_dynamic, N, 0)
    return nothing
end

function added_all!(self::LineRenderer)::Nothing
    N = length(self.data_static.coords_sizes)
    if N != length(self.data_static.position_width_buffer_in) && N > 1
        added_static!(self)
    end
    if any(d -> isempty(d.distances), self.data_dynamic)
        added_dynamic!(self)
    end
    return nothing
end
function set_position!(self::LineRenderer, handle::LineHandle, positions)::Nothing
    @assert !resizeable(handle) "set_position! is currently only supported for non-resizable line handles"
    (first, last, _) = self.ranges[index(handle)]
    first == last && return nothing

    v = view(self.data_static.coords_sizes, first:last)
    for (i, pos) in enumerate(positions)
        i > length(v) && break
        size = v[i][4]
        v[i] = Vec4F(pos[1], pos[2], pos[3], size)
    end
    self.updated |= _LINE_PROP_COORD_SIZE
    return nothing
end

function set_color!(self::LineRenderer, handle::LineHandle, color::UInt32)::Nothing
    set_color!(self, handle, (color,))
    return nothing
end

function set_color!(self::LineRenderer, handle::LineHandle, colors)::Nothing
    if resizeable(handle)
        idx = index(handle)
        cs = self.data_dynamic[idx].color_style
        length(cs) <= 2 && return nothing

        for (i, color) in enumerate(Iterators.take(Iterators.cycle(colors), length(cs) - 2))
            cs[i + 1] = set_alpha_byte(color, cs[i + 1] >> 24)
        end
        push!(self.update_list, idx)
    else
        (first, last, _) = self.ranges[index(handle)]
        first == last && return nothing

        v = view(self.data_static.color_style, first:last)
        for (i, color) in enumerate(Iterators.take(Iterators.cycle(colors), last - first + 1))
            v[i] = set_alpha_byte(color, v[i] >> 24)
        end
        self.updated |= _LINE_PROP_COLOR_STYLE
    end
    return nothing
end

function set_style!(self::LineRenderer, handle::LineHandle, style::UInt8)::Nothing
    (new_style, new_reversed) = get_type_reversed(style)
    
    if resizeable(handle)
        idx = index(handle)
        cs = self.data_dynamic[idx].color_style
        length(cs) <= 2 && return nothing

        old_reversed = (cs[2] >> 24) != 0
        self.types_dynamic[idx] = new_style

        if xor(new_reversed, old_reversed)
            apply_reversed_flag!(cs, new_reversed)
        end
        push!(self.update_list, idx)
    else
        idx = index(handle)
        (first, last, old_style) = self.ranges[idx]
        first == last && return nothing

        old_reversed = (self.data_static.color_style[first] >> 24) != 0

        if new_style != old_style
            self.ranges[idx] = (first, last, new_style)
            self.updated |= _LINE_PROP_STYLE
        end

        if xor(new_reversed, old_reversed)
            apply_reversed_flag!(view(self.data_static.color_style, first:last), new_reversed)
            self.updated |= _LINE_PROP_COLOR_STYLE
        end
    end
    return nothing
end

function set_size!(self::LineRenderer, handle::LineHandle, size::Float32)::Nothing
    if resizeable(handle)
        idx = index(handle)
        cs = self.data_dynamic[idx].coords_sizes
        length(cs) <= 2 && return nothing

        for i in 2:(length(cs) - 1)
            c = cs[i]
            cs[i] = Vec4F(c[1], c[2], c[3], size)
        end
        push!(self.update_list, idx)
    else
        idx = index(handle)
        (first, last, _) = self.ranges[idx]
        first == last && return nothing

        map!(e -> Vec4F(e[1], e[2], e[3], size), view(self.data_static.coords_sizes, first:last))
        self.updated |= _LINE_PROP_COORD_SIZE
    end
    return nothing
end

# Single-value / property update convenience
function set_properties!(self::LineRenderer, handle::LineHandle, color::UInt32, style::UInt8, size::Float32)::Nothing
    set_color!(self, handle, color)
    set_style!(self, handle, style)
    set_size!(self, handle, size)
    return nothing
end

function set_properties!(self::LineRenderer, handle::LineHandle, colors, style::UInt8, size::Float32)::Nothing
    set_color!(self, handle, colors)
    set_style!(self, handle, style)
    set_size!(self, handle, size)
    return nothing
end

# Full element rebuild (supported for resizable handles)
function set_properties!(self::LineRenderer, handle::LineHandle, positions, colors, style::UInt8, size::Float32)::Nothing
    @assert resizeable(handle) "Full set_properties! with positions is only supported for resizable line handles"
    idx = index(handle)
    (style, reversed) = get_type_reversed(style)

    coords_sizes, color_style = _pack_line_data(positions, colors, size, reversed)
    d = self.data_dynamic[idx]
    d.coords_sizes = coords_sizes
    d.color_style  = color_style

    self.types_dynamic[idx] = style
    push!(self.update_list, idx)
    return nothing
end

function sync_all!(self::LineRenderer)::Bool
    if (self.updated & _LINE_PROP_STYLE) == _LINE_PROP_STYLE
        _sort_lines!(self)
        self.updated |= _LINE_PROP_COORD_SIZE | _LINE_PROP_COLOR_STYLE
    end
    
    scene_change::Bool = false
    if (self.updated & _LINE_PROP_COORD_SIZE) == _LINE_PROP_COORD_SIZE || (self.updated & _LINE_PROP_COLOR_STYLE) == _LINE_PROP_COLOR_STYLE
        if (self.updated & _LINE_PROP_COORD_SIZE) == _LINE_PROP_COORD_SIZE
            copyto!(self.data_static.position_width_buffer_in, self.data_static.coords_sizes)
        end
        if (self.updated & _LINE_PROP_COLOR_STYLE) == _LINE_PROP_COLOR_STYLE
            upload!(self.data_static.color_style_buffer_in, self.data_static.color_style, 0)
        end
        scene_change = true
    end

    if !isempty(self.update_list)
        for ref in self.update_list
            d = self.data_dynamic[ref]
            upload!(d.position_width_buffer_in, d.coords_sizes, 0)
            upload!(d.color_style_buffer_in, d.color_style, 0)
            
            N = length(d.coords_sizes)
            Base.resize!(d.distances, N)
            reserve!(d.distance_buffer_in, N, 0)
        end
        empty!(self.update_list)

        N = sum(d -> length(d.coords_sizes) <= 3 ? 0 : (length(d.coords_sizes) - 3), self.data_dynamic)
        if N > length(self.output_dynamic.color_buffer)
            reserve!(self.output_dynamic, N, 0)
        end
        scene_change = true
    end

    self.updated = _LINE_PROP_NONE
    return scene_change
end

function _bind_ssbo_input(input_data::LineData)
    bind_ssbo(input_data.distance_buffer_in, 0)
    bind_ssbo(input_data.color_style_buffer_in, 1)
    bind_ssbo(input_data.position_width_buffer_in, 2)
end

function pre_draw(self::LineRenderer, cam::Camera, window::GLFWData)::Nothing
    if isempty(self.data_static.coords_sizes) && isempty(self.data_dynamic) return nothing end

    prev_offset::UInt32 = 0
    offset::UInt32 = 0
    offsets = Vector{GLuint}()
    sizehint!(offsets, max(length(self.data_dynamic), 1))
    
    for i in 1:_LINE_TYPE_COUNT
        for j in 1:length(self.data_dynamic)
            if self.types_dynamic[j] != i || length(self.data_dynamic[j].coords_sizes) <= 3 continue end
            push!(offsets, GLuint(offset))
            offset += UInt32(length(self.data_dynamic[j].coords_sizes) - 3)
        end
        self.draw_ranges_dynamic[i] = (prev_offset, offset - prev_offset)
        prev_offset = offset
    end

    if isempty(offsets) push!(offsets, GLuint(0)) end

    if length(self.UBO) != length(offsets)
        upload!(self.UBO, offsets, GL_DYNAMIC_STORAGE_BIT)
    else
        upload!(self.UBO, offsets)
    end

    (vp, v, p) = get_matrices(cam)

    # Static
    if length(self.data_static.coords_sizes) > 1
        _calc_distances!(self, vp, Vec2F(window.width, window.height))

        _bind_ssbo_input(self.data_static)
        bind_ssbo_output(self.output_static, 3)

        activate(self.shader_predraw)
        bind_ubo(self.UBO, 1, 8) 
        @time_gpu_begin Renderer Line Pre_Draw Static
        glDispatchCompute(cld(length(self.data_static.coords_sizes), 32), 1, 1);
        @time_gpu_end Renderer Line Pre_Draw Static
        self.gpu_gpu_sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
    end
    
    # Dynamic
    if !isempty(self.data_dynamic)
        _calc_distances_dynamic!(self, vp, Vec2F(window.width, window.height))
        bind_ssbo_output(self.output_dynamic, 3)

        activate(self.shader_predraw)
        index = 1
        @time_gpu_begin Renderer Line Pre_Draw Dynamic
        for i in 1:_LINE_TYPE_COUNT
            for j in 1:length(self.data_dynamic)
                d = self.data_dynamic[j]
                if self.types_dynamic[j] != i || length(d.coords_sizes) <= 3 continue end
                _bind_ssbo_input(d)
                bind_ubo(self.UBO, index, 8)
                glDispatchCompute(cld(length(d.coords_sizes), 32), 1, 1);
                index += 1
            end
        end
        @time_gpu_end Renderer Line Pre_Draw Dynamic

        self.gpu_gpu_sync_dynamic = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
    end
    return nothing
end

# Internal unified draw pass
function _draw_lines_pass!(self::LineRenderer, output::LineOutputData, draw_ranges, sync_fence, shaders)
    any(x -> x[2] != 0, draw_ranges) || return
    if sync_fence != C_NULL
        glWaitSync(sync_fence, 0, 0xFFFFFFFFFFFFFFFF)
        glDeleteSync(sync_fence)
    end

    activate(self.emptyVAO)
    bind_ssbo_output(output, 0)

    @inbounds for type in 1:_LINE_TYPE_COUNT
        (first, count) = draw_ranges[type]
        count == 0 && continue
        activate(shaders[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
end

function opaque(self::LineRenderer, cam::Camera, window::GLFWData)::Nothing
    @time_gpu_begin Renderer Line Opaque Static
    _draw_lines_pass!(self, self.output_static, self.draw_ranges, self.gpu_gpu_sync, self.shaders_opaque)
    @time_gpu_end Renderer Line Opaque Static

    @time_gpu_begin Renderer Line Opaque Dynamic
    _draw_lines_pass!(self, self.output_dynamic, self.draw_ranges_dynamic, self.gpu_gpu_sync_dynamic, self.shaders_opaque)
    @time_gpu_end Renderer Line Opaque Dynamic
    return nothing
end

function behind_opaque(self::LineRenderer, cam::Camera, window::GLFWData)::Nothing
    glEnable(GL_BLEND)
    glBlendColor(0.0, 0.0, 0.0, 0.4)
    glBlendFunc(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA)
    glColorMaski(1, GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)

    _draw_lines_pass!(self, self.output_static, self.draw_ranges, C_NULL, self.shaders_behind_opaque)
    _draw_lines_pass!(self, self.output_dynamic, self.draw_ranges_dynamic, C_NULL, self.shaders_behind_opaque)

    glColorMaski(1, GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glDisable(GL_BLEND)
    return nothing
end

function transparent(self::LineRenderer, cam::Camera, window::GLFWData)::Nothing
    @time_gpu_begin Renderer Line Transparent Static
    _draw_lines_pass!(self, self.output_static, self.draw_ranges, C_NULL, self.shaders_transparent)
    @time_gpu_end Renderer Line Transparent Static

    @time_gpu_begin Renderer Line Transparent Dynamic
    _draw_lines_pass!(self, self.output_dynamic, self.draw_ranges_dynamic, C_NULL, self.shaders_transparent)
    @time_gpu_end Renderer Line Transparent Dynamic
    return nothing
end