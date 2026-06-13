# GREEN Thread

const SOLID::UInt8    = 1
const DASHED::UInt8   = 2
const DOTTED::UInt8   = 3
const WAVE::UInt8     = 4
const DASH_DOT::UInt8 = 5
const ARROW::UInt8    = 6
const ARROW_REVERSED::UInt8 = ARROW | (one(UInt8) << 7)
const _LINE_TYPE_COUNT::UInt8   = 6

function get_type_reversed(line_type::UInt8)::Tuple{UInt8,Bool}
    mask::UInt8 = (one(UInt8) << 7)
    return line_type & ~mask, (line_type & mask) == mask
end

@bitflag LinePropertyUpdate::UInt8 begin
    _LINE_PROP_NONE        = 0x0
    _LINE_PROP_COORD       = 0x1
    _LINE_PROP_STYLE       = 0x2
    _LINE_PROP_COLOR_STYLE = 0x4
    _LINE_PROP_COORD_SIZE  = 0x8
end

export SOLID, DASHED, DOTTED, 
        WAVE, DASH_DOT, ARROW, ARROW_REVERSED

mutable struct LineRenderer
    updated::LinePropertyUpdate
    emptyVAO::VertexArray

    shader_predraw::ShaderProgram
    shaders_opaque::Vector{ShaderProgram}
    shaders_behind_opaque::Vector{ShaderProgram}
    shaders_transparent::Vector{ShaderProgram}

    # Static
    ranges::Vector{Tuple{Int,Int,Int}}
    draw_ranges::Vector{Tuple{Int,Int}}

    coords_sizes::Vector{Vec4F}
    color_style::Vector{UInt32}

    distances::Vector{Float32} # to avoid memory allocations

    distance_buffer_in::MappedBuffer{Float32}
    color_style_buffer_in::Buffer{UInt32}
    position_width_buffer_in::MappedBuffer{Vec4F}

    position_distance_buffer_out::Buffer{Vec4F}
    color_buffer_out::Buffer{UVec2}
    begin_pos_rad::Buffer{Vec4F}
    sdf_buffer_out::Buffer{Vec4F}
    end_pos_rad::Buffer{Vec4F}

    gpu_gpu_sync::GLsync

    # Dynamic
    update_list::Vector{UInt32}
    types_dynamic::Vector{UInt8}
    draw_ranges_dynamic::Vector{Tuple{Int,Int}}

    coords_sizes_dynamic::Vector{Vector{Vec4F}}
    color_style_dynamic::Vector{Vector{UInt32}}

    distances_dynamic::Vector{Vector{Float32}} # to avoid memory allocations

    distance_buffer_in_dynamic::Vector{MappedBuffer{Float32}}
    color_style_buffer_in_dynamic::Vector{Buffer{UInt32}}
    position_width_buffer_in_dynamic::Vector{MappedBuffer{Vec4F}}

    position_distance_buffer_out_dynamic::Buffer{Vec4F}
    color_buffer_out_dynamic::Buffer{UVec2}
    begin_pos_rad_dynamic::Buffer{Vec4F}
    sdf_buffer_out_dynamic::Buffer{Vec4F}
    end_pos_rad_dynamic::Buffer{Vec4F}

    gpu_gpu_sync_dynamic::GLsync

    # GREEN Thread
    function LineRenderer()
        updated = _LINE_PROP_NONE
        emptyVAO = VertexArray()

        shader_predraw = ShaderProgram(["renderers/line/line.comp"],["offset"])
        shaders_opaque = Vector{ShaderProgram}()
        shaders_behind_opaque = Vector{ShaderProgram}()
        shaders_transparent = Vector{ShaderProgram}()
        types = ["SOLID","DASHED","DOTTED","WAVE","DASH_DOT","ARROW"]
        for type in types push!(shaders_opaque,ShaderProgram(["renderers/line/line.vert",("renderers/line/line.frag",[type])])) end
        for type in types push!(shaders_behind_opaque,ShaderProgram(["renderers/line/line.vert",("renderers/line/line_behind_opaque.frag",[type])])) end
        for type in types push!(shaders_transparent,ShaderProgram(["renderers/line/line.vert",("renderers/line/line.frag",[type,"TRANSPARENT_WEIGHTED_ONLY"])])) end
        
        # Static

        ranges = Vector{Tuple{Int,Int,Int}}()
        draw_ranges = fill((0,0),_LINE_TYPE_COUNT)

        coords_sizes = Vec4F[Vec4FNan]
        color_style = UInt32[0x0]

        distances = Vector{Float32}()

        distance_buffer_in = MappedBuffer{Float32}()
        color_style_buffer_in = Buffer{UInt32}()
        position_width_buffer_in = MappedBuffer{Vec4F}()

        position_distance_buffer_out = Buffer{Vec4F}()
        color_buffer_out = Buffer{UVec2}()
        begin_pos_rad = Buffer{Vec4F}()
        sdf_buffer_out = Buffer{Vec4F}()
        end_pos_rad = Buffer{Vec4F}()

        gpu_gpu_sync::GLsync = C_NULL

        # Dynamic

        update_list = Vector{UInt32}()
        types_dynamic = Vector{UInt8}()
        draw_ranges_dynamic = fill((0,0),_LINE_TYPE_COUNT)

        coords_sizes_dynamic = Vector{Vector{Vec4F}}()
        color_style_dynamic = Vector{Vector{UInt32}}()

        distances_dynamic = Vector{Vector{Float32}}()

        distance_buffer_in_dynamic = Vector{MappedBuffer{Float32}}()
        color_style_buffer_in_dynamic = Vector{Buffer{UInt32}}()
        position_width_buffer_in_dynamic = Vector{MappedBuffer{Vec4F}}()

        position_distance_buffer_out_dynamic = Buffer{Vec4F}()
        color_buffer_out_dynamic = Buffer{UVec2}()
        begin_pos_rad_dynamic = Buffer{Vec4F}()
        sdf_buffer_out_dynamic = Buffer{Vec4F}()
        end_pos_rad_dynamic = Buffer{Vec4F}()

        gpu_gpu_sync_dynamic = C_NULL

        return new(updated,emptyVAO,
            shader_predraw,shaders_opaque,shaders_behind_opaque,shaders_transparent,
            ranges,draw_ranges,
            coords_sizes,color_style,
            distances,
            distance_buffer_in,color_style_buffer_in,position_width_buffer_in,
            position_distance_buffer_out,color_buffer_out,begin_pos_rad,sdf_buffer_out,end_pos_rad,
            gpu_gpu_sync,
            update_list,types_dynamic,draw_ranges_dynamic,
            coords_sizes_dynamic,color_style_dynamic,
            distances_dynamic,
            distance_buffer_in_dynamic,color_style_buffer_in_dynamic,position_width_buffer_in_dynamic,
            position_distance_buffer_out_dynamic,color_buffer_out_dynamic,begin_pos_rad_dynamic,sdf_buffer_out_dynamic,end_pos_rad_dynamic,
            gpu_gpu_sync_dynamic)
    end
