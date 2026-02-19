# ? ---------------------------------
# ! SegmentSequencePlan
# ? ---------------------------------

mutable struct SegmentSequencePlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _colors::Vector{Vec3F}
    _break_every::Int32
    _type::UInt8
    _reversed::UInt8
    _width::Float32
    
    function SegmentSequencePlan(callback::Function, plans::Vector{T},
                                 color::Tuple{Real,Real,Real},break_every::Real,
                                 type::UInt8,reversed::UInt8,width::Real) where {T<:PlanDNA}
        
        SegmentSequencePlan(callback,plans,[color],break_every,type,reversed,width)
    end

    function SegmentSequencePlan(callback::Function,plans::Vector{T},
                                 color::Vector{U},break_every::Real,
                                 type::UInt8,reversed::UInt8,width::Real) where {T<:PlanDNA, U<:Tuple{Real,Real,Real}}
        
        colors = [Vec3F(c[1],c[2],c[3]) for c in color]
        new(RenderedPlan(callback,plans),colors,break_every,type,reversed,width)
    end
end

_RenderedPlan_(self::SegmentSequencePlan)::RenderedPlan = return self._plan
Base.string(self::SegmentSequencePlan)::String = return "Segment sequence"


# ? ---------------------------------
# ! SegmentSequenceDependent
# ? ---------------------------------

mutable struct SegmentSequenceDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _colors::Vector{Vec3F}
    _break_every::Int32
    _width::Float32
    _type::UInt8
    _reversed::UInt8

    _values::Vector{Vec3D}

    function SegmentSequenceDependent(plan::SegmentSequencePlan)
        a = RenderedDependent(plan)
        colors = plan._colors
        break_every = plan._break_every
        width = plan._width
        type = plan._type
        reversed = plan._reversed
        values = Vector{Vec3F}()

        new(a,colors,break_every,width,type,reversed,values)
    end
end

# ! Must have
function Plan2Dependent(plan::SegmentSequencePlan)::SegmentSequenceDependent
    return SegmentSequenceDependent(plan)
end

Base.string(self::SegmentSequenceDependent)::String =  return "Segment sequence: $(length(self._values))"
_RenderedDependent_(self::SegmentSequenceDependent)::RenderedDependent = return self._renderedDependent

function onNodeEval(self::SegmentSequenceDependent)
    evalCallbackDp(self)
end

function insert_nans(self::SegmentSequenceDependent,data::Vector{Vec3D})
    N = self._break_every
    len = length(data)
    if len < 2
        return [Vec3DNan,Vec3DNan]
    end

    add_front = !any(isnan,data[1])
    add_back = !any(isnan,data[end])

    if N < 2
        result = Vector{Vec3D}()
        add_front && push!(result, Vec3DNan)
        append!(result, data)
        add_back && push!(result, Vec3DNan)
        return result
    end

    num_interior_nans = div(len - 1, N)
    
    total_size = len + num_interior_nans + (add_front ? 1 : 0) + (add_back ? 1 : 0)
    result = Vector{Vec3D}(undef, total_size)
    
    curr = 1
    if add_front
        result[curr] = Vec3DNan
        curr += 1
    end

    for i in 1:len
        result[curr] = data[i]
        curr += 1
        if i % N == 0 && i != len
            result[curr] = Vec3DNan
            curr += 1
        end
    end

    if add_back
        result[curr] = Vec3DNan
    end

    return result
end

evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vec3D})  = self._values = insert_nans(self,coords)
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vec3F})  = self._values = insert_nans(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Tuple})  = self._values = insert_nans(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vector}) = self._values = insert_nans(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::SegmentSequenceDependent,::Nothing) = self.values = [Vec3DNan,Vec3DNan]

struct PSegmentsOfSegmentSequence <: PrimitivesOf{PSegment}
    _segseq::SegmentSequenceDependent
end
PrimitivesOf(self::SegmentSequenceDependent) = return PSegmentsOfSegmentSequence(self)

