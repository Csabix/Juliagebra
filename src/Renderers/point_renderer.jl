# GREEN Thread

const _POINT_UPDATED_MOVABLE_COORD::UInt32 = 1
const _POINT_UPDATED_MOVABLE_COLOR::UInt32 = 2
const _POINT_UPDATED_DEPENDENT_COORD::UInt32 = 4
const _POINT_UPDATED_DEPENDENT_COLOR::UInt32 = 8

function _point_renderer_buffer_array()
    attributes = [nothing,
    [VertexAttrib(false,4,GL_UNSIGNED_BYTE,GL_TRUE,0)],
    [VertexAttrib(true,1,GL_UNSIGNED_BYTE,GL_FALSE,0)],
    [VertexAttrib(true,1,GL_UNSIGNED_INT,GL_FALSE,0)]]
    return BufferArray{Tuple{Vec3F,UInt32,UInt8,UInt32}}(attributes,MappedBuffer,MappedBuffer,MappedBuffer,Buffer)
end

mutable struct GlobalPointRenderer
    updated::UInt32

    movable_shader::ShaderProgram
    dependent_shader::ShaderProgram
    # Static
    movable_buffer::BufferArray
    dependent_buffer::BufferArray
    
    movable_coords::Vector{Vec3F}
    movable_colors::Vector{UInt32}
    movable_sizes::Vector{UInt8}
    movable_ids::Vector{UInt32}
    last_movable_size::UInt32

    dependent_coords::Vector{Vec3F}
    dependent_colors::Vector{UInt32}
    dependent_sizes::Vector{UInt8}
    dependent_ids::Vector{UInt32}
    last_dependent_size::UInt32
    # Dynamic
    dependent_buffer_dynamic::Vector{BufferArray}

    dependent_coords_dynamic::Vector{Vector{Vec3F}}
    dependent_colors_dynamic::Vector{Vector{UInt32}}
    dependent_sizes_dynamic::Vector{Vector{UInt8}}
    dependent_ids_dynamic::Vector{Vector{UInt32}}
    
    function GlobalPointRenderer()
        updated::UInt32 = 0

        movable_uniforms = String["VP","selected_id","picked_id","light_dir_side_view"]
        movable_shader::ShaderProgram = ShaderProgram(["renderers/point/point.vert","renderers/point/point.frag"], movable_uniforms)

        dependent_uniforms = String["VP","light_dir_side_view"]
        dependent_shader::ShaderProgram = ShaderProgram([("renderers/point/point.vert",["STATIC"]),("renderers/point/point.frag",["STATIC"])], dependent_uniforms)
        
        movable_buffer::BufferArray = _point_renderer_buffer_array()
        dependent_buffer::BufferArray = _point_renderer_buffer_array()
        
        movable_coords::Vector{Vec3F} = Vector{Vec3F}()
        movable_colors::Vector{UInt32} = Vector{UInt32}()
        movable_sizes::Vector{UInt8} = Vector{UInt8}()
        movable_ids::Vector{UInt32} = Vector{UInt32}()
        last_movable_size::UInt32 = 0
        
        dependent_coords::Vector{Vec3F} = Vector{Vec3F}()
        dependent_colors::Vector{UInt32} = Vector{UInt32}()
        dependent_sizes::Vector{UInt8} = Vector{UInt8}()
        dependent_ids::Vector{UInt32} = Vector{UInt32}()
        last_dependent_size::UInt32 = 0
        
        dependent_buffer_dynamic::Vector{BufferArray} = Vector{BufferArray}()
        
        dependent_coords_dynamic::Vector{Vector{Vec3F}} = Vector{Vector{Vec3F}}()
        dependent_colors_dynamic::Vector{Vector{UInt32}} = Vector{Vector{UInt32}}()
        dependent_sizes_dynamic::Vector{Vector{UInt8}} = Vector{Vector{UInt8}}()
        dependent_ids_dynamic::Vector{Vector{UInt32}} = Vector{Vector{UInt32}}()
        
        return new(
            updated,
            movable_shader,dependent_shader,
            movable_buffer,dependent_buffer,
            movable_coords,movable_colors,movable_ids,movable_sizes,last_movable_size,
            dependent_coords,dependent_colors,dependent_ids,dependent_sizes,last_dependent_size,
            dependent_buffer_dynamic,
            dependent_coords_dynamic,dependent_colors_dynamic,dependent_sizes_dynamic,dependent_ids_dynamic)
    end