end

function _sort_lines!(self::LineRenderer)
    range_groups = [Vector{Int}() for _ in 1:_LINE_TYPE_COUNT]
    for index = 1:length(self.ranges)
        push!(range_groups[self.ranges[index][3]],index)
    end

    coords_sizes = Vec4F[Vec4FNan]
    sizehint!(coords_sizes, length(self.coords_sizes))
    color_style = UInt32[0x0]
    sizehint!(color_style, length(self.coords_sizes))

    draw_first = 0
    @inbounds for (index,group) in enumerate(range_groups)
        draw_count = 0
        @inbounds for range_ind in group
            (first, last, type) = self.ranges[range_ind]
            draw_count += last-first+2
            self.ranges[range_ind] = (length(coords_sizes)+1,length(coords_sizes)+last-first+1,type)
            
            append!(coords_sizes, view(self.coords_sizes,first:last))
            append!(color_style, view(self.color_style,first:last))
            
            push!(coords_sizes, Vec4FNan)
            push!(color_style, 0x0)
        end
        self.draw_ranges[index] = (draw_first, draw_count == 0 ? 0 : (draw_count - 2))
        draw_first += draw_count
    end

    self.coords_sizes = coords_sizes
    self.color_style = color_style
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
        _compute_strip_distances!(self.distances, self.coords_sizes, first, last, vp, wh)
    end
    @time_cpu_end Renderer Line Distances Static
    
    wait(self.distance_buffer_in)
    copyto!(self.distance_buffer_in, self.distances)
    
