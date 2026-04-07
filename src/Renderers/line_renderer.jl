# GREEN Thread

const SOLID::UInt8    = 1
const DASHED::UInt8   = 2
const DOTTED::UInt8   = 3
const WAVE::UInt8     = 4
const DASH_DOT::UInt8 = 5
const ARROW::UInt8    = 6
const _LINE_TYPE_COUNT::UInt8   = 6

const _LINE_UPDATED_COORD_WIDTH::UInt32 = 1
const _LINE_UPDATED_COLOR_TYPE::UInt32 = 2
const _LINE_UPDATED_COORD_WIDTH_DYNAMIC::UInt32 = 4
const _LINE_UPDATED_COLOR_TYPE_DYNAMIC::UInt32 = 8

export SOLID, DASHED, DOTTED, 
        WAVE, DASH_DOT, ARROW

mutable struct LineRenderer
    updated::UInt32
    emptyVAO::VertexArray

    shader_predraw::ShaderProgram
    shaders_opaque::Vector{ShaderProgram}
    shaders_transparent::Vector{ShaderProgram}

    # Static
    ranges::Vector{Tuple{Int,Int,Int}}
    draw_ranges::Vector{Tuple{Int,Int}}

    coords_widths::Vector{Vec4F}
    color_type::Vector{UInt32}

    distances::Vector{Float32} # to avoid memory allocations

    distance_buffer_in::MappedBuffer{Float32}
    color_type_buffer_in::Buffer{UInt32}
    position_width_buffer_in::MappedBuffer{Vec4F}

    position_distance_buffer_out::Buffer{Vec4F}
    color_buffer_out::Buffer{UVec2}
    light_buffer_out::Buffer{Vec4F}
    sdf_buffer_out::Buffer{Vec4F}

    gpu_gpu_sync::GLsync

    # Dynamic
    update_list::Vector{UInt32}
    types_dynamic::Vector{UInt8}
    draw_ranges_dynamic::Vector{Tuple{Int,Int}}

    coords_widths_dynamic::Vector{Vector{Vec4F}}
    color_type_dynamic::Vector{Vector{UInt32}}

    distances_dynamic::Vector{Vector{Float32}} # to avoid memory allocations

    distance_buffer_in_dynamic::Vector{MappedBuffer{Float32}}
    color_type_buffer_in_dynamic::Vector{Buffer{UInt32}}
    position_width_buffer_in_dynamic::Vector{MappedBuffer{Vec4F}}

    position_distance_buffer_out_dynamic::Buffer{Vec4F}
    color_buffer_out_dynamic::Buffer{UVec2}
    light_buffer_out_dynamic::Buffer{Vec4F}
    sdf_buffer_out_dynamic::Buffer{Vec4F}

    gpu_gpu_sync_dynamic::GLsync

    # GREEN Thread
    function LineRenderer()
        updated::UInt32 = 0
        emptyVAO = VertexArray()

        shader_predraw = ShaderProgram(["renderers/line/line.comp"],["VP","WH","Eye","lightDirCam","lightDirSide","offset"])
        shaders_opaque = Vector{ShaderProgram}()
        shaders_transparent = Vector{ShaderProgram}()
        types = ["SOLID","DASHED","DOTTED","WAVE","DASH_DOT","ARROW"]
        for type in types push!(shaders_opaque,ShaderProgram(["renderers/line/line.vert",("renderers/line/line.frag",[type])])) end
        for type in types push!(shaders_transparent,ShaderProgram(["renderers/line/line.vert",("renderers/line/line.frag",[type,"TRANSPARENT"])],["width"])) end
        
        # Static

        ranges = Vector{Tuple{Int,Int,Int}}()
        draw_ranges = fill((0,0),_LINE_TYPE_COUNT)

        coords_widths = Vec4F[Vec4FNan]
        color_type = UInt32[0x0]

        distances = Vector{Float32}()

        distance_buffer_in = MappedBuffer{Float32}()
        color_type_buffer_in = Buffer{UInt32}()
        position_width_buffer_in = MappedBuffer{Vec4F}()

        position_distance_buffer_out = Buffer{Vec4F}()
        color_buffer_out = Buffer{UVec2}()
        light_buffer_out = Buffer{Vec4F}()
        sdf_buffer_out = Buffer{Vec4F}()

        gpu_gpu_sync::GLsync = C_NULL

        # Dynamic

        update_list = Vector{UInt32}()
        types_dynamic = Vector{UInt8}()
        draw_ranges_dynamic = fill((0,0),_LINE_TYPE_COUNT)

        coords_widths_dynamic = Vector{Vector{Vec4F}}()
        color_type_dynamic = Vector{Vector{UInt32}}()

        distances_dynamic = Vector{Vector{Float32}}()

        distance_buffer_in_dynamic = Vector{MappedBuffer{Float32}}()
        color_type_buffer_in_dynamic = Vector{Buffer{UInt32}}()
        position_width_buffer_in_dynamic = Vector{MappedBuffer{Vec4F}}()

        position_distance_buffer_out_dynamic = Buffer{Vec4F}()
        color_buffer_out_dynamic = Buffer{UVec2}()
        light_buffer_out_dynamic = Buffer{Vec4F}()
        sdf_buffer_out_dynamic = Buffer{Vec4F}()

        gpu_gpu_sync_dynamic = C_NULL

        return new(updated,emptyVAO,
            shader_predraw,shaders_opaque,shaders_transparent,
            ranges,draw_ranges,
            coords_widths,color_type,
            distances,
            distance_buffer_in,color_type_buffer_in,position_width_buffer_in,
            position_distance_buffer_out,color_buffer_out,light_buffer_out,sdf_buffer_out,
            gpu_gpu_sync,
            update_list,types_dynamic,draw_ranges_dynamic,
            coords_widths_dynamic,color_type_dynamic,
            distances_dynamic,
            distance_buffer_in_dynamic,color_type_buffer_in_dynamic,position_width_buffer_in_dynamic,
            position_distance_buffer_out_dynamic,color_buffer_out_dynamic,light_buffer_out_dynamic,sdf_buffer_out_dynamic,
            gpu_gpu_sync_dynamic)
    end
