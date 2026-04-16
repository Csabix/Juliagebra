# GREEN Thread

const _POINT_UPDATED_COORD::UInt8 = 1
const _POINT_UPDATED_PROPERTY::UInt8 = 2

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
    return BufferArray{Tuple{MappedBuffer{Vec3F}, MappedBuffer{Vec2T{UInt32}}}}(attributes)
end

struct PointsData
    buffer::BufferArray{Tuple{MappedBuffer{Vec3F}, MappedBuffer{Vec2T{UInt32}}}}
    coords::Vector{Vec3F}
    point_properties::Vector{Vec2T{UInt32}}

    PointsData() = new(_point_renderer_buffer_array(), Vector{Vec3F}(), Vector{Vec2T{UInt32}}())
end

function destroy!(points_data::PointsData)
    destroy!(points_data.buffer)
end

function add!(points_data::PointsData,coord::Vec3F,type::UInt32,color::Vec3F,size::UInt8,id::UInt32)
    push!(points_data.coords,coord)
    push!(points_data.point_properties,pack_point_property(type,color,size,id))
end

function add!(points_data::PointsData,coords,types,colors,sizes,ids)
    last_length::Int = length(points_data.coords)
    append!(points_data.coords, coords)
    coords_length::Int = length(points_data.coords) - last_length
    append!(points_data.point_properties, imap(pack_point_property, take(types, coords_length), colors, sizes, ids))
end

function added_all!(points_data::PointsData)
    if length(points_data.buffer[1]) != length(points_data.coords)
        upload!(points_data.buffer,1,points_data.coords,0)
        upload!(points_data.buffer,2,points_data.point_properties,0)
    end
end

update_coords!(points_data::PointsData, coord::Vec3F, offset::Int = 1) =
    points_data.coords[offset] = coord

update_coords!(points_data::PointsData, coords, offset::Int = 1) =
    copyto!(view(points_data.coords,offset:(offset + length(coords) - 1U)),coords)

update_properties!(points_data::PointsData, type::UInt32, color::Vec3F, size::UInt8, id::UInt32, offset::Int = 1) =
    points_data.point_properties[offset] = pack_point_property(type, color, size, id)

update_properties!(points_data::PointsData, length::Int, types, colors, sizes, ids, offset::Int = 1) =
    copyto!(view(points_data.point_properties,offset:(offset + length - 1U)),
    imap(pack_point_property, take(types, length), colors, sizes, ids))

function update!(points_data::PointsData, coords, types, colors, sizes, ids)
    empty!(points_data.coords)
    empty!(points_data.point_properties)
    append!(points_data.coords, coords)
    append!(points_data.point_properties, imap(pack_point_property, take(types, length(points_data.coords)), colors, sizes, ids))
end

Base.length(points_data::PointsData)::Int = length(points_data.coords)

mutable struct PointRenderer
    shader::ShaderProgram
    points::Vector{PointsData}
    updates::Vector{UInt8}
    
    function PointRenderer()
        uniforms = String["v_2_x","P","VP","selected_id","picked_id","light_dir_side_view","width_p_0_0"]
        shader::ShaderProgram = ShaderProgram(["renderers/point/point.vert",("renderers/point/point.frag",OPAQUE)], uniforms)
        return new(shader, PointsData[PointsData()],UInt8[0x0])
    end
end

function destroy!(self::PointRenderer)::Nothing
    destroy!(self.shader)
    foreach(destroy!,self.points)
    return nothing
end

function add!(self::PointRenderer,coord::Vec3F,type::UInt32,color::Vec3F,size::UInt8,id::UInt32)::UInt32
    add!(self.points[1], coord, type, color, size, id)
    return UInt32(length(self.points[1]))
end

function add!(self::PointRenderer,coords,types,colors,sizes,ids)::UInt32
    ref::UInt32 = UInt32(length(self.points[1])) + 1
    add!(self.points[1], coords, types, colors, sizes, ids)
    return ref
end

function add_dynamic!(self::PointRenderer,coords,types,colors,sizes,ids)::UInt32
    points_data::PointsData = PointsData()
    add!(points_data, coords, types, colors, sizes, ids)
    push!(self.points, points_data)
    push!(self.updates,0x0)
    return length(self.points)
end

function added_all!(self::PointRenderer)::Nothing
    foreach(added_all!,self.points)
    return nothing
end

function update_coords!(self::PointRenderer,ref::UInt32,coord::Vec3F)
    update_coords!(self.points[1], coord, Int(ref))
    self.updates[1] |= _POINT_UPDATED_COORD
end
function update_properties(self::PointRenderer,ref::UInt32,type::UInt32,color::Vec3F,size::UInt8,id::UInt32)
    update_properties!(self.points[1], type, color, size, id, Int(ref))
    self.updates[1] |= _POINT_UPDATED_PROPERTY
end
function update_coords!(self::PointRenderer,ref::UInt32,coords)
    update_coords!(self.points[1], coords, Int(ref))
    self.updates[1] |= _POINT_UPDATED_COORD
end
function update_properties(self::PointRenderer,ref::UInt32,length::UInt32,types,colors,sizes,ids)
    update_properties!(self.points[1], length, types, colors, sizes, ids, ref)
    self.updates[1] |= _POINT_UPDATED_PROPERTY
end

function update_dyncamic!(self::PointRenderer,ref::UInt32,coords,types,colors,sizes,ids)
    update!(self.points[ref], coords, types, colors, sizes, ids)
    self.updates[ref] |= _POINT_UPDATED_PROPERTY | _POINT_UPDATED_COORD
end

function sync_all!(self::PointRenderer)::Nothing
    if any(x -> x != 0x0, self.updates)
        wait(self.points[1].buffer[1])
        for (i,points_data) in enumerate(self.points)
            if (self.updates[i] & _POINT_UPDATED_COORD) != 0x0
                if length(points_data.coords) != length(points_data.buffer[1])
                    reserve!(points_data.buffer,1,length(points_data.coords),0)
                end
                copyto!(points_data.buffer[1], points_data.coords)
            end
            if (self.updates[i] & _POINT_UPDATED_PROPERTY) != 0x0
                if length(points_data.coords) != length(points_data.buffer[2])
                    reserve!(points_data.buffer,2,length(points_data.coords),0)
                end
                copyto!(points_data.buffer[2], points_data.point_properties)
            end
        end
    end
    fill!(self.updates, 0x0)
    return nothing
end

function opaque(self::PointRenderer,cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_STENCIL_TEST)
    (vp, v, p) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    side_light = v[SOneTo(3), SOneTo(3)] * side_light

    activate(self.shader)
    uniform(self.shader,"VP",vp)
    uniform(self.shader,"v_2_x",v[3,:])
    uniform(self.shader,"P",p)
    uniform(self.shader,"width_p_0_0",Vec2F(Float32(shrd._width),p[1][1]))
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
    glEnable(GL_STENCIL_TEST)
    return nothing
end