end

function _calc_distances_dynamic!(self::LineRenderer, vp::Mat4, wh::Vec2F)
    @time_cpu_begin Renderer Line Distances Dynamic
    Threads.@threads for index in 1:length(self.coords_sizes_dynamic)
        distances = self.distances_dynamic[index]
        coords_sizes = self.coords_sizes_dynamic[index]
        
        first_idx = 1
        last_idx = length(coords_sizes)
        
        _compute_strip_distances!(distances, coords_sizes, first_idx, last_idx, vp, wh)
    end
    @time_cpu_end Renderer Line Distances Dynamic

    wait(last(self.distance_buffer_in_dynamic))
    @inbounds for i in 1:length(self.distances_dynamic)
        copyto!(self.distance_buffer_in_dynamic[i], self.distances_dynamic[i])
    end
end

function reset!(self::LineRenderer)::Nothing
    destroy!(self.distance_buffer_in)
    destroy!(self.color_style_buffer_in)
    destroy!(self.position_width_buffer_in)

    destroy!(self.position_distance_buffer_out)
    destroy!(self.color_buffer_out)
    destroy!(self.begin_pos_rad)
    destroy!(self.sdf_buffer_out)
    destroy!(self.end_pos_rad)

    foreach(destroy!,self.distance_buffer_in_dynamic)
    foreach(destroy!,self.color_style_buffer_in_dynamic)
    foreach(destroy!,self.position_width_buffer_in_dynamic)

    destroy!(self.position_distance_buffer_out_dynamic)
    destroy!(self.color_buffer_out_dynamic)
    destroy!(self.begin_pos_rad_dynamic)
    destroy!(self.sdf_buffer_out_dynamic)
    destroy!(self.end_pos_rad_dynamic)

    self.ranges = Vector{Tuple{Int,Int,Int}}()
    self.draw_ranges = fill((0,0),_LINE_TYPE_COUNT)
    self.coords_sizes = Vec4F[Vec4FNan]
    self.color_style = UInt32[0x0]
    self.distances = Vector{Float32}()
    self.distance_buffer_in = MappedBuffer{Float32}()
    self.color_style_buffer_in = Buffer{UInt32}()
    self.position_width_buffer_in = MappedBuffer{Vec4F}()
    self.position_distance_buffer_out = Buffer{Vec4F}()
    self.color_buffer_out = Buffer{UVec2}()
    self.begin_pos_rad = Buffer{Vec4F}()
    self.sdf_buffer_out = Buffer{Vec4F}()
    self.end_pos_rad = Buffer{Vec4F}()

    self.update_list = Vector{UInt32}()
    self.types_dynamic = Vector{UInt8}()
    self.draw_ranges_dynamic = fill((0,0),_LINE_TYPE_COUNT)
    self.coords_sizes_dynamic = Vector{Vector{Vec4F}}()
    self.color_style_dynamic = Vector{Vector{UInt32}}()
    self.distances_dynamic = Vector{Vector{Float32}}()
    self.distance_buffer_in_dynamic = Vector{MappedBuffer{Float32}}()
    self.color_style_buffer_in_dynamic = Vector{Buffer{UInt32}}()
    self.position_width_buffer_in_dynamic = Vector{MappedBuffer{Vec4F}}()
    self.position_distance_buffer_out_dynamic = Buffer{Vec4F}()
    self.color_buffer_out_dynamic = Buffer{UVec2}()
    self.begin_pos_rad_dynamic = Buffer{Vec4F}()
    self.sdf_buffer_out_dynamic = Buffer{Vec4F}()
    self.end_pos_rad_dynamic = Buffer{Vec4F}()
    return nothing
