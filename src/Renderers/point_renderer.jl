# GREEN Thread

const _POINT_UPDATED_COORD::UInt32 = 1
const _POINT_UPDATED_PROPERTY::UInt32 = 2
const _POINT_UPDATED_COORD_DYNAMIC::UInt32 = 4
const _POINT_UPDATED_PROPERTY_DYNAMIC::UInt32 = 8

const POINT_NONE::UInt32 = 0
const POINT_PLUS::UInt32 = 1

function pack_point_property(type::UInt32,color::Vec3F,size::UInt8,id::UInt32)::Vec2T{UInt32}
    c1 = UInt32(round(clamp(color[1], 0.0, 1.0) * 255.0))
    c2 = UInt32(round(clamp(color[2], 0.0, 1.0) * 255.0))
    c3 = UInt32(round(clamp(color[3], 0.0, 1.0) * 255.0))
    c4 = UInt32(size)
    color_size = (c4 << 24) | (c3 << 16) | (c2 << 8) | c1
    type_id = id | (type << 24)
    return Vec2T{UInt32}(color_size, type_id)
end

function _point_renderer_buffer_array()
    attributes = [nothing,
    [VertexAttrib(false,4,GL_UNSIGNED_BYTE,GL_TRUE,0),
    VertexAttrib(true,1,GL_UNSIGNED_INT,GL_FALSE,sizeof(Cuint))]]
    return BufferArray{Tuple{Vec3F,Vec2T{UInt32}}}(attributes,MappedBuffer,MappedBuffer)
end

mutable struct GlobalPointRenderer
    updated::UInt32
    shader::ShaderProgram
    # Static
    buffer::BufferArray
    coords::Vector{Vec3F}
    point_properties::Vector{Vec2T{UInt32}}
    # Dynamic
    buffer_dynamic::BufferArray
    coords_dynamic::Vector{Vector{Vec3F}}
    point_properties_dynamic::Vector{Vector{Vec2T{UInt32}}}
    last_length_dynamic::UInt32
    
    function GlobalPointRenderer()
        updated::UInt32 = 0

        uniforms = String["VP","selected_id","picked_id","light_dir_side_view"]
        shader::ShaderProgram = ShaderProgram(["renderers/point/point.vert","renderers/point/point.frag"], uniforms)
        
        buffer::BufferArray = _point_renderer_buffer_array()
        coords::Vector{Vec3F} = Vector{Vec3F}()
        point_properties::Vector{Vec2T{UInt32}} = Vector{Vec2T{UInt32}}()
        
        buffer_dynamic::BufferArray = _point_renderer_buffer_array()
        coords_dynamic::Vector{Vector{Vec3F}} = Vector{Vector{Vec3F}}()
        point_properties_dynamic::Vector{Vector{Vec2T{UInt32}}} = Vector{Vector{Vec2T{UInt32}}}()
        
        return new(
            updated,
            shader,
            buffer,coords,point_properties,
            buffer_dynamic,coords_dynamic,point_properties_dynamic,UInt32(0))
    end
end
_point_renderer::Union{GlobalPointRenderer,Nothing} = nothing

function init!(::Val{:Point})::Nothing
    global _point_renderer
    if !isnothing(_point_renderer) destroy!(Val{:Point}()) end
    _point_renderer = GlobalPointRenderer()
    return nothing
end

function destroy!(::Val{:Point})::Nothing
    global _point_renderer
    @assert !isnothing(_point_renderer)
    renderer::GlobalPointRenderer = _point_renderer::GlobalPointRenderer

    destroy!(renderer.shader)
    destroy!(renderer.buffer)
    destroy!(renderer.buffer_dynamic)

    _point_renderer = nothing
    return nothing
end

function get_renderer(::Val{:Point})::GlobalPointRenderer
    global _point_renderer
    @assert !isnothing(_point_renderer)
    return _point_renderer::GlobalPointRenderer
end

function add!(::Val{:Point},coord::Vec3F,type::UInt32,color::Vec3F,size::UInt8,id::UInt32)::UInt32
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    push!(renderer.coords,coord)
    push!(renderer.point_properties,pack_point_property(type,color,size,id))
    return UInt32(length(renderer.coords))
end

function add!(::Val{:Point},coords,types,colors,sizes,ids)::UInt32
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    last_length = UInt32(length(renderer.coords))
    append!(renderer.coords, collect(coords))
    append!(renderer.point_properties, imap(pack_point_property, take(types,length(coords)), colors, sizes, ids))
    return last_length + 1
end

function add_dynamic!(::Val{:Point},coords,types,colors,sizes,ids)::UInt32
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    last_length = UInt32(length(renderer.coords_dynamic))
    push!(renderer.coords_dynamic, collect(coords))
    push!(renderer.point_properties_dynamic, collect(imap(pack_point_property, take(types,length(coords)), colors, sizes, ids)))
    return last_length + 1
end