function Base.length(self::PSegmentsOfSegmentSequence)
    len = 0
    values = self._segseq._values
    for i in 1:length(values)-1
        if !(any(isnan,values[i]) || any(isnan,values[i+1]))
            len += 1
        end
    end
    return len
end

# SLOOW O(N)
function Base.getindex(self::PSegmentsOfSegmentSequence, index::Integer)::Union{Nothing, PSegment}
    if index < 1 return nothing end

    values = self._segseq._values
    n = length(values)
    i = 1

    while i < n
        if !(any(isnan,values[i]) || any(isnan,values[i+1]))
            index -= 1
            if index == 0 break end
        end
        i += 1
    end

    if index == 0
        return PSegment(values[i], values[i + 1])
    else
        return nothing
    end
end

function Base.iterate(self::PSegmentsOfSegmentSequence, index::Integer = 1)
    if index < 1 return nothing end

    values = self._segseq._values
    n = length(values)

    while index < n && (any(isnan,values[index]) || any(isnan,values[index + 1]))
        index += 1
    end

    if index == n return nothing
    else return (PSegment(values[index], values[index + 1]),index + 1) end
end

# ? ---------------------------------
# ! SegmentSequenceRenderer
# ? ---------------------------------

mutable struct SegmentSequenceRenderer <: RendererDNA{SegmentSequenceDependent}
    _renderer::Renderer{SegmentSequenceDependent}

    _shader_predraw::ShaderProgram
    _shaders_id::Vector{ShaderProgram}
    _shaders_opaque::Vector{ShaderProgram}
    _shaders_behind_opaque::Vector{ShaderProgram}
    _shaders_transparent::Vector{ShaderProgram}

    _update_me::Vector{Int32}
    _draw_ranges::Vector{Tuple{Int,Int}}

    _coords::Vector{Vector{Vec3F}}
    _widths::Vector{Float32}
    _colors::Vector{Vector{Float32}}
    _types::Vector{UInt8}

    _distance_buffers_in::Vector{StaticBuffer}
    _color_type_buffers_in::Vector{StaticBuffer}
    _position_width_buffers_in::Vector{StaticBuffer}

    _position_distance_buffer_out::StaticBuffer
    _color_buffer_out::StaticBuffer
    _light_buffer_out::StaticBuffer
    _sdf_buffer_out::StaticBuffer

    function SegmentSequenceRenderer(context::OpenGLData)
        renderer = Renderer{SegmentSequenceDependent}(context)

        shader_predraw = ShaderProgram(sp("curve/segseq_vertex.comp"),["VP","WH","Eye","lightDirCam","lightDirSide","offset"])

        types = ["solid","dashed","dotted","wave","dash_dot","arrow"]

        shaders_id = Vector{ShaderProgram}()
        for type in types push!(shaders_id,ShaderProgram(sp("curve/id/curve.vert"),sp("curve/id/curve_$type.frag"))) end

        shaders_opaque = Vector{ShaderProgram}()
        for type in types push!(shaders_opaque,ShaderProgram(sp("curve/opaque/curve.vert"),sp("curve/opaque/curve_$type.frag"))) end

        shaders_behind_opaque = Vector{ShaderProgram}()
        for type in types push!(shaders_behind_opaque,ShaderProgram(sp("curve/behind_opaque/curve.vert"),sp("curve/behind_opaque/curve_$type.frag"))) end

        shaders_transparent = Vector{ShaderProgram}()
        for type in types push!(shaders_transparent,ShaderProgram(sp("curve/opaque/curve.vert"),sp("curve/transparent/curve_$type.frag"))) end

        coords = Vector{Vector{Vec3F}}()
        widths = Vector{Float32}()
        colors = Vector{Vector{Float32}}()
        types = Vector{UInt8}()
        
        new(renderer,
            shader_predraw,shaders_id,shaders_opaque,shaders_behind_opaque,shaders_transparent,
            Vector{Int32}(),Vector{Tuple{Int, Int}}(undef, _CURVE_COUNT),
            coords,widths,colors,types,
            Vector{StaticBuffer}(),Vector{StaticBuffer}(),Vector{StaticBuffer}(),
            StaticBuffer(),StaticBuffer(),StaticBuffer(),StaticBuffer())
    end