end

function _sort_lines!(self::LineRenderer)
    range_groups = [Vector{Int}() for _ in 1:_LINE_TYPE_COUNT]
    for index = 1:length(self.ranges)
        push!(range_groups[self.ranges[index][3]],index)
    end

    coords_widths = Vec4F[Vec4FNan]
    sizehint!(coords_widths, length(self.coords_widths))
    color_type = UInt32[0x0]
    sizehint!(color_type, length(self.coords_widths))

    draw_first = 0
    @inbounds for (index,group) in enumerate(range_groups)
        draw_count = 0
        @inbounds for range_ind in group
            (first, last, type) = self.ranges[range_ind]
            draw_count += last-first+2
            self.ranges[range_ind] = (length(coords_widths)+1,length(coords_widths)+last-first+1,type)
            
            append!(coords_widths, view(self.coords_widths,first:last))
            append!(color_type, view(self.color_type,first:last))
            
            push!(coords_widths, Vec4FNan)
            push!(color_type, 0x0)
        end
        self.draw_ranges[index] = (draw_first, draw_count == 0 ? 0 : (draw_count - 2))
        draw_first += draw_count
    end

    self.coords_widths = coords_widths
    self.color_type = color_type
end

@inline function _compute_strip_distances!(distances::Vector{Float32}, coords_widths::Vector{Vec4F}, first_idx::Int, last_idx::Int, vp::Mat4, wh::Vec2F)
    distance_sum::Float32 = 0.0f0
    @inbounds for i in first_idx:(last_idx-1)
        cw1::Vec4F = coords_widths[i]
        cw2::Vec4F = coords_widths[i+1]
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
        _compute_strip_distances!(self.distances, self.coords_widths, first, last, vp, wh)
    end
    @time_cpu_end Renderer Line Distances Static
    
    wait(self.distance_buffer_in)
    copyto!(self.distance_buffer_in, self.distances)
    
end

function _calc_distances_dynamic!(self::LineRenderer, vp::Mat4, wh::Vec2F)
    @time_cpu_begin Renderer Line Distances Dynamic
    Threads.@threads for index in 1:length(self.coords_widths_dynamic)
        distances = self.distances_dynamic[index]
        coords_widths = self.coords_widths_dynamic[index]
        
        first_idx = 1
        last_idx = length(coords_widths)
        
        _compute_strip_distances!(distances, coords_widths, first_idx, last_idx, vp, wh)
    end
    @time_cpu_end Renderer Line Distances Dynamic

    wait(last(self.distance_buffer_in_dynamic))
    @inbounds for i in 1:length(self.distances_dynamic)
        copyto!(self.distance_buffer_in_dynamic[i], self.distances_dynamic[i])
    end
