struct _TriangleTransform
    M::Mat4T{Float32}
    MIT::Mat4T{Float32}
    _TriangleTransform(M::Mat4T{Float32}) = new(M,inv(transpose(M)))
end

mutable struct TriangleRenderer
    shader_calc_normals::Pipeline
    shader_opaque::Pipeline
    shader_transparent::Pipeline

    UBO::RepeatBufferUBO{_TriangleTransform}
    buffers::Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}} # position normal color id

    matrices::Vector{Mat4T{Float32}}
    coords::Vector{Vector{Vec4F}}
    color_ids::Vector{Vec2T{UInt32}}
    infinite_ids::Vector{Bool}

    update_normals::Vector{UInt32}
    color_updates::Vector{UInt32}
    # ubo_infinite::MappedBuffer{Int32}

    function TriangleRenderer(loader::PipelineLoader)
        calc_normals = create_compute_pipeline!(loader,spv"renderers/triangle/triangle_normal.comp")
        opaque = create_graphics_pipeline!(loader;
            vert = spv"renderers/triangle/triangle.vert",
            frag = spv"renderers/triangle/triangle_opaque.frag")
        transparent = create_graphics_pipeline!(loader,
            vert = spv"renderers/triangle/triangle.vert",
            frag = spv"renderers/triangle/triangle_transparent.frag")

        # ubo_infinite = MappedBuffer{Int32}()
        # reserve!(ubo_infinite, 1, 0)
        # ubo_infinite[1] = false;
        # ubo_infinite[1] = 0;

        new(calc_normals,opaque,transparent,
            RepeatBufferUBO{_TriangleTransform}(),
            Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}}(),
            Vector{Mat4T{Float32}}(),Vector{Vector{Vec3F}}(),Vector{Vec2T{UInt32}}(),Vector{Bool}(),
            Vector{UInt32}(),
            Vector{UInt32}(),
            # ubo_infinite
        )
    end
end

function reset!(self::TriangleRenderer)::Nothing
    foreach(destroy!, self.buffers)

    self.buffers = Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}}()
    self.matrices = Vector{Mat4T{Float32}}()
    self.coords = Vector{Vector{Vec3F}}()
    self.color_ids = Vector{Vec2T{UInt32}}()
    self.update_normals = Vector{UInt32}()
    self.color_updates = Vector{UInt32}()
    return nothing
end

function destroy!(self::TriangleRenderer)::Nothing
    foreach(destroy!, self.buffers)
    # destroy!(self.ubo_infinite)
end

function add!(self::TriangleRenderer,coords,matrix::Mat4T{Float32},color::UInt32,isInfinite::Bool,id::UInt32)::UInt32
    push!(self.coords, collect((Vec4F(c[1],c[2],c[3],1.0f0) for c in coords)))
    push!(self.matrices, matrix)
    push!(self.color_ids,UVec2(color,id))
    println(isInfinite)
    println(id)
    println(length(self.buffers))
    push!(self.infinite_ids,isInfinite)
    return UInt32(length(self.coords))
end

function update_color!(self::TriangleRenderer, ref::UInt32, color::UInt32)
    id_val = self.color_ids[ref][2]
    self.color_ids[ref] = Vec2T{UInt32}(color, id_val)
    push!(self.color_updates, ref)
end

function update_transform!(self::TriangleRenderer, ref::UInt32, transform)
    self.matrices[ref] = Mat4T{Float32}(transform)
end

function _triangle_renderer_buffer_array()
    attributes = [nothing,nothing,
    [VertexAttrib(false,4,GL_UNSIGNED_BYTE,GL_TRUE,0),
    VertexAttrib(true,1,GL_UNSIGNED_INT,GL_FALSE,sizeof(Cuint))]]
    return BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}(attributes)
end

function added_all!(self::TriangleRenderer)::Nothing
    if length(self.buffers) != length(self.coords)
        for i in (length(self.buffers)+1):length(self.coords)
            buffer = _triangle_renderer_buffer_array()
            upload!(buffer,1,self.coords[i],GL_DYNAMIC_STORAGE_BIT)
            N = length(self.coords[i])
            reserve!(buffer,2,N,0)
            reserve!(buffer,3,N,0)
            glClearNamedBufferSubData(id(buffer[3]),GL_RG32UI,0,N * sizeof(Vec2T{UInt32}), GL_RG_INTEGER, GL_UNSIGNED_INT, self.color_ids[i])
            push!(self.buffers, buffer)
            push!(self.update_normals,UInt32(i))
        end
    end