end

_Renderer_(self::SegmentSequenceRenderer) = return self._renderer
Base.string(self::SegmentSequenceRenderer) = return "SegmentSequenceRenderer[$(length(self._coords))]"

function added!(self::SegmentSequenceRenderer,segseq::SegmentSequenceDependent)
    onNodeEval(segseq)
    push!(self._coords,segseq._values)
    packed_colors = [pack_color(color,segseq._reversed != 0x0) for color in segseq._colors]
    push!(self._colors,packed_colors)
    push!(self._widths,segseq._width)
    push!(self._types,segseq._type)
end

setRenderedID!(renderer::SegmentSequenceRenderer,dependent::SegmentSequenceDependent,id) = return nothing

_preallocated_vec(T, len) = sizehint!(Vector{T}(), len)

function addedAll!(self::SegmentSequenceRenderer)
    upload_colors = _preallocated_vec.(Float32, length.(self._coords))
    upload_position_widths = _preallocated_vec.(Vec4F, length.(self._coords))

    Threads.@threads for i in 1:length(self._coords)
        len = length(self._coords[i])
        # Color
        colors = upload_colors[i]
        packed_colors = self._colors[i]
        color_count = length(packed_colors)
        current_color = 1
        push!(colors, 0x0000000)
        for _ in 1:(len-2)
            push!(colors, packed_colors[current_color])
            current_color = mod1(current_color + 1, color_count)
        end
        push!(colors, 0x0000000)
        # Position Width
        position_widths = upload_position_widths[i]
        width = self._widths[i]
        coords = self._coords[i]
        for coord in coords
            push!(position_widths,Vec4F(coord...,width))
        end
    end

    for i in 1:length(self._coords)
        # Distance
        push!(self._distance_buffers_in,create(StaticBuffer(),length(self._coords[i])*sizeof(GLfloat),GL_DYNAMIC_STORAGE_BIT))
        # Color
        push!(self._color_type_buffers_in,create(StaticBuffer(),upload_colors[i],UInt32(0)))
        # Position Width
        push!(self._position_width_buffers_in,create(StaticBuffer(),upload_position_widths[i],GL_DYNAMIC_STORAGE_BIT))
    end

    total_coord = sum(length,self._coords)
    self._position_distance_buffer_out = create(self._position_distance_buffer_out, 5 * total_coord*4*sizeof(GLfloat), UInt32(0))
    self._color_buffer_out = create(self._color_buffer_out, total_coord*2*sizeof(GLuint), UInt32(0))
    self._light_buffer_out = create(self._light_buffer_out, total_coord*4*sizeof(GLfloat), UInt32(0))
    self._sdf_buffer_out = create(self._sdf_buffer_out, 5 * total_coord*4*sizeof(GLfloat), UInt32(0))
end

# ! Must have
function sync!(self::SegmentSequenceRenderer,segseq::SegmentSequenceDependent)
    index = getObserverID(segseq)
    size_change = length(self._coords[index]) != length(segseq._values)
    self._coords[index] = segseq._values
    push!(self._update_me,size_change ? -index : index)
end

