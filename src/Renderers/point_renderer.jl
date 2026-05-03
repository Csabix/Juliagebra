# GREEN Thread

const _POINT_UPDATED_COORD::UInt8 = 1
const _POINT_UPDATED_PROPERTY::UInt8 = 2

@bitflag PointPropertyUpdate::UInt8 begin
    _POINT_PROP_NONE        = 0
    _POINT_PROP_COORD       = 1
    _POINT_PROP_COLOR_SIZE  = 2
    _POINT_PROP_STYLE_ID    = 4
end

const POINT_NONE::UInt8 = 0
const POINT_PLUS::UInt8 = 1

function pack_point_property(color::UInt32,style::UInt8,size::UInt8,id::UInt32)::Tuple{UInt32, UInt32}
    const lower_mask = ~(UInt32(0xff) << 24)
    color_size = (UInt32(size) << 24) | color & lower_mask
    style_id = (UInt32(style) << 24) | id & lower_mask
    return color_size, style_id
end

function _point_renderer_buffer_array()
    attributes = [nothing,
        [VertexAttrib(false,4,GL_UNSIGNED_BYTE,GL_TRUE,0)],   # loc 1: color+size (4 normalized bytes)
        [VertexAttrib(true,1,GL_UNSIGNED_INT,GL_FALSE,0)]]    # loc 2: style_id   (1 uint, offset 0)
    return BufferArray{Tuple{MappedBuffer{Vec3F}, MappedBuffer{UInt32}, MappedBuffer{UInt32}}}(attributes)
end

@kwdef struct PointsData
    buffer::BufferArray{Tuple{MappedBuffer{Vec3F}, MappedBuffer{UInt32}, MappedBuffer{UInt32}}} = _point_renderer_buffer_array()
    coords::Vector{Vec3F}       = Vector{Vec3F}()
    color_sizes::Vector{UInt32} = Vector{UInt32}()
    style_ids::Vector{UInt32}   = Vector{UInt32}()
    update::PointPropertyUpdate = _POINT_PROP_NONE
end

function destroy!(points_data::PointsData)
    destroy!(points_data.buffer)
end

function add!(points_data::PointsData,coord::Vec3F,color::UInt32,style::UInt8,size::UInt8,id::UInt32)
    push!(points_data.coords,coord)
    prop = pack_point_property(color,style,size,id)
    push!(points_data.color_sizes, prop[1])
    push!(points_data.style_ids,   prop[2])
end

function add!(points_data::PointsData,coords,colors,styles,sizes,ids)
    last_length = length(points_data.coords)
    append!(points_data.coords, coords)
    coords_length = length(points_data.coords) - last_length
    for (color,style,size,id) in zip(take(colors,coords_length), styles, sizes, ids)
        prop = pack_point_property(color,style,size,id)
        push!(points_data.color_sizes, prop[1])
        push!(points_data.style_ids,   prop[2])
    end
end

function added_all!(points_data::PointsData)
    if length(points_data.buffer[1]) != length(points_data.coords)
        upload!(points_data.buffer,1,points_data.coords,0)
        upload!(points_data.buffer,2,points_data.color_sizes,0)
        upload!(points_data.buffer,3,points_data.style_ids,0)
        points_data.update = _POINT_PROP_NONE
    end
end

function update_coords!(points_data::PointsData, coord::Vec3F, offset::Int = 1)
    points_data.coords[offset] = coord
    points_data.update |= _POINT_PROP_COORD
end
function update_coords!(points_data::PointsData, coords, offset::Int = 1)
    copyto!(view(points_data.coords,offset:(offset + length(coords) - 1)),coords)
    points_data.update |= _POINT_PROP_COORD
end

function update_colors!(points_data::PointsData, color::UInt32, offset::Int = 1)
    const upper_mask = UInt32(0xff) << 24
    const lower_mask = ~(UInt32(0xff) << 24)
    points_data.color_sizes[offset] = points_data.color_sizes[offset] & upper_mask | color & lower_mask
    points_data.update = _POINT_PROP_COLOR_SIZE