end

function update_coords!(self::TriangleRenderer,ref::UInt32,coords)::Nothing
    empty!(self.coords[ref])
    append!(self.coords[ref],(Vec4F(c[1],c[2],c[3],1.0f0) for c in coords))
    push!(self.update_normals,ref)
    return nothing
end

function update_matrix!(self::TriangleRenderer,ref::UInt32,matrix::Mat4T{Float32})::Nothing
    self.matrices[ref] = matrix
    return nothing
end

function sync_all!(self::TriangleRenderer)::Bool
    for i in self.update_normals
        buffer = self.buffers[i]
        if length(self.coords[i]) != length(buffer)
            upload!(buffer,1,self.coords[i],GL_DYNAMIC_STORAGE_BIT)
            N = length(self.coords[i])
            reserve!(buffer,2,N,0)
            reserve!(buffer,3,N,0)
            glClearNamedBufferSubData(id(buffer[3]),GL_RG32UI,0,N * sizeof(Vec2T{UInt32}), GL_RG_INTEGER, GL_UNSIGNED_INT, self.color_ids[i])
        else
            upload!(buffer,1,self.coords[i])
        end
    end
    for i in self.color_updates
        buffer = self.buffers[i]
        N = length(self.coords[i])
        if N > 0
            glClearNamedBufferSubData(id(buffer[3]),GL_RG32UI,0,N * sizeof(Vec2T{UInt32}), GL_RG_INTEGER, GL_UNSIGNED_INT, self.color_ids[i])
        end
    end
    return !isempty(self.update_normals) || !isempty(self.color_updates)
end

function pre_draw(self::TriangleRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.update_normals) return nothing end
    activate(self.shader_calc_normals)
    for i in self.update_normals
        if length(self.coords[i]) == 0 continue end
        bind_ssbo(self.buffers[i][1],0)
        bind_ssbo(self.buffers[i][2],1)
        glDispatchCompute(cld(length(self.coords[i]),64),1,1);
    end

    transforms = _TriangleTransform[_TriangleTransform(M) for M in self.matrices]
    if length(self.UBO) != length(transforms)
        upload!(self.UBO,transforms,GL_DYNAMIC_STORAGE_BIT)
    else
        upload!(self.UBO,transforms)
    end

    return nothing
end

function opaque(self::TriangleRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.coords) return nothing end
    if !isempty(self.update_normals) || !isempty(self.color_updates)
        println("\t", self.color_updates)
        glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT)
        empty!(self.update_normals)
        empty!(self.color_updates)
    end

    glDisable(GL_CULL_FACE)

    activate(self.shader_opaque)
    
    # shaderProgram = self.shader_opaque.loader.pipelines[self.shader_opaque.pipeline_handle]
    # println("shader: ", shaderProgram)
    # glUniform1i(4,rand((0,1)))
    # self.ubo_infinite[1] = rand((0,1)) == 1 ? true : false

    for i in 1:length(self.buffers)
        if !is_packed_opaque(self.color_ids[i][1]) || length(self.coords[i]) == 0 continue end
        bind_ubo(self.UBO, i, 0)
        glUniform1i(4,self.infinite_ids[i])
        draw(self.buffers[i],GL_TRIANGLES)
        # println(self.buffers[i])
    end
    println(self.color_ids)
    # println("buffers: ", length(self.buffers), ", coords: ", length(self.coords))
    # for i in 1:length(self.coords)
    #     println("\t[", i, "]: ", length(self.coords[i]))
    #     println(self.coords[i])
    # end

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent(self::TriangleRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.coords) return nothing end
    glDisable(GL_CULL_FACE)

    activate(self.shader_transparent)
    for i in 1:length(self.buffers)
        if is_packed_opaque(self.color_ids[i][1]) || length(self.coords[i]) == 0 continue end
        bind_ubo(self.UBO, i, 0)
        draw(self.buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end