# ! Must have
function syncAll!(self::SegmentSequenceRenderer)
    upload_colors = Vector{Union{Nothing,Vector{Float32}}}(nothing, length(self._update_me))
    upload_position_widths = Vector{Union{Nothing,Vector{Vec4F}}}(nothing, length(self._update_me))

    Threads.@threads for i in 1:length(self._update_me)
        index = abs(self._update_me[i])
        coords = self._coords[index]
        len = length(coords)

        # Position Width
        position_widths = _preallocated_vec(Vec4F,len)
        upload_position_widths[i] = position_widths
        width = self._widths[index]
        for coord in coords
            push!(position_widths,Vec4F(coord...,width))
        end

        if self._update_me[i] < 0
            # Color
            colors = _preallocated_vec(Float32,len)
            upload_colors[i] = colors
            packed_colors = self._colors[index]
            current_color = 1
            color_count = length(packed_colors)
            push!(colors, 0x0000000)
            for _ in 1:(len-2)
                push!(colors, packed_colors[current_color])
                current_color = mod1(current_color + 1, color_count)
            end
            push!(colors, 0x0000000)
        end
    end

    for i in 1:length(self._update_me)
        index = abs(self._update_me[i])
        position_widths = upload_position_widths[i]
        if self._update_me[i] < 0
            # Distance
            self._distance_buffers_in[index] = create(self._distance_buffers_in[index],length(position_widths)*sizeof(GLfloat),GL_DYNAMIC_STORAGE_BIT)
            # Color
            self._color_type_buffers_in[index] = create(self._color_type_buffers_in[index],upload_colors[i],UInt32(0))
            # Position Width
            self._position_width_buffers_in[index] = create(self._position_width_buffers_in[index],position_widths,GL_DYNAMIC_STORAGE_BIT)
        else
            upload!(self._position_width_buffers_in[index],position_widths)
        end
    end

    if any(x -> x < 0, self._update_me)
        total_coord = sum(length,self._coords)
        self._position_distance_buffer_out = create(self._position_distance_buffer_out, 5 * total_coord*4*sizeof(GLfloat), UInt32(0) )
        self._color_buffer_out = create(self._color_buffer_out, total_coord*2*sizeof(GLuint),  UInt32(0))
        self._light_buffer_out = create(self._light_buffer_out, total_coord*4*sizeof(GLfloat), UInt32(0))
        self._sdf_buffer_out = create(self._sdf_buffer_out, 5 * total_coord*4*sizeof(GLfloat), UInt32(0))
    end

    empty!(self._update_me)
end

@inbounds function _calc_distances!(self::SegmentSequenceRenderer,vp::Mat4,wh::Vec2F)
    @time_cpu_begin Dependent Segmnet_Sequence Distances
    upload_distances = [Vector{Float32}(undef,length(coords)) for coords in self._coords]
    Threads.@threads for index in 1:length(self._coords)
        coords = self._coords[index]
        distances = upload_distances[index]
        distance_sum = 0.0f0
        for i in 2:length(coords)-2
            a = vp * Vec4F(Vec3F(coords[i]), 1.0f0)
            b = vp * Vec4F(Vec3F(coords[i+1]), 1.0f0)
            if a.z + a.w < 0.0 && b.z + b.w < 0.0f0 continue end
            t0 = a.z + a.w;
            t1 = b.z + b.w;
            if t0 < 0.0
                tt = t0 / (t0 - t1)
                a = @. a * (1 - tt) + b * tt
            elseif t1 < 0.0
                tt = t1 / (t1 - t0)
                b = @. b * (1 - tt) + a * tt
            end
            a2 = Vec2F(a.x,a.y) / a.w
            a2 = a2 .* 0.5f0 .+ 0.5f0
            a2 = a2 .* wh

            b2 = Vec2F(b.x,b.y) / b.w
            b2 = b2 .* 0.5f0 .+ 0.5f0
            b2 = b2 .* wh

            distances[i] = distance_sum
            distance_sum = !isnan(norm(a2 - b2)) ? distance_sum + norm(a2 - b2) : 0
        end
        distances[length(coords)-1] = distance_sum
    end

    for (i,dist) in enumerate(upload_distances)
        upload!(self._distance_buffers_in[i],dist)
    end
    @time_cpu_end Dependent Segmnet_Sequence Distances
end