end

function destroy!(self::LineRenderer)::Nothing
    destroy!(self.emptyVAO)
    destroy!(self.shader_predraw)
    foreach(destroy!,self.shaders_opaque)
    foreach(destroy!,self.shaders_transparent)

    destroy!(self.distance_buffer_in)
    destroy!(self.color_type_buffer_in)
    destroy!(self.position_width_buffer_in)

    destroy!(self.position_distance_buffer_out)
    destroy!(self.color_buffer_out)
    destroy!(self.light_buffer_out)
    destroy!(self.sdf_buffer_out)

    foreach(destroy!,self.distance_buffer_in_dynamic)
    foreach(destroy!,self.color_type_buffer_in_dynamic)
    foreach(destroy!,self.position_width_buffer_in_dynamic)

    destroy!(self.position_distance_buffer_out_dynamic)
    destroy!(self.color_buffer_out_dynamic)
    destroy!(self.light_buffer_out_dynamic)
    destroy!(self.sdf_buffer_out_dynamic)

    return nothing
end

function pack_color_reversed(color::Vec3F, reversed::Bool)::UInt32
    return (UInt32(reversed ? 255 : 0) << 24) | packUnorm4x8(color)
end

function add!(self::LineRenderer,coords,colors,ids,width::Float32,type::UInt8,reversed::Bool)::UInt32
    first = length(self.coords_widths) + 1
    append!(self.coords_widths,(Vec4F(coord...,width) for coord in coords))
    last = length(self.coords_widths)
    push!(self.coords_widths, Vec4FNan)

    append!(self.color_type, (pack_color_reversed(color,reversed) for color in take(colors,length(coords))))
    push!(self.color_type, UInt32(0))

    push!(self.ranges,tuple(first,last,Int(type)))
    return UInt32(first)
end

function add_dynamic!(self::LineRenderer,coords,colors,ids,width::Float32,type::UInt8,reversed::Bool)::UInt32
    coords_widths = Vector{Vec4F}()
    sizehint!(coords_widths, 2 + length(coords))
    push!(coords_widths, Vec4FNan)
    append!(coords_widths, (Vec4F(coord...,width) for coord in coords))
    push!(coords_widths, Vec4FNan)
    push!(self.coords_widths_dynamic, coords_widths)

    color_type = Vector{UInt32}()
    sizehint!(color_type, 2 + length(coords))
    push!(color_type, 0x0)
    append!(color_type, (pack_color_reversed(color,reversed) for color in take(colors,length(coords))))
    push!(color_type, 0x0)
    push!(self.color_type_dynamic, color_type)

    push!(self.types_dynamic,type)
    return UInt32(length(self.coords_widths_dynamic))
end

function added_all!(self::LineRenderer)::Nothing
    N = length(self.coords_widths) 
    if N != length(self.position_width_buffer_in) && N > 1
        _sort_lines!(self)
        upload!(self.position_width_buffer_in, self.coords_widths, 0)
        upload!(self.color_type_buffer_in, self.color_type, 0)
        
        self.distances = Vector{Float32}(undef, N)
        reserve!(self.distance_buffer_in,N,0)

        reserve!(self.position_distance_buffer_out,5*(N-3),0)
        reserve!(self.color_buffer_out,N-3,0)
        reserve!(self.light_buffer_out,N-3,0)
        reserve!(self.sdf_buffer_out,5*(N-3),0)
        self.updated = 0
    end
    if length(self.coords_widths_dynamic) != length(self.position_width_buffer_in_dynamic)
        for i in (length(self.position_width_buffer_in_dynamic)+1):length(self.coords_widths_dynamic)
            pw = MappedBuffer{Vec4F}()
            upload!(pw, self.coords_widths_dynamic[i], 0)
            push!(self.position_width_buffer_in_dynamic, pw)
            
            ct = Buffer{UInt32}()
            upload!(ct, self.color_type_dynamic[i], 0)
            push!(self.color_type_buffer_in_dynamic, ct)
            
            N = length(self.coords_widths_dynamic[i])
            push!(self.distances_dynamic,Vector{Float32}(undef, N))

            distance_buffer = MappedBuffer{Float32}()
            reserve!(distance_buffer,N,0)
            push!(self.distance_buffer_in_dynamic, distance_buffer)
        end
        N = sum(v -> length(v) - 3, self.coords_widths_dynamic)
        reserve!(self.position_distance_buffer_out_dynamic,5*N,0)
        reserve!(self.color_buffer_out_dynamic,N,0)
        reserve!(self.light_buffer_out_dynamic,N,0)
        reserve!(self.sdf_buffer_out_dynamic,5*N,0)
    end
    return nothing
