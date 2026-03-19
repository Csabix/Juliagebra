# GREEN Thread

const CURVE_SOLID::UInt8    = 1
const CURVE_DASHED::UInt8   = 2
const CURVE_DOTTED::UInt8   = 3
const CURVE_WAVE::UInt8     = 4
const CURVE_DASH_DOT::UInt8 = 5
const CURVE_ARROW::UInt8    = 6
const _CURVE_COUNT::UInt8   = 6

export CURVE_SOLID, CURVE_DASHED, CURVE_DOTTED, 
        CURVE_WAVE, CURVE_DASH_DOT, CURVE_ARROW

mutable struct GlobalLineRenderer
    emptyVAO::VertexArray

    shader_predraw::ShaderProgram
    shaders_opaque::Vector{ShaderProgram}
    shaders_behind_opaque::Vector{ShaderProgram}
    #shaders_transparent::Vector{ShaderProgram} Maybe

    # Dynamic
    types::Vector{UInt8}
    draw_ranges::Vector{Tuple{Int,Int}}

    distance_buffers_in::Vector{Buffer{Float32}}
    color_reversed_buffers_in::Vector{Buffer{UInt32}} # RGB + if reverse the pattern
    position_width_buffers_in::Vector{Buffer{Vec4F}}

    position_distance_buffer_out::Buffer{Vec4F}
    color_buffer_out::Buffer{UVec2}
    light_buffer_out::Buffer{Vec4F}
    sdf_buffer_out::Buffer{Vec4F}

    # GREEN Thread
    function SegmentSequenceRenderer(context::OpenGLData)
        renderer = Renderer{SegmentSequenceDependent}(context)

        shader_predraw = ShaderProgram(["curve/segseq_vertex.comp"],["VP","WH","Eye","lightDirCam","lightDirSide","offset"])

        types = ["solid","dashed","dotted","wave","dash_dot","arrow"]

        shaders_id = Vector{ShaderProgram}()
        for type in types push!(shaders_id,ShaderProgram(["curve/id/curve.vert","curve/id/curve_$type.frag"])) end

        shaders_opaque = Vector{ShaderProgram}()
        for type in types push!(shaders_opaque,ShaderProgram(["curve/opaque/curve.vert","curve/opaque/curve_$type.frag"])) end

        shaders_behind_opaque = Vector{ShaderProgram}()
        for type in types push!(shaders_behind_opaque,ShaderProgram(["curve/behind_opaque/curve.vert","curve/behind_opaque/curve_$type.frag"])) end

        shaders_transparent = Vector{ShaderProgram}()
        for type in types push!(shaders_transparent,ShaderProgram(["curve/opaque/curve.vert","curve/transparent/curve_$type.frag"])) end

        coords = Vector{Vector{Vec3F}}()
        widths = Vector{Float32}()
        colors = Vector{Vector{Float32}}()
        types = Vector{UInt8}()
        
        new(renderer,VertexArray(),
            shader_predraw,shaders_id,shaders_opaque,shaders_behind_opaque,shaders_transparent,
            Vector{Int32}(),Vector{Tuple{Int, Int}}(undef, _CURVE_COUNT),
            coords,widths,colors,types,
            Vector{Buffer{Float32}}(),Vector{Buffer{Float32}}(),Vector{Buffer{Vec4F}}(),
            Buffer{Vec4F}(),Buffer{UVec2}(),Buffer{Vec4F}(),Buffer{Vec4F}())
    end
end

_line_renderer::Union{GlobalLineRenderer,Nothing} = nothing
function get_renderer_line()::GlobalLineRenderer
    global _line_renderer
    @assert !isnothing(_line_renderer)
    return _line_renderer::GlobalLineRenderer
end

function pack_color_reversed(color::UInt32, reversed::Bool)::UInt32
    return (UInt32(reversed ? 255 : 0) << 24) | color
end

function add_dynamic!(::Val{:Line},coords,colors,id,width,reversed,type)::UInt32
    renderer = get_renderer_line()
    N = length(coords)

    # Distance
    distance_buffer = MappedBuffer{Float32}()
    reserve!(distance_buffer,n,0)
    push!(renderer.distance_buffers_in,distance_buffer)

    # Color
    color_buffer = MappedBuffer{UInt32}()
    reserve!(color_buffer,n,0)
    copyto!(color_buffer,take((pack_color_reversed(color,reversed) for color in colors),N))
    push!(renderer.color_type_buffers_in,color_buffer)

    # Position Width
    position_width_buffer = MappedBuffer{Vec4F}()
    reserve!(position_width_buffer,N,0)
    copyto!(color_buffer,(Vec4F(coord..., width) for coord in coords))
    push!(renderer.position_width_buffers_in,position_width_buffer)

    push!(renderer.types,type)
end

function added_all!(::Val{:Line})
    renderer = get_renderer_line()
    
    # Dynamic
    total_coord = sum(length,renderer._distance_buffers_in)

    renderer.position_distance_buffer_out = Buffer{Vec4F}()
    reserve!(renderer.position_distance_buffer_out,5*total_coord,0)

    renderer.color_buffer_out = Buffer{Vec2T{UInt32}}()
    reserve!(renderer.color_buffer_out,total_coord,0)

    renderer.light_buffer_out = Buffer{Vec4F}()
    reserve!(renderer.light_buffer_out,total_coord,0)

    renderer.sdf_buffer_out = Buffer{Vec4F}()
    reserve!(renderer.sdf_buffer_out,5*total_coord,0)
end