end

function destroy!(self::LineRenderer)::Nothing
    destroy!(self.emptyVAO)
    destroy!(self.shader_predraw)
    foreach(destroy!,self.shaders_opaque)
    foreach(destroy!,self.shaders_behind_opaque)
    foreach(destroy!,self.shaders_transparent)

    destroy!(self.distance_buffer_in)
    destroy!(self.color_style_buffer_in)
    destroy!(self.position_width_buffer_in)

    destroy!(self.position_distance_buffer_out)
    destroy!(self.color_buffer_out)
    destroy!(self.begin_pos_rad)
    destroy!(self.sdf_buffer_out)
    destroy!(self.end_pos_rad)

    foreach(destroy!,self.distance_buffer_in_dynamic)
    foreach(destroy!,self.color_style_buffer_in_dynamic)
    foreach(destroy!,self.position_width_buffer_in_dynamic)

    destroy!(self.position_distance_buffer_out_dynamic)
    destroy!(self.color_buffer_out_dynamic)
    destroy!(self.begin_pos_rad_dynamic)
    destroy!(self.sdf_buffer_out_dynamic)
    destroy!(self.end_pos_rad_dynamic)

    return nothing
end

function pack_color_reversed(color::UInt32, reversed::Bool)::UInt32
    return (UInt32(reversed ? 0xff : 0x00) << 24) | (color & ~(UInt32(0xff) << 24))
end

function add!(self::LineRenderer,coords,colors,ids,width::Float32,type::UInt8)::UInt32
    (type, reversed) = get_type_reversed(type)
    first = length(self.coords_sizes) + 1
    append!(self.coords_sizes,(Vec4F(coord...,width) for coord in coords))
    last = length(self.coords_sizes)
    push!(self.coords_sizes, Vec4FNan)

    append!(self.color_style, (pack_color_reversed(color,reversed) for color in take(colors,length(coords))))
    push!(self.color_style, UInt32(0))

    push!(self.ranges,tuple(first,last,Int(type)))
    return UInt32(length(self.ranges))
end

function add_dynamic!(self::LineRenderer,coords,colors,ids,width::Float32,type::UInt8)::UInt32
    (type, reversed) = get_type_reversed(type)
    coords_sizes = Vector{Vec4F}()
    sizehint!(coords_sizes, 2 + length(coords))
    push!(coords_sizes, Vec4FNan)
    append!(coords_sizes, (Vec4F(coord...,width) for coord in coords))
    push!(coords_sizes, Vec4FNan)
    push!(self.coords_sizes_dynamic, coords_sizes)

    color_style = Vector{UInt32}()
    sizehint!(color_style, 2 + length(coords))
    push!(color_style, 0x0)
    append!(color_style, (pack_color_reversed(color,reversed) for color in take(colors,length(coords))))
    push!(color_style, 0x0)
    push!(self.color_style_dynamic, color_style)

    push!(self.types_dynamic,type)
    return UInt32(length(self.coords_sizes_dynamic))
end

function added_static!(self::LineRenderer)::Nothing
    _sort_lines!(self)
    upload!(self.position_width_buffer_in, self.coords_sizes, 0)
    upload!(self.color_style_buffer_in, self.color_style, 0)

    N = length(self.coords_sizes)
    self.distances = Vector{Float32}(undef, N)
    reserve!(self.distance_buffer_in,N,0)

    reserve!(self.position_distance_buffer_out,5*(N-3),0)
    reserve!(self.color_buffer_out,N-3,0)
    reserve!(self.begin_pos_rad,N-3,0)
    reserve!(self.sdf_buffer_out,5*(N-3),0)
    reserve!(self.end_pos_rad,N-3,0)
    self.updated = _LINE_PROP_NONE
    return nothing
