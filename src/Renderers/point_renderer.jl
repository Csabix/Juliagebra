# GREEN Thread

const POINT_UPDATED_MOVABLE_COORD::UInt32 = 1
const POINT_UPDATED_MOVABLE_COLOR::UInt32 = 2
const POINT_UPDATED_DEPENDENT_COORD::UInt32 = 4
const POINT_UPDATED_DEPENDENT_COLOR::UInt32 = 8

mutable struct StaticPointRenderer <: BaseRenderer
    updated::UInt32

    movable_shader::ShaderProgram
    dependent_shader::ShaderProgram

    movable_buffer::BufferArray
    dependent_buffer::BufferArray

    movable_coords::Vector{Vec3F}
    movable_colors::Vector{Uint32}
    movable_ids::Vector{Uint32}

    dependent_coords::Vector{Vec3F}
    dependent_colors::Vector{Uint32}
    dependent_ids::Vector{Uint32}

    function StaticPointRenderer()
        updated::UInt32 = 0

        movable_shader::ShaderProgram = ShaderProgram()
        dependent_shader::ShaderProgram = ShaderProgram()

        movable_buffer::BufferArray = BufferArray{Tuple{Vec3F,Uint32,UInt32}}(MappedBuffer,MappedBuffer,Buffer)
        dependent_buffer::BufferArray = BufferArray{Tuple{Vec3F,Uint32,UInt32}}(MappedBuffer,MappedBuffer,Buffer)

        movable_coords::Vector{Vec3F} = Vector{Vec3F}()
        movable_colors::Vector{Uint32} = Vector{Uint32}()
        movable_ids::Vector{Uint32} = Vector{Uint32}()

        dependent_coords::Vector{Vec3F} = Vector{Vec3F}()
        dependent_colors::Vector{Uint32} = Vector{Uint32}()
        dependent_ids::Vector{Uint32} = Vector{Uint32}()

        return new(
            updated,
            movable_shader,dependent_shader,
            movable_buffer,dependent_buffer,
            movable_coords,movable_colors,movable_ids,
            dependent_coords,dependent_colors,dependent_ids)
    end
end

function added!(self::StaticPointRenderer,movable::Bool,coord::Vec3F,color::UInt32,id::UInt32)::Tuple{SubArray{Vec3F},SubArray{UInt32}}
    if movable
        last_length = length(self.movable_coords)
        push!(self.movable_coords,coord)
        push!(self.movable_colors,color)
        push!(self.movable_ids,id)
        return (view(self.movable_coord, last_length:length(self.movable_coords)), view(self.movable_colors, last_length:length(self.movable_coords)))
    else
        last_length = length(self.dependent_coords)
        push!(self.dependent_coords,coord)
        push!(self.dependent_colors,color)
        push!(self.dependent_ids,id)
        return (view(self.dependent_coords, last_length:length(self.dependent_coords)), view(self.dependent_colors, last_length:length(self.dependent_coords)))
    end
end

function added!(self::StaticPointRenderer,movable::Bool,coords::Vector{Vec3F},colors::Vector{UInt32},ids::Vector{UInt32})::Tuple{SubArray{Vec3F},SubArray{UInt32}}
    if movable
        last_length = length(self.movable_coords)
        for coord in coords push!(self.movable_coords,coord) end
        for color in colors push!(self.movable_colors,color) end
        for id in ids push!(self.movable_ids,id) end
        return (view(self.movable_coord, last_length:length(self.movable_coords)), view(self.movable_colors, last_length:length(self.movable_coords)))
    else
        last_length = length(self.dependent_coords)
        for coord in coords push!(self.dependent_coords,coord) end
        for color in colors push!(self.dependent_colors,color) end
        for id in ids push!(self.dependent_ids,id) end
        return (view(self.dependent_coords, last_length:length(self.dependent_coords)), view(self.dependent_colors, last_length:length(self.dependent_coords)))
    end
end

function added_all!(self::StaticPointRenderer)::Nothing
    if length(self.movable_coords) != 0
        upload!(movable_buffer,1,self.movable_coords,0)
        upload!(movable_buffer,2,self.movable_colors,0)
        upload!(movable_buffer,3,self.movable_ids,0)
    end
    if length(self.dependent_coords) != 0
        upload!(movable_buffer,1,self.dependent_coords,0)
        upload!(movable_buffer,2,self.dependent_colors,0)
        upload!(movable_buffer,3,self.dependent_ids,0)
    end
    return nothing
end

function sync!(self::StaticPointRenderer,updated::UInt32)::Nothing
    self.updated |= updated
    return nothing
end

function sync_all!(self::StaticPointRenderer)::Nothing
    if (self.updated & POINT_UPDATED_MOVABLE_COORD != 0) || (self.updated & POINT_UPDATED_MOVABLE_COLOR != 0)
        wait(self.movable_buffer[1])
    end
    if self.updated & POINT_UPDATED_MOVABLE_COORD != 0
        copyto!(self.movable_buffer[1],self.movable_coords)
    end
    if self.updated & POINT_UPDATED_MOVABLE_COLOR != 0
        copyto!(self.movable_buffer[2],self.movable_colors)
    end

    if (self.updated & POINT_UPDATED_DEPENDENT_COORD != 0) || (self.updated & POINT_UPDATED_DEPENDENT_COLOR != 0)
        wait(self.dependent_buffer[1])
    end
    if self.updated & POINT_UPDATED_DEPENDENT_COORD != 0
        copyto!(self.dependent_buffer[1],self.dependent_coords)
    end
    if self.updated & POINT_UPDATED_DEPENDENT_COLOR != 0
        copyto!(self.dependent_buffer[2],self.dependent_colors)
    end

    self.updated = 0;
    return nothing
end

is_occluder(self::StaticPointRenderer)::Bool = false

function opaque(self::StaticPointRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (_, view, _) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    @time_gpu_begin Renderer Point
    if length(self.movable_buffer) != 0
        activate(self.movable_shader)
        uniform(self.movable_shader,"VP",vp)
        uniform(self.movable_shader,"selectedID",shrd._selectedID)
        uniform(self.movable_shader,"pickedID",shrd._pickedID)
        uniform(self.movable_shader,"lightDirSideView", view[1:3,1:3] * side_light)
        draw(self.movable_buffer,GL_POINTS)
        lock(self.movable_buffer[1])
    end

    if length(self.dependent_buffer) != 0
        activate(self.dependent_shader)
        uniform(self.dependent_shader,"VP",vp)
        uniform(self.dependent_shader,"selectedID",shrd._selectedID)
        uniform(self.dependent_shader,"pickedID",shrd._pickedID)
        uniform(self.dependent_shader,"lightDirSideView", view[1:3,1:3] * side_light)
        draw(self.dependent_buffer,GL_POINTS)
        lock(self.dependent_buffer[1])
    end
    @time_gpu_end Renderer Point

    return nothing
end