struct TriangleRenderer
    shader_calc_normals::ShaderProgram
    shader_opaque::ShaderProgram
    shader_transparent::ShaderProgram

    buffers::Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}} # position normal color id

    matrices::Vector{Mat4T{Float32}}
    coords::Vector{Vector{Vec4F}}
    color_ids::Vector{Vec2T{UInt32}}

    update_normals::Vector{UInt32}
    color_updates::Vector{UInt32}

    function TriangleRenderer()
        calc_normals = ShaderProgram(["renderers/triangle/triangle_normal.comp"])
        opaque = ShaderProgram(["renderers/triangle/triangle.vert","renderers/triangle/triangle.frag"],["M","MIT"])
        transparent = ShaderProgram(["renderers/triangle/triangle.vert",("renderers/triangle/triangle.frag",["TRANSPARENT"])],["M","MIT"])

        new(calc_normals,opaque,transparent,
            Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}}(),
            Vector{Mat4T{Float32}}(),Vector{Vector{Vec3F}}(),Vector{Vec2T{UInt32}}(),
            Vector{UInt32}(),
            Vector{UInt32}()
        )
    end
end

function destroy!(self::TriangleRenderer)::Nothing
    destroy!(self.shader_calc_normals)
    destroy!(self.shader_opaque)
    destroy!(self.shader_transparent)
    foreach(destroy!, self.buffers)
end

function add!(self::TriangleRenderer,coords,matrix::Mat4T{Float32},color::UInt32,id::UInt32)::UInt32
    push!(self.coords, collect((Vec4F(c[1],c[2],c[3],1.0f0) for c in coords)))
    push!(self.matrices, matrix)
    push!(self.color_ids,UVec2(color,id))
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

function sync_all!(self::TriangleRenderer)::Nothing
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
    return nothing
end

function pre_draw(self::TriangleRenderer,cam::Camera,shrd::SharedData)::Nothing
    if isempty(self.update_normals) return nothing end
    activate(self.shader_calc_normals)
    for i in self.update_normals
        if length(self.coords[i]) == 0 continue end
        bind_ssbo(self.buffers[i][1],0)
        bind_ssbo(self.buffers[i][2],1)
        glDispatchCompute(cld(length(self.coords[i]),64),1,1);
    end
    return nothing
end

function opaque(self::TriangleRenderer,cam::Camera,shrd::SharedData)::Nothing
    if isempty(self.coords) return nothing end
    if !isempty(self.update_normals) || !isempty(self.color_updates)
        glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT)
        empty!(self.update_normals)
        empty!(self.color_updates)
    end

    glDisable(GL_CULL_FACE)

    activate(self.shader_opaque)
    for i in 1:length(self.buffers)
        if !is_packed_opaque(self.color_ids[i][1]) || length(self.coords[i]) == 0 continue end
        uniform(self.shader_opaque,"M",self.matrices[i])
        uniform(self.shader_opaque,"MIT",inv(transpose(self.matrices[i])))
        draw(self.buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent(self::TriangleRenderer,cam::Camera,shrd::SharedData)::Nothing
    if isempty(self.coords) return nothing end
    glDisable(GL_CULL_FACE)

    activate(self.shader_transparent)
    for i in 1:length(self.buffers)
        if is_packed_opaque(self.color_ids[i][1]) || length(self.coords[i]) == 0 continue end
        uniform(self.shader_transparent,"M",self.matrices[i])
        uniform(self.shader_transparent,"MIT",inv(transpose(self.matrices[i])))
        draw(self.buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end