function pre_draw!(self::SegmentSequenceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    _calc_distances!(self,vp,Vec2F(shrd._width,shrd._height))

    (cam_light, side_light) = get_lights(cam)
    activate(self._shader_predraw)
    setUniform!(self._shader_predraw,"VP",vp)
    setUniform!(self._shader_predraw,"WH",Vec2F(shrd._width, shrd._height))
    setUniform!(self._shader_predraw,"Eye",cam._eye)
    setUniform!(self._shader_predraw,"lightDirCam", cam_light)
    setUniform!(self._shader_predraw,"lightDirSide",side_light)
    bind_ssbo(self._position_distance_buffer_out,3)
    bind_ssbo(self._color_buffer_out,4)
    bind_ssbo(self._light_buffer_out,5)
    bind_ssbo(self._sdf_buffer_out,6)

    offset = UInt32(0)
    @time_gpu_begin Dependent Segmnet_Sequence PRE_DRAW_PASS
    for i in 1:_CURVE_COUNT
        for j in 1:length(self._coords)
            if self._types[j] != i continue end
            bind_ssbo(self._distance_buffers_in[j],0)
            bind_ssbo(self._color_type_buffers_in[j],1)
            bind_ssbo(self._position_width_buffers_in[j],2)
            setUniform!(self._shader_predraw,"offset",offset)
            glDispatchCompute(cld(length(self._coords[j]),32),1,1);
            offset += UInt32(length(self._coords[j]))
        end
    end
    @time_gpu_end Dependent Segmnet_Sequence PRE_DRAW_PASS
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)

    counts = zeros(Int, _CURVE_COUNT)
    for i in 1:length(self._coords)
        counts[self._types[i]] += length(self._coords[i])
    end

    current_idx = 1
    for i in 1:_CURVE_COUNT
        len = counts[i]
        if len > 0
            self._draw_ranges[i] = (current_idx, current_idx + len - 1)
        else
            self._draw_ranges[i] = (typemax(Int),typemin(Int))
        end
        current_idx += len
    end
end

function id_pass!(self::SegmentSequenceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._sdf_buffer_out,1)

    baseInstance = 0
    @time_gpu_begin Dependent Segmnet_Sequence ID_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._draw_ranges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_id[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Segmnet_Sequence ID_PASS
end

function opaque_pass!(self::SegmentSequenceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._color_buffer_out,1)
    bind_ssbo(self._light_buffer_out,2)
    bind_ssbo(self._sdf_buffer_out,3)

    baseInstance = 0
    glEnable(GL_BLEND)
    @time_gpu_begin Dependent Segmnet_Sequence OPAQUE_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._draw_ranges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Segmnet_Sequence OPAQUE_PASS
    glDisable(GL_BLEND)
end

is_occluder(self::SegmentSequenceRenderer)::Bool = false

function behind_opaque_pass!(self::SegmentSequenceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._color_buffer_out,1)
    bind_ssbo(self._sdf_buffer_out,2)

    baseInstance = 0
    @time_gpu_begin Dependent Segmnet_Sequence BEHIND_OPAQUE_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._draw_ranges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_behind_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Segmnet_Sequence BEHIND_OPAQUE_PASS
end

function transparent_pass!(self::SegmentSequenceRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._color_buffer_out,1)
    bind_ssbo(self._light_buffer_out,2)
    bind_ssbo(self._sdf_buffer_out,3)

    baseInstance = 0
    glEnable(GL_BLEND)
    @time_gpu_begin Dependent Segmnet_Sequence TRANSPARENT_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._draw_ranges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_transparent[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Segmnet_Sequence TRANSPARENT_PASS
end

function destroy!(self::SegmentSequenceRenderer)
    destroy!(self._shader_predraw)
    destroy!.(self._shaders_id)
    destroy!.(self._shaders_opaque)
    destroy!.(self._shaders_behind_opaque)
    destroy!.(self._shaders_transparent)

    destroy!.(self._distance_buffers_in)
    destroy!.(self._color_type_buffers_in)
    destroy!.(self._position_width_buffers_in)

    destroy!(self._position_distance_buffer_out)
    destroy!(self._color_buffer_out)
    destroy!(self._light_buffer_out)
    destroy!(self._sdf_buffer_out)
end

function Plan2Observer(self::OpenGLData,plan::SegmentSequencePlan)
    return SingleRendererTactic(self,_SEGMENT_SEQUENCE_RENDERER,SegmentSequenceRenderer)::SegmentSequenceRenderer
end