end
function update_colors!(points_data::PointsData, len::Int, colors, offset::Int = 1)
    for (i,color) in enumerate(take(colors,len))
        update_colors!(points_data,color,offset+i-1)
    end
end

function update_sizes!(points_data::PointsData, size::UInt8, offset::Int = 1)
    const lower_mask = ~(UInt32(0xff) << 24)
    points_data.color_sizes[offset] = (UInt32(size) << 24) | points_data.color_sizes[offset] & lower_mask
    points_data.update = _POINT_PROP_COLOR_SIZE
end
function update_sizes!(points_data::PointsData, len::Int, sizes, offset::Int = 0)
    for (i,size) in enumerate(take(sizes,len))
        update_sizes!(points_data,size,offset+i)
    end
end

function update_styles!(points_data::PointsData, style::UInt8, offset::Int = 1)
    const lower_mask = ~(UInt32(0xff) << 24)
    points_data.style_ids[offset] = (UInt32(style) << 24) | points_data.style_ids[offset] & lower_mask
    points_data.update = _POINT_PROP_STYLE_ID
end
function update_styles!(points_data::PointsData, len::Int, styles, offset::Int)
    for (i,style) in enumerate(take(styles,len))
        update_styles!(points_data,style,offset+i)
    end
end

function update_ids!(points_data::PointsData, id::UInt32, offset::Int = 1)
    const upper_mask = UInt32(0xff) << 24
    const lower_mask = ~(UInt32(0xff) << 24)
    points_data.style_ids[offset] = points_data.style_ids[offset] & upper_mask | id & lower_mask
    points_data.update = _POINT_PROP_STYLE_ID
end
function update_ids!(points_data::PointsData, len::Int, ids, offset::Int = 0)
    for (i,id) in enumerate(take(ids,len))
        update_ids!(points_data,id,offset+i)
    end
end

function update_properties!(points_data::PointsData, color::UInt32, style::UInt8, size::UInt8, id::UInt32, offset::Int = 1)
    prop = pack_point_property(color,style,size,id)
    points_data.color_sizes[offset] = prop[1]
    points_data.style_ids[offset]    = prop[2]
    points_data.update |= _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID
end
function update_properties!(points_data::PointsData, len::Int, colors, styles, sizes, ids, offset::Int = 0)
    for (i,(color,style,size,id)) in enumerate(zip(take(colors,len), styles, sizes, ids))
        update_properties!(points_data,color,style,size,id,offset+i)
    end
end

function update!(points_data::PointsData, coords, colors, styles, sizes, ids)
    empty!(points_data.coords)
    empty!(points_data.color_sizes)
    empty!(points_data.style_ids)
    append!(points_data.coords, coords)
    for (color,style,size,id) in zip(take(colors,length(colors)), styles, sizes, ids)
        prop = pack_point_property(color,style,size,id)
        push!(points_data.color_sizes, prop[1])
        push!(points_data.type_ids,    prop[2])
    end
    points_data.update |= _POINT_PROP_COLOR_SIZE | _POINT_PROP_STYLE_ID | _POINT_PROP_COORD
end

function sync_all!(points_data::PointsData)
    n = length(points_data.coords)

    if points_data.update & _POINT_PROP_COORD == _POINT_PROP_COORD
        if n != length(points_data.buffer[1])
            reserve!(points_data.buffer,1,length(points_data.coords),0)
        end
        copyto!(points_data.buffer[1], points_data.coords)
    end

    if points_data.update & _POINT_PROP_COLOR_SIZE == _POINT_PROP_COLOR_SIZE
        if n != length(points_data.buffer[2])
            reserve!(points_data.buffer,2,n,0)
        end
        copyto!(points_data.buffer[2], points_data.color_sizes)
    end

    if points_data.update & _POINT_PROP_STYLE_ID == _POINT_PROP_STYLE_ID
        if n != length(points_data.buffer[3])
            reserve!(points_data.buffer,3,n,0)
        end
        copyto!(points_data.buffer[3], points_data.type_ids)
    end

    points_data.update = _POINT_PROP_NONE
    return nothing
end

Base.length(points_data::PointsData)::Int = length(points_data.coords)

