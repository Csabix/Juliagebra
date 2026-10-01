struct _TriangleTransform
    M::Mat4T{Float32}
    MIT::Mat4T{Float32}
    IsInfinite::Int32
    _TriangleTransform(M::Mat4T{Float32},IsInfinite::Bool) = new(M,inv(transpose(M)),Int32(IsInfinite))
end

const GatherRequests = Dict{UInt32,Tuple{BufferBase{Vec4},Int}}

mutable struct TriangleRenderer <: Renderer
    shader_calc_normals::Pipeline
    shader_opaque::Pipeline
    shader_transparent::Pipeline
    shader_surface_gather::Pipeline

    UBO::RepeatBufferUBO{_TriangleTransform}
    buffers::Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}} # position normal color id

    matrices::Vector{Mat4T{Float32}}
    coords::Vector{Vector{Vec4F}}
    coords_lengths::Vector{Int}
    color_ids::Vector{Vec2T{UInt32}}
    infinite_ids::Vector{Bool}

    gather_coords::GatherRequests # handle => (tess buffer, grid width), Dict because new entries should invalidate old ones
    update_normals::Vector{UInt32}
    color_updates::Vector{UInt32}

    # cached separately from OpenGLData so that render stays independent from implicitApp
    max_wg_count::Tuple{GLint, GLint, GLint}
    max_shader_storage_block_size::GLint64

    function TriangleRenderer(loader::PipelineLoader)
        calc_normals = create_compute_pipeline!(loader,spv"renderers/triangle/triangle_normal.comp")
        opaque = create_graphics_pipeline!(loader;
            vert = spv"renderers/triangle/triangle.vert",
            frag = spv"renderers/triangle/triangle_opaque.frag")
        transparent = create_graphics_pipeline!(loader,
            vert = spv"renderers/triangle/triangle.vert",
            frag = spv"renderers/triangle/triangle_transparent.frag")
        surface_gather = create_compute_pipeline!(loader,spv"renderers/triangle/surface_gather.comp")

        max_wg_count, max_shader_storage_block_size = _get_compute_limits()

        new(calc_normals,opaque,transparent,surface_gather,
            RepeatBufferUBO{_TriangleTransform}(),
            Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}}(),
            Vector{Mat4T{Float32}}(),Vector{Vector{Vec4F}}(),Vector{Int}(),Vector{Vec2T{UInt32}}(),Vector{Bool}(),
            GatherRequests(),
            Vector{UInt32}(),
            Vector{UInt32}(),
            max_wg_count, max_shader_storage_block_size
        )
    end
end

function clear!(self::TriangleRenderer)::Nothing
    foreach(destroy!, self.buffers)

    self.buffers = Vector{BufferArray{Tuple{Buffer{Vec4F},Buffer{Vec4F},Buffer{Vec2T{UInt32}}}}}()
    self.matrices = Vector{Mat4T{Float32}}()
    self.coords = Vector{Vector{Vec4F}}()
    self.coords_lengths = Vector{Int}()
    self.color_ids = Vector{Vec2T{UInt32}}()
    self.gather_coords = GatherRequests()
    self.update_normals = Vector{UInt32}()
    self.color_updates = Vector{UInt32}()
    self.infinite_ids = Vector{Bool}()
    return nothing
end

function destroy!(self::TriangleRenderer)::Nothing
    foreach(destroy!, self.buffers)
end

function add!(self::TriangleRenderer,coords,matrix::Mat4T{Float32},color::UInt32,isInfinite::Bool,id::UInt32)::UInt32
    push!(self.coords, [Vec4F(c[1],c[2],c[3],1.0f0) for c in coords])
    push!(self.coords_lengths, length(coords))
    push!(self.matrices, matrix)
    push!(self.color_ids,UVec2(color,id))
    push!(self.infinite_ids,isInfinite)
    return UInt32(length(self.coords))
end

# for GPU-only surfaces that are gathered from a GPU buffer instead of having CPU coords data
function add!(self::TriangleRenderer,tess_buffer::BufferBase{Vec4},grid_width::Int,matrix::Mat4T{Float32},color::UInt32,id::UInt32)::UInt32
    @assert length(tess_buffer) % grid_width == 0 "Unexpected tessellation buffer size, or invalid grid width"
    grid_height = div(length(tess_buffer), grid_width)
    push!(self.coords, Vec4F[])
    push!(self.coords_lengths, _triangulated_size(grid_width,grid_height))
    push!(self.matrices, matrix)
    push!(self.color_ids,UVec2(color,id))
    push!(self.infinite_ids,false) # GPU tessellated surfaces can't be infinite
    ref = UInt32(length(self.coords))
    self.gather_coords[ref] = (tess_buffer, grid_width)
    return ref
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

function update_coords!(self::TriangleRenderer,ref::UInt32,coords)::Nothing
    empty!(self.coords[ref])
    append!(self.coords[ref],(Vec4F(c[1],c[2],c[3],1.0f0) for c in coords))
    self.coords_lengths[ref] = length(self.coords[ref])
    delete!(self.gather_coords,ref)
    push!(self.update_normals,ref)
    return nothing
end

# move to a GPU-only source
function update_coords!(self::TriangleRenderer,ref::UInt32,tess_buffer::BufferBase{Vec4},grid_width::Int)::Nothing
    self.coords[ref] = Vec4F[]
    @assert length(tess_buffer) % grid_width == 0 "Invalid buffer dimensions"
    self.coords_lengths[ref] = _triangulated_size(grid_width, div(length(tess_buffer), grid_width))
    self.gather_coords[ref] = (tess_buffer, grid_width)
    push!(self.update_normals,ref)
    return nothing