end

function added_dynamic!(self::LineRenderer)::Nothing
    for i in (length(self.position_width_buffer_in_dynamic)+1):length(self.coords_sizes_dynamic)
        pw = MappedBuffer{Vec4F}()
        upload!(pw, self.coords_sizes_dynamic[i], 0)
        push!(self.position_width_buffer_in_dynamic, pw)
            
        ct = Buffer{UInt32}()
        upload!(ct, self.color_style_dynamic[i], 0)
        push!(self.color_style_buffer_in_dynamic, ct)
            
        N = length(self.coords_sizes_dynamic[i])
        push!(self.distances_dynamic,Vector{Float32}(undef, N))

        distance_buffer = MappedBuffer{Float32}()
        reserve!(distance_buffer,N,0)
        push!(self.distance_buffer_in_dynamic, distance_buffer)
    end
    N = sum(v -> length(v) <= 3 ? 0 : (length(v) - 3), self.coords_sizes_dynamic)
    reserve!(self.position_distance_buffer_out_dynamic,5*N,0)
    reserve!(self.color_buffer_out_dynamic,N,0)
    reserve!(self.begin_pos_rad_dynamic,N,0)
    reserve!(self.sdf_buffer_out_dynamic,5*N,0)
    reserve!(self.end_pos_rad_dynamic,5*N,0)
    return nothing
end

function added_all!(self::LineRenderer)::Nothing
    N = length(self.coords_sizes)
    if N != length(self.position_width_buffer_in) && N > 1
        added_static!(self)
    end

    if length(self.coords_sizes_dynamic) != length(self.position_width_buffer_in_dynamic)
        added_dynamic!(self)
    end
    return nothing
end

function update_coords!(self::LineRenderer,ref::UInt32,coords)::Nothing
    (first,last,_) = self.ranges[ref]
    first == last && return nothing

    coords_sizes_view = view(self.coords_sizes, first:last)
    size = coords_sizes_view[1][4]
    for (i,coord) in enumerate(coords)
        coords_sizes_view[i] = Vec4F(coord[1],coord[2],coord[3],size)
    end
    self.updated |= _LINE_PROP_COORD_SIZE
    return nothing
end

function update_size!(self::LineRenderer,ref::UInt32,size::Float32)::Nothing
    (first,last,_) = self.ranges[ref]
    first == last && return nothing

    coords_sizes_view = view(self.coords_sizes, first:last)
    map!(e -> Vec4F(e[1],e[2],e[3],size), coords_sizes_view)
    self.updated |= _LINE_PROP_COORD_SIZE
    return nothing
end

function update_colors!(self::LineRenderer,ref::UInt32,colors)
    (first,last,_) = self.ranges[ref]
    first == last && return nothing
    
    color_style_view = view(self.color_style, first:last)
    for (i,color) in enumerate(take(colors, last - first + 1))
        color_style_view[i] = color_style_view[i] & (UInt32(0xFF) << 24) | color & ~(UInt32(0xFF) << 24)
    end
    self.updated |= _LINE_PROP_COLOR_STYLE
    return nothing
end

function update_style!(self::LineRenderer,ref::UInt32,style::UInt8)
    (first,last,old_style) = self.ranges[ref]
    first == last && return nothing

    (new_style, new_reversed) = get_type_reversed(style)
    old_reversed = (self.color_style[first] & (UInt32(0xff) << 24)) != 0

    if new_style != old_style
        self.ranges[ref] = (first, last, new_style)
        self.updated |= _LINE_PROP_STYLE
    end

    if xor(new_reversed, old_reversed)
        color_style_view = view(self.color_style, first:UInt32(first + N - 1))
        reversed_value::UInt32 = UInt32(new_reversed ? 0xff : 0x00) << 24
        map!(e -> e & ~(UInt32(0xff) << 24) | reversed_value, color_style_view)
        self.updated |= _LINE_PROP_COLOR_STYLE
    end
    return nothing