mutable struct PointRenderer
    shader::ShaderProgram
    shader_behind::ShaderProgram
    points::Vector{PointsData}

    function PointRenderer()
        uniforms_opaque = String["selected_id","picked_id","light_dir_side_view"]
        uniforms_behind = String["selected_id","picked_id"]
        shader = ShaderProgram(["renderers/point/point.vert",("renderers/point/point.frag")], uniforms_opaque)
        shader_behind = ShaderProgram(["renderers/point/point.vert",("renderers/point/point.frag",["OPAQUE_BEHIND"])], uniforms_behind)
        return new(shader, shader_behind, PointsData[PointsData()], UInt8[0x0])
    end
end

function destroy!(self::PointRenderer)::Nothing
    destroy!(self.shader)
    destroy!(self.shader_behind)
    foreach(destroy!,self.points)
    return nothing
end

function add!(self::PointRenderer,coord::Vec3F,color::UInt32,style::UInt8,size::UInt8,id::UInt32)::UInt32
    add!(self.points[1], coord, color, style, size, id)
    return UInt32(length(self.points[1]))
end

function add!(self::PointRenderer,coords,colors,styles,sizes,ids)::UInt32
    ref::UInt32 = UInt32(length(self.points[1])) + 1
    add!(self.points[1], coords, colors, styles, sizes, ids)
    return ref
end

function add_dynamic!(self::PointRenderer,coords,colors,styles,sizes,ids)::UInt32
    points_data::PointsData = PointsData()
    add!(points_data, coords, colors, styles, sizes, ids)
    push!(self.points, points_data)
    push!(self.updates,0x0)
    return length(self.points)
end

function added_all!(self::PointRenderer)::Nothing
    foreach(added_all!,self.points)
    return nothing
end

update_coords!(self::PointRenderer,ref::UInt32,coord::Vec3F) = update_coords!(self.points[1], coord, Int(ref))
update_properties(self::PointRenderer,ref::UInt32,color::UInt32,style::UInt8,size::UInt8,id::UInt32) =
    update_properties!(self.points[1], color, style, size, id, Int(ref))

update_coords!(self::PointRenderer,ref::UInt32,coords) = update_coords!(self.points[1], coords, Int(ref))
update_properties(self::PointRenderer,ref::UInt32,length::UInt32,colors,styles,sizes,ids) =
    update_properties!(self.points[1], length, colors, styles, sizes, ids, ref)

update_dyncamic!(self::PointRenderer,ref::UInt32,coords,colors,styles,sizes,ids) =
    update!(self.points[ref], coords, colors, styles, sizes, ids)

function sync_all!(self::PointRenderer)::Nothing
    all(e -> e.update == _POINT_PROP_NONE) && return nothing
    wait(self.points[1].buffer[1])
    foreach(sync_all!,self.points)
    return nothing
end

function opaque(self::PointRenderer,cam::Camera,shrd::SharedData)::Nothing
    (vp, v, p) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    side_light = v[SOneTo(3), SOneTo(3)] * side_light

    activate(self.shader)
    uniform(self.shader,"selected_id", shrd._selectedID)
    uniform(self.shader,"picked_id", shrd._pickedID)
    uniform(self.shader,"light_dir_side_view", side_light)

    @time_gpu_begin Renderer Point
    for points_data in self.points
        if length(points_data.coords) != 0
            draw(points_data.buffer,GL_POINTS)
        end
    end
    @time_gpu_end Renderer Point
    lock(self.points[1].buffer[1])
    return nothing
end

function behind_opaque(self::PointRenderer,cam::Camera,shrd::SharedData)::Nothing
    (vp, v, p) = get_matrices(cam)
    (_, side_light) = get_lights(cam)
    side_light = v[SOneTo(3), SOneTo(3)] * side_light

    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glColorMaski(1, GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)

    activate(self.shader_behind)
    uniform(self.shader_behind,"selected_id", shrd._selectedID)
    uniform(self.shader_behind,"picked_id", shrd._pickedID)

    for points_data in self.points
        if length(points_data.coords) != 0
            draw(points_data.buffer,GL_POINTS)
        end
    end

    glColorMaski(1, GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
    glDisable(GL_BLEND)
    return nothing
end