end

function update_matrix!(self::TriangleRenderer,ref::UInt32,matrix::Mat4T{Float32})::Nothing
    self.matrices[ref] = matrix
    return nothing
end

function pre_draw!(self::TriangleRenderer,cam::Camera,window::GLFWData)::Nothing
    if length(self.buffers) != length(self.coords)
        for i in (length(self.buffers)+1):length(self.coords)
            buffer = _triangle_renderer_buffer_array()
            N = self.coords_lengths[i]
            # upload isn't needed, since items in update_normals are uploaded in the next step anyway
            reserve!(buffer,1,N,GL_DYNAMIC_STORAGE_BIT)
            reserve!(buffer,2,N,0)
            reserve!(buffer,3,N,0)
            glClearNamedBufferSubData(id(buffer[3]),GL_RG32UI,0,N * sizeof(Vec2T{UInt32}), GL_RG_INTEGER, GL_UNSIGNED_INT, self.color_ids[i])
            push!(self.buffers, buffer)
            push!(self.update_normals,UInt32(i))
        end
    end

    for i in self.update_normals
        buffer = self.buffers[i]
        N = self.coords_lengths[i]
        has_gpu_src = isempty(self.coords[i]) && N > 0
        if N != length(buffer)
            if has_gpu_src
                reserve!(buffer,1,N,GL_DYNAMIC_STORAGE_BIT)
            else
                upload!(buffer,1,self.coords[i],GL_DYNAMIC_STORAGE_BIT)
            end
            reserve!(buffer,2,N,0)
            reserve!(buffer,3,N,0)
            glClearNamedBufferSubData(id(buffer[3]),GL_RG32UI,0,N * sizeof(Vec2T{UInt32}), GL_RG_INTEGER, GL_UNSIGNED_INT, self.color_ids[i])
        elseif !has_gpu_src
            upload!(buffer,1,self.coords[i])
        end
    end
    for i in self.color_updates
        buffer = self.buffers[i]
        N = self.coords_lengths[i]
        if N > 0
            glClearNamedBufferSubData(id(buffer[3]),GL_RG32UI,0,N * sizeof(Vec2T{UInt32}), GL_RG_INTEGER, GL_UNSIGNED_INT, self.color_ids[i])
        end
    end

    activate(self.shader_surface_gather)
    for (i, (tess_buffer, grid_width)) in self.gather_coords
        N = self.coords_lengths[i]
        N == 0 && continue
        _check_buffer_size(self,N)
        bind_ssbo(tess_buffer, 0)
        bind_ssbo(self.buffers[i][1], 1)
        glUniform(0, UInt32(N)) # vertex_count
        glUniform(1, UInt32(grid_width)) # grid_width
        glDispatchCompute(_wg_split(self,cld(N, 256))...)
    end
    if !isempty(self.gather_coords)
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)
        empty!(self.gather_coords)
    end
    
    if isempty(self.update_normals) return nothing end
    activate(self.shader_calc_normals)
    for i in self.update_normals
        N = self.coords_lengths[i]
        N == 0 && continue
        _check_buffer_size(self,N)
        bind_ssbo(self.buffers[i][1],0)
        bind_ssbo(self.buffers[i][2],1)
        @assert N % 3 == 0 "Unexpected coords buffer size"
        glDispatchCompute(_wg_split(self,cld(div(N,3),64))...); # normal shader writes 3 vertices per invocation
    end

    transforms = _TriangleTransform[_TriangleTransform(M,is_infinite) for (M,is_infinite) in zip(self.matrices,self.infinite_ids)]
    if length(self.UBO) != length(transforms)
        upload!(self.UBO,transforms,GL_DYNAMIC_STORAGE_BIT)
    else
        upload!(self.UBO,transforms)
    end

    return nothing
end

function draw_opaque!(self::TriangleRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.coords) return nothing end
    if !isempty(self.update_normals) || !isempty(self.color_updates)
        glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT)
        empty!(self.update_normals)
        empty!(self.color_updates)
    end

    glDisable(GL_CULL_FACE)

    activate(self.shader_opaque)
    for i in 1:length(self.buffers)
        if !is_packed_opaque(self.color_ids[i][1]) || self.coords_lengths[i] == 0 continue end
        bind_ubo(self.UBO, i, 0)
        draw(self.buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function draw_transparent!(self::TriangleRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.coords) return nothing end
    glDisable(GL_CULL_FACE)

    activate(self.shader_transparent)
    for i in 1:length(self.buffers)
        if is_packed_opaque(self.color_ids[i][1]) || self.coords_lengths[i] == 0 continue end
        bind_ubo(self.UBO, i, 0)
        draw(self.buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

_triangulated_size(grid_width::Integer,grid_height::Integer) = 6 * (grid_width - 1) * (grid_height - 1)

function _check_buffer_size(self::TriangleRenderer,coords_length::Int)::Nothing
    size = coords_length * sizeof(Vec4F)
    max_size = self.max_shader_storage_block_size
    max_size < size && error("Buffer size exceeds the size limit for shader storage blocks on this system (size: $size, maximum: $max_size)")
    return nothing
end

function _wg_split(self::TriangleRenderer,wg_count::Integer)::Tuple{GLuint,GLuint,GLuint}
    wg_count_u = convert(GLuint, wg_count)
    y = cld(wg_count_u, self.max_wg_count[1])
    x = cld(wg_count_u, y)
    y > self.max_wg_count[2] && error("The current dispatch grid cannot fit the required number of workgroups ($wg_count_u) on this system")
    return (x, y, one(GLuint))
end