end

function update_dynamic!(self::LineRenderer,ref::UInt32,coords,colors,ids,width::Float32,type::UInt8)
    (type, reversed) = get_type_reversed(type)
    coords_sizes = self.coords_sizes_dynamic[ref]
    empty!(coords_sizes)
    push!(coords_sizes, Vec4FNan)
    append!(coords_sizes, (Vec4F(coord...,width) for coord in coords))
    push!(coords_sizes, Vec4FNan)

    color_style = self.color_style_dynamic[ref]
    empty!(color_style)
    push!(color_style, 0x0)
    append!(color_style, (pack_color_reversed(color,reversed) for color in take(colors,length(coords))))
    push!(color_style, 0x0)

    self.types_dynamic[ref] = type
    push!(self.update_list, ref)
end

function update_colors_dynamic!(self::LineRenderer,ref::UInt32,colors)::Nothing
    color_style = self.color_style_dynamic[ref]
    length(color_style) <= 2 && return nothing
    for (i,color) in enumerate(take(colors, length(color_style)-2))
        color_style[i+1] = color_style[i+1] & (UInt32(0xFF) << 24) | color & ~(UInt32(0xFF) << 24)
    end
    push!(self.update_list,ref)
    return nothing
end

function update_style_dynamic!(self::LineRenderer,ref::UInt32,style::UInt8)::Nothing
    color_style = self.color_style_dynamic[ref]
    length(color_style) <= 2 && return nothing

    (new_style, new_reversed) = get_type_reversed(style)
    old_reversed = (color_style[2] & (UInt32(0xff) << 24)) != 0

    self.types_dynamic[ref] = new_style

    if xor(new_reversed, old_reversed)
        reversed_value::UInt32 = UInt32(new_reversed ? 0xff : 0x00) << 24
        map!(e -> e & ~(UInt32(0xff) << 24) | reversed_value, color_style)
    end
    push!(self.update_list,ref)
    return nothing
end

function update_size_dynamic!(self::LineRenderer,ref::UInt32,size::Float32)::Nothing
    coord_sizes = self.coords_sizes_dynamic[ref]
    length(coord_sizes) <= 2 && return nothing

    for i in 2:(length(coord_sizes)-1)
        c = coord_sizes[i]
        coord_sizes[i] = Vec4F(c[1],c[2],c[3],size)
    end

    push!(self.update_list,ref)
    return nothing
end

function sync_all!(self::LineRenderer)::Bool
    if (self.updated & _LINE_PROP_STYLE) == _LINE_PROP_STYLE
        _sort_lines!(self)
        self.updated |= _LINE_PROP_COORD_SIZE | _LINE_PROP_COLOR_STYLE
    end
    scene_change::Bool = false
    if (self.updated & _LINE_PROP_COORD_SIZE) == _LINE_PROP_COORD_SIZE || (self.updated & _LINE_PROP_COLOR_STYLE) == _LINE_PROP_COLOR_STYLE
        wait(self.distance_buffer_in)
        if (self.updated & _LINE_PROP_COORD_SIZE) == _LINE_PROP_COORD_SIZE
            copyto!(self.position_width_buffer_in, self.coords_sizes)
        end
        if (self.updated & _LINE_PROP_COLOR_STYLE) == _LINE_PROP_COLOR_STYLE
            upload!(self.color_style_buffer_in, self.color_style, 0)
        end
        scene_change = true
    end
    if length(self.update_list) != 0
        wait(last(self.distance_buffer_in_dynamic))

        for ref in self.update_list
            upload!(self.position_width_buffer_in_dynamic[ref], self.coords_sizes_dynamic[ref], 0)
            upload!(self.color_style_buffer_in_dynamic[ref], self.color_style_dynamic[ref], 0)
            
            N = length(self.coords_sizes_dynamic[ref])

            Base.resize!(self.distances_dynamic[ref],N)
            reserve!(self.distance_buffer_in_dynamic[ref],N,0)
        end
        empty!(self.update_list)

        N = sum(v -> length(v) <= 3 ? 0 : (length(v) - 3), self.coords_sizes_dynamic)
        if N > length(self.color_buffer_out_dynamic)
            reserve!(self.position_distance_buffer_out_dynamic,5*N,0)
            reserve!(self.color_buffer_out_dynamic,N,0)
            reserve!(self.begin_pos_rad_dynamic,N,0)
            reserve!(self.sdf_buffer_out_dynamic,5*N,0)
            reserve!(self.end_pos_rad_dynamic,5*N,0)
        end
        scene_change = true
    end
    self.updated = _LINE_PROP_NONE
    return scene_change