end

function update_coords!(self::LineRenderer,ref::UInt32,coords,width::Float32)
    coords_widths_view = view(self.coords_widths, ref:UInt32(ref + length(coords) - 1))
    copyto!(coords_widths_view,(Vec4F(coord...,width) for coord in coords))
    self.updated |= _LINE_UPDATED_COORD_WIDTH
end

function update_dynamic!(self::LineRenderer,ref::UInt32,coords,colors,ids,width::Float32,type::UInt8,reversed::Bool)
    coords_widths = self.coords_widths_dynamic[ref]
    empty!(coords_widths)
    push!(coords_widths, Vec4FNan)
    append!(coords_widths, (Vec4F(coord...,width) for coord in coords))
    push!(coords_widths, Vec4FNan)

    color_type = self.color_type_dynamic[ref]
    empty!(color_type)
    push!(color_type, 0x0)
    append!(color_type, (pack_color_reversed(color,reversed) for color in take(colors,length(coords))))
    push!(color_type, 0x0)

    self.types_dynamic[ref] = type
    self.updated |= _LINE_UPDATED_COLOR_TYPE_DYNAMIC
    push!(self.update_list, ref)
end

function sync_all!(self::LineRenderer)::Nothing
    if (self.updated & _LINE_UPDATED_COORD_WIDTH) != 0 || (self.updated & _LINE_UPDATED_COLOR_TYPE) != 0
        wait(self.distance_buffer_in)
        if (self.updated & _LINE_UPDATED_COORD_WIDTH) != 0
            copyto!(self.position_width_buffer_in, self.coords_widths)
        end
    end
    if length(self.update_list) != 0
        wait(last(self.distance_buffer_in_dynamic))

        for ref in self.update_list
            upload!(self.position_width_buffer_in_dynamic[ref], self.coords_widths_dynamic[ref], 0)
            upload!(self.color_type_buffer_in_dynamic[ref], self.color_type_dynamic[ref], 0)
            
            N = length(self.coords_widths_dynamic[ref])

            Base.resize!(self.distances_dynamic[ref],N)
            reserve!(self.distance_buffer_in_dynamic[ref],N,0)
        end
        empty!(self.update_list)

        N = sum(v -> length(v) - 3, self.coords_widths_dynamic)
        if N > length(self.color_buffer_out_dynamic)
            reserve!(self.position_distance_buffer_out_dynamic,5*N,0)
            reserve!(self.color_buffer_out_dynamic,N,0)
            reserve!(self.light_buffer_out_dynamic,N,0)
            reserve!(self.sdf_buffer_out_dynamic,5*N,0)
        end
    end
    self.updated = 0
    return nothing
end