end
_point_renderer::Union{GlobalPointRenderer,Nothing} = nothing

function init!(::Val{:Point})::Nothing
    global _point_renderer
    if !isnothing(_point_renderer) destroy_point!() end
    _point_renderer = GlobalPointRenderer()
    return nothing
end

function destroy!(::Val{:Point})::Nothing
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer

    destroy!(renderer.movable_shader)
    destroy!(renderer.dependent_shader)
    destroy!(renderer.movable_buffer)
    destroy!(renderer.dependent_buffer)

    _point_renderer = nothing
    return nothing
end

function added!(movable::Bool,coord::Vec3F,color::UInt32,size::UInt8,id::UInt32)::UInt32
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    curr_length = UInt32(0)
    if movable
        push!(renderer.movable_coords,coord)
        push!(renderer.movable_colors,color)
        push!(renderer.movable_sizes,size)
        push!(renderer.movable_ids,id)
        curr_length = UInt32(length(renderer.movable_coords))
    else
        push!(renderer.dependent_coords,coord)
        push!(renderer.dependent_colors,color)
        push!(renderer.dependent_sizes,size)
        push!(renderer.dependent_ids,id)
        curr_length = UInt32(length(renderer.dependent_coords))
    end
    return curr_length
end

function added!(movable::Bool,coords::Vector{Vec3F},colors::Vector{UInt32},sizes::Vector{UInt8},ids::Vector{UInt32})::UInt32
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    last_length = UInt32(0)
    if movable
        last_length = UInt32(length(renderer.movable_coords))
        append!(renderer.movable_coords,coords)
        append!(renderer.movable_colors,colors)
        append!(renderer.movable_sizes,sizes)
        append!(renderer.movable_ids,ids)
    else
        last_length = UInt32(length(renderer.dependent_coords))
        append!(renderer.dependent_coords,coords)
        append!(renderer.dependent_colors,colors)
        append!(renderer.dependent_sizes,sizes)
        append!(renderer.dependent_ids,ids)
    end
    return last_length + 1
end

function added_dynamic!(coords::Vector{Vec3F},colors::Vector{UInt32},sizes::Vector{UInt8},ids::Vector{UInt32})::UInt32
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    last_length = UInt32(length(renderer.dependent_buffer_dynamic))
    
    buffer_arr = _point_renderer_buffer_array()
    push!(renderer.dependent_buffer_dynamic,buffer_arr)
    upload!(buffer_arr,1,coords,0)
    upload!(buffer_arr,2,colors,0)
    upload!(buffer_arr,3,sizes,0)
    upload!(buffer_arr,4,ids,0)
    return last_length + 1
end

function added_all!(::Val{:Point})::Nothing
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    if length(renderer.movable_coords) != renderer.last_movable_size
        upload!(renderer.movable_buffer,1,renderer.movable_coords,0)
        upload!(renderer.movable_buffer,2,renderer.movable_colors,0)
        upload!(renderer.movable_buffer,3,renderer.movable_sizes,0)
        upload!(renderer.movable_buffer,4,renderer.movable_ids,0)
        renderer.last_movable_size = length(renderer.movable_coords)
    end
    if length(renderer.dependent_coords) != renderer.last_dependent_size
        upload!(renderer.dependent_buffer,1,renderer.dependent_coords,0)
        upload!(renderer.dependent_buffer,2,renderer.dependent_colors,0)
        upload!(renderer.dependent_buffer,3,renderer.dependent_sizes,0)
        upload!(renderer.dependent_buffer,4,renderer.dependent_ids,0)
        renderer.last_dependent_size = length(renderer.dependent_coords)
    end
    return nothing