end

function pre_draw(self::LineRenderer,cam::Camera,shrd::SharedData)::Nothing
    (vp, v, p) = get_matrices(cam)

    # Static
    
    if length(self.coords_sizes) > 1
    _calc_distances!(self,vp,Vec2F(shrd._width,shrd._height))

    bind_ssbo(self.distance_buffer_in,0)
    bind_ssbo(self.color_style_buffer_in,1)
    bind_ssbo(self.position_width_buffer_in,2)
    bind_ssbo(self.position_distance_buffer_out,3)
    bind_ssbo(self.color_buffer_out,4)
    bind_ssbo(self.begin_pos_rad,5)
    bind_ssbo(self.sdf_buffer_out,6)
    bind_ssbo(self.end_pos_rad,7)

    (cam_light, side_light) = get_lights(cam)
    activate(self.shader_predraw)
    uniform(self.shader_predraw,"offset",UInt32(0))
    @time_gpu_begin Renderer Line Pre_Draw Static
    glDispatchCompute(cld(length(self.coords_sizes),32),1,1);
    @time_gpu_end Renderer Line Pre_Draw Static
    self.gpu_gpu_sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
    lock(self.distance_buffer_in)
    end
    # Dynamic
    
    if length(self.coords_sizes_dynamic) > 0
    _calc_distances_dynamic!(self,vp,Vec2F(shrd._width,shrd._height))

    bind_ssbo(self.position_distance_buffer_out_dynamic,3)
    bind_ssbo(self.color_buffer_out_dynamic,4)
    bind_ssbo(self.begin_pos_rad_dynamic,5)
    bind_ssbo(self.sdf_buffer_out_dynamic,6)
    bind_ssbo(self.end_pos_rad_dynamic,7)

    (cam_light, side_light) = get_lights(cam)
    activate(self.shader_predraw)

    prev_offset::UInt32 = 0
    offset::UInt32 = 0
    @time_gpu_begin Renderer Line Pre_Draw Dynamic
    for i in 1:_LINE_TYPE_COUNT
        for j in 1:length(self.coords_sizes_dynamic)
            if self.types_dynamic[j] != i || length(self.coords_sizes_dynamic[j]) <= 3 continue end
            bind_ssbo(self.distance_buffer_in_dynamic[j],0)
            bind_ssbo(self.color_style_buffer_in_dynamic[j],1)
            bind_ssbo(self.position_width_buffer_in_dynamic[j],2)
            uniform(self.shader_predraw,"offset",offset)
            glDispatchCompute(cld(length(self.coords_sizes_dynamic[j]),32),1,1);
            offset += UInt32(length(self.coords_sizes_dynamic[j]) - 3)
        end
        self.draw_ranges_dynamic[i] = (prev_offset, offset - prev_offset)
        prev_offset = offset
    end
    @time_gpu_end Renderer Line Pre_Draw Dynamic

    self.gpu_gpu_sync_dynamic = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
    lock(last(self.distance_buffer_in_dynamic))
    end

    return nothing
end