function pre_draw(self::LineRenderer,cam::Camera,shrd::SharedData)::Nothing
    (vp, _, _) = get_matrices(cam)

    # Static
    
    if length(self.coords_widths) > 1
    _calc_distances!(self,vp,Vec2F(shrd._width,shrd._height))

    bind_ssbo(self.distance_buffer_in,0)
    bind_ssbo(self.color_type_buffer_in,1)
    bind_ssbo(self.position_width_buffer_in,2)
    bind_ssbo(self.position_distance_buffer_out,3)
    bind_ssbo(self.color_buffer_out,4)
    bind_ssbo(self.light_buffer_out,5)
    bind_ssbo(self.sdf_buffer_out,6)

    (cam_light, side_light) = get_lights(cam)
    activate(self.shader_predraw)
    uniform(self.shader_predraw,"VP",vp)
    uniform(self.shader_predraw,"WH",Vec2F(shrd._width, shrd._height))
    uniform(self.shader_predraw,"Eye",cam._eye)
    uniform(self.shader_predraw,"lightDirCam", cam_light)
    uniform(self.shader_predraw,"lightDirSide",side_light)
    uniform(self.shader_predraw,"offset",UInt32(0))
    @time_gpu_begin Renderer Line Pre_Draw Static
    glDispatchCompute(cld(length(self.coords_widths),32),1,1);
    @time_gpu_end Renderer Line Pre_Draw Static
    self.gpu_gpu_sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
    lock(self.distance_buffer_in)
    end
    # Dynamic
    
    if length(self.coords_widths_dynamic) > 0
    _calc_distances_dynamic!(self,vp,Vec2F(shrd._width,shrd._height))

    bind_ssbo(self.position_distance_buffer_out_dynamic,3)
    bind_ssbo(self.color_buffer_out_dynamic,4)
    bind_ssbo(self.light_buffer_out_dynamic,5)
    bind_ssbo(self.sdf_buffer_out_dynamic,6)

    (cam_light, side_light) = get_lights(cam)
    activate(self.shader_predraw)
    uniform(self.shader_predraw,"VP",vp)
    uniform(self.shader_predraw,"WH",Vec2F(shrd._width, shrd._height))
    uniform(self.shader_predraw,"Eye",cam._eye)
    uniform(self.shader_predraw,"lightDirCam", cam_light)
    uniform(self.shader_predraw,"lightDirSide",side_light)

    prev_offset::UInt32 = 0
    offset::UInt32 = 0
    @time_gpu_begin Renderer Line Pre_Draw Dynamic
    for i in 1:_LINE_TYPE_COUNT
        for j in 1:length(self.coords_widths_dynamic)
            if self.types_dynamic[j] != i continue end
            bind_ssbo(self.distance_buffer_in_dynamic[j],0)
            bind_ssbo(self.color_type_buffer_in_dynamic[j],1)
            bind_ssbo(self.position_width_buffer_in_dynamic[j],2)
            uniform(self.shader_predraw,"offset",offset)
            glDispatchCompute(cld(length(self.coords_widths_dynamic[j]),32),1,1);
            offset += UInt32(length(self.coords_widths_dynamic[j]) - 3)
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
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    if (any(x -> x[2] != 0, self.draw_ranges))
    glWaitSync(self.gpu_gpu_sync, 0, 0xFFFFFFFFFFFFFFFF)
    glDeleteSync(self.gpu_gpu_sync);

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out,1)
    bind_ssbo(self.color_buffer_out,2)
    bind_ssbo(self.light_buffer_out,3)
    bind_ssbo(self.sdf_buffer_out,4)
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
    bind_ssbo(self.position_distance_buffer_out_dynamic,1)
    bind_ssbo(self.color_buffer_out_dynamic,2)
    bind_ssbo(self.light_buffer_out_dynamic,3)
    bind_ssbo(self.sdf_buffer_out_dynamic,4)
    @time_gpu_begin Renderer Line Opaque Dynamic
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges_dynamic[type]
        if count == 0 continue end
        activate(self.shaders_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Opaque Dynamic
    end
    glDisable(GL_BLEND)
    return nothing
end

function transparent(self::LineRenderer,cam::Camera,shrd::SharedData)::Nothing
    if (any(x -> x[2] != 0, self.draw_ranges))

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out,1)
    bind_ssbo(self.color_buffer_out,2)
    bind_ssbo(self.light_buffer_out,3)
    bind_ssbo(self.sdf_buffer_out,4)
    @time_gpu_begin Renderer Line Transparent Static
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges[type]
        if count == 0 continue end
        activate(self.shaders_transparent[type])
        uniform(self.shaders_transparent[type],"width",UInt32(shrd._width))
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Transparent Static
    end

    if (any(x -> x[2] != 0, self.draw_ranges_dynamic))

    activate(self.emptyVAO)
    bind_ssbo(self.position_distance_buffer_out_dynamic,1)
    bind_ssbo(self.color_buffer_out_dynamic,2)
    bind_ssbo(self.light_buffer_out_dynamic,3)
    bind_ssbo(self.sdf_buffer_out_dynamic,4)
    @time_gpu_begin Renderer Line Transparent Dynamic
    for type in 1:_LINE_TYPE_COUNT
        (first,count) = self.draw_ranges_dynamic[type]
        if count == 0 continue end
        activate(self.shaders_transparent[type])
        uniform(self.shaders_transparent[type],"width",UInt32(shrd._width))
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, count, first)
    end
    @time_gpu_end Renderer Line Transparent Dynamic
    end
    return nothing
end