function added_all!(::Val{:Point})::Nothing
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    if length(renderer.coords) != length(renderer.buffer[1])
        upload!(renderer.buffer,1,renderer.coords,0)
        upload!(renderer.buffer,2,renderer.point_properties,0)
    end

    renderer.last_length_dynamic = sum(length,renderer.coords_dynamic;init=0)
    if renderer.last_length_dynamic > length(renderer.buffer_dynamic[1])
        reserve!(renderer.buffer_dynamic,1,Int(renderer.last_length_dynamic),0)
        reserve!(renderer.buffer_dynamic,2,Int(renderer.last_length_dynamic),0)
        copyto!(renderer.buffer_dynamic[1],Iterators.flatten(renderer.coords_dynamic))
        copyto!(renderer.buffer_dynamic[2],Iterators.flatten(renderer.point_properties_dynamic))
    end
    renderer.updated = 0;
    return nothing
end

update_coords!(::Val{:Point},ref::UInt32) = update_coords!(Val{:Point}(),ref,UInt32(1))
function update_coords!(::Val{:Point},ref::UInt32,length::UInt32)
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    renderer.updated |= _POINT_UPDATED_COORD
    return view(renderer.coords,ref:(ref + length - 1))
end
update_property!(::Val{:Point},ref::UInt32) = update_properties!(Val{:Point}(),ref,UInt32(1))
function update_properties!(::Val{:Point},ref::UInt32,length::UInt32)
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    renderer.updated |= _POINT_UPDATED_PROPERTY
    return view(renderer.point_properties,ref:(ref + length - 1))
end

function update_dyncamic!(::Val{:Point},ref::UInt32,coords,types,colors,sizes,ids)
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    renderer.updated |= _POINT_UPDATED_COORD_DYNAMIC
    coords_dynamic = renderer.coords_dynamic[ref]
    last_size = length(coords_dynamic)
    empty!(coords_dynamic)
    append!(coords_dynamic,coords)
    if last_size != length(coords)
        renderer.updated |= _POINT_UPDATED_PROPERTY_DYNAMIC
        properties_dynamic = renderer.point_properties_dynamic[ref]
        empty!(properties_dynamic)
        append!(properties_dynamic,imap(pack_point_property, take(types,length(coords)), colors, sizes, ids))
    end
end

function sync!(::Val{:Point})::Nothing
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())
    if ((renderer.updated & _POINT_UPDATED_COORD) != 0) || ((renderer.updated & _POINT_UPDATED_PROPERTY) != 0)
        wait(renderer.buffer[1])
        if (renderer.updated & _POINT_UPDATED_COORD) != 0
            copyto!(renderer.buffer[1],renderer.coords)
        end
        if (renderer.updated & _POINT_UPDATED_PROPERTY) != 0
            copyto!(renderer.buffer[2],renderer.point_properties)
        end
    end
    
    if ((renderer.updated & _POINT_UPDATED_COORD_DYNAMIC) != 0) || ((renderer.updated & _POINT_UPDATED_PROPERTY_DYNAMIC) != 0)
        renderer.last_length_dynamic = sum(length,renderer.coords_dynamic;init=0)
        wait(renderer.buffer_dynamic[1])
        if renderer.last_length_dynamic > length(renderer.buffer_dynamic[1])
            reserve!(renderer.buffer_dynamic,1,Int(renderer.last_length_dynamic),0)
            reserve!(renderer.buffer_dynamic,2,Int(renderer.last_length_dynamic),0)
            copyto!(renderer.buffer_dynamic[1],Iterators.flatten(renderer.coords_dynamic))
            copyto!(renderer.buffer_dynamic[2],Iterators.flatten(renderer.point_properties_dynamic))
        else
            if (renderer.updated & _POINT_UPDATED_COORD_DYNAMIC) != 0
                copyto!(renderer.buffer_dynamic[1],Iterators.flatten(renderer.coords_dynamic))
            end
            if renderer.updated & _POINT_UPDATED_PROPERTY_DYNAMIC != 0
                copyto!(renderer.buffer_dynamic[2],Iterators.flatten(renderer.point_properties_dynamic))
            end
        end
    end
        
    renderer.updated = 0;
    return nothing
end

function opaque(::Val{:Point},cam::Camera,shrd::SharedData)::Nothing
    renderer::GlobalPointRenderer = get_renderer(Val{:Point}())

    (vp, view, _) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    side_light = view[1:3,1:3] * side_light

    activate(renderer.shader)
    uniform(renderer.shader,"VP",vp)
    uniform(renderer.shader,"selected_id", shrd._selectedID)
    uniform(renderer.shader,"picked_id", shrd._pickedID)
    uniform(renderer.shader,"light_dir_side_view", side_light)

    if length(renderer.coords) != 0
        @time_gpu_begin Renderer Point Static
        draw(renderer.buffer,GL_POINTS)
        @time_gpu_end Renderer Point Static
        lock(renderer.buffer[1])
    end
    
    if renderer.last_length_dynamic != 0
        @time_gpu_begin Renderer Point Dynamic
        draw(renderer.buffer_dynamic,GL_POINTS,GLsizei(sum(length,renderer.coords_dynamic;init=0)))
        @time_gpu_end Renderer Point Dynamic
        lock(renderer.buffer_dynamic[1])
    end
    return nothing
end