function opaque(self::LineRenderer,cam::Camera,shrd::SharedData)::Nothing
    if (any(x -> x[2] != 0, self.draw_ranges))
    glWaitSync(self.gpu_gpu_sync, 0, 0xFFFFFFFFFFFFFFFF)
    glDeleteSync(self.gpu_gpu_sync);

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out,0)
    bind_ssbo(self.color_buffer_out,1)
    bind_ssbo(self.begin_pos_rad,2)
    bind_ssbo(self.sdf_buffer_out,3)
    bind_ssbo(self.end_pos_rad,4)
    @time_gpu_begin Renderer Line Opaque Static
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges[type]
        if count == 0 continue end
        activate(self.shaders_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Opaque Static
    end

    if (any(x -> x[2] != 0, self.draw_ranges_dynamic))
    glWaitSync(self.gpu_gpu_sync_dynamic, 0, 0xFFFFFFFFFFFFFFFF)
    glDeleteSync(self.gpu_gpu_sync_dynamic);

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out_dynamic,0)
    bind_ssbo(self.color_buffer_out_dynamic,1)
    bind_ssbo(self.begin_pos_rad_dynamic,2)
    bind_ssbo(self.sdf_buffer_out_dynamic,3)
    bind_ssbo(self.end_pos_rad_dynamic,4)
    @time_gpu_begin Renderer Line Opaque Dynamic
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges_dynamic[type]
        if count == 0 continue end
        activate(self.shaders_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Opaque Dynamic
    end
    return nothing
end

function behind_opaque(self::LineRenderer,cam::Camera,shrd::SharedData)::Nothing
    (_, _, p) = get_matrices(cam)
    glEnable(GL_BLEND)
    glBlendColor(0.0, 0.0, 0.0, 0.4)
    glBlendFunc(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA)
    glColorMaski(1, GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)

    if (any(x -> x[2] != 0, self.draw_ranges))
    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out,0)
    bind_ssbo(self.color_buffer_out,1)
    bind_ssbo(self.begin_pos_rad,2)
    bind_ssbo(self.sdf_buffer_out,3)
    bind_ssbo(self.end_pos_rad,4)
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges[type]
        if count == 0 continue end
        activate(self.shaders_behind_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    end

    if (any(x -> x[2] != 0, self.draw_ranges_dynamic))
    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out_dynamic,0)
    bind_ssbo(self.color_buffer_out_dynamic,1)
    bind_ssbo(self.begin_pos_rad_dynamic,2)
    bind_ssbo(self.sdf_buffer_out_dynamic,3)
    bind_ssbo(self.end_pos_rad_dynamic,4)
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges_dynamic[type]
        if count == 0 continue end
        activate(self.shaders_behind_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    end

    glColorMaski(1, GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glDisable(GL_BLEND)
    return nothing
end

function transparent(self::LineRenderer,cam::Camera,shrd::SharedData)::Nothing
    if (any(x -> x[2] != 0, self.draw_ranges))

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out,0)
    bind_ssbo(self.color_buffer_out,1)
    bind_ssbo(self.begin_pos_rad,2)
    bind_ssbo(self.sdf_buffer_out,3)
    bind_ssbo(self.end_pos_rad,4)
    @time_gpu_begin Renderer Line Transparent Static
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges[type]
        if count == 0 continue end
        activate(self.shaders_transparent[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Transparent Static
    end

    if (any(x -> x[2] != 0, self.draw_ranges_dynamic))

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out_dynamic,0)
    bind_ssbo(self.color_buffer_out_dynamic,1)
    bind_ssbo(self.begin_pos_rad_dynamic,2)
    bind_ssbo(self.sdf_buffer_out_dynamic,3)
    bind_ssbo(self.end_pos_rad_dynamic,4)
    @time_gpu_begin Renderer Line Transparent Dynamic
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges_dynamic[type]
        if count == 0 continue end
        activate(self.shaders_transparent[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Transparent Dynamic
    end
    return nothing
end