end

update_coord!(movable::Bool,ref::UInt32) = update_coord!(movable,(ref,ref))
function update_coord!(movable::Bool,ref::Tuple{UInt32,UInt32})
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    if movable
        renderer.updated |= _POINT_UPDATED_MOVABLE_COORD
        return view(renderer.movable_coords,ref[1]:ref[2])
    else
        renderer.updated |= _POINT_UPDATED_DEPENDENT_COORD
        return view(renderer.dependent_coords,ref[1]:ref[2])
    end
end

function update_coord_dynamic!(ref::UInt32)
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    return renderer.dependent_buffer_dynamic[ref]
end

update_color!(movable::Bool,ref::UInt32) = update_color!(movable,Tuple{UInt32,UInt32}(ref,ref))
function update_color!(movable::Bool,ref::Tuple{UInt32,UInt32})
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    if movable
        renderer.updated |= _POINT_UPDATED_MOVABLE_COLOR
        return view(renderer.movable_colors,ref[1]:ref[2])
    else
        renderer.updated |= _POINT_UPDATED_DEPENDENT_COLOR
        return view(renderer.dependent_colors,ref[1]:ref[2])
    end
end

function sync_all!(::Val{:Point})::Nothing
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer
    if (renderer.updated & _POINT_UPDATED_MOVABLE_COORD != 0) || (renderer.updated & _POINT_UPDATED_MOVABLE_COLOR != 0)
        wait(renderer.movable_buffer[1])
    end
    if renderer.updated & _POINT_UPDATED_MOVABLE_COORD != 0
        copyto!(renderer.movable_buffer[1],renderer.movable_coords)
    end
    if renderer.updated & _POINT_UPDATED_MOVABLE_COLOR != 0
        copyto!(renderer.movable_buffer[2],renderer.movable_colors)
    end

    if (renderer.updated & _POINT_UPDATED_DEPENDENT_COORD != 0) || (renderer.updated & _POINT_UPDATED_DEPENDENT_COLOR != 0)
        wait(renderer.dependent_buffer[1])
    end
    if renderer.updated & _POINT_UPDATED_DEPENDENT_COORD != 0
        copyto!(renderer.dependent_buffer[1],renderer.dependent_coords)
    end
    if renderer.updated & _POINT_UPDATED_DEPENDENT_COLOR != 0
        copyto!(renderer.dependent_buffer[2],renderer.dependent_colors)
    end

    renderer.updated = 0;
    return nothing
end

function opaque(::Val{:Point},cam::Camera,shrd::SharedData)::Nothing
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer

    (vp, view, _) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    side_light = view[1:3,1:3] * side_light

    if renderer.last_movable_size != 0
        activate(renderer.movable_shader)
        uniform(renderer.movable_shader,"VP",vp)
        uniform(renderer.movable_shader,"selected_id", shrd._selectedID)
        uniform(renderer.movable_shader,"picked_id", shrd._pickedID)
        uniform(renderer.movable_shader,"light_dir_side_view", side_light)
        @time_gpu_begin Renderer Point Movable
        draw(renderer.movable_buffer,GL_POINTS)
        @time_gpu_end Renderer Point Movable
        lock(renderer.movable_buffer[1])
    end

    if renderer.last_dependent_size != 0
        activate(renderer.dependent_shader)
        uniform(renderer.movable_shader,"VP",vp)
        uniform(renderer.movable_shader,"light_dir_side_view", side_light)
        draw(renderer.dependent_buffer,GL_POINTS)
        lock(renderer.dependent_buffer[1])
    end

    if length(renderer.dependent_buffer_dynamic) != 0
        activate(renderer.dependent_shader)
        uniform(renderer.movable_shader,"VP",vp)
        uniform(renderer.movable_shader,"light_dir_side_view", side_light)
        for buffer_arr in renderer.dependent_buffer_dynamic
            draw(buffer_arr,GL_POINTS)
            lock(buffer_arr[1])
        end
    end

    return nothing
end