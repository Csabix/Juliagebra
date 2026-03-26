using Base.Iterators: cycle, take, map as imap

function packUnorm4x8(v::Vec3T{T})::UInt32 where T <: AbstractFloat
    return  packUnorm4x8(Vec4F(Float32(v[1]),Float32(v[2]),Float32(v[3]),Float32(1.0)))
end
function packUnorm4x8(v::Vec4T{T})::UInt32 where T <: AbstractFloat
    c1 = UInt32(round(clamp(v[1], 0.0, 1.0) * 255.0))
    c2 = UInt32(round(clamp(v[2], 0.0, 1.0) * 255.0))
    c3 = UInt32(round(clamp(v[3], 0.0, 1.0) * 255.0))
    c4 = UInt32(round(clamp(v[4], 0.0, 1.0) * 255.0))
    return (c4 << 24) | (c3 << 16) | (c2 << 8) | c1
end

include("point_renderer.jl")
include("line_renderer.jl")

init!(s::Symbol)::Nothing = init!(Val(s))
function init_renderers!()::Nothing
    init!(:Point)
    init!(:Line)
end

destroy!(s::Symbol)::Nothing = destroy!(Val(s))
function destroy_renderers!()::Nothing
    destroy!(:Point)
    destroy!(:Line)
end

added_all!(s::Symbol)::Nothing = added_all!(Val(s))
function added_all!()::Nothing
    added_all!(:Point)
    added_all!(:Line)
end

sync!(s::Symbol)::Nothing = sync!(Val(s))
function sync_all!()::Nothing
    sync!(:Point)
    sync!(:Line)
end

pre_draw(s::Symbol,cam::Camera,shrd::SharedData) = pre_draw(Val(s),cam,shrd)
function pre_draw!(cam::Camera,shrd::SharedData)::Nothing
    pre_draw(:Line,cam,shrd)
end

opaque(s::Symbol,cam::Camera,shrd::SharedData) = opaque(Val(s),cam,shrd)
function opaque!(fbo::FrameBuffer,cam::Camera,shrd::SharedData)::Nothing
    activate(fbo)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
    clear_value = SVector{4, Int32}(0, 0, 0, 0)
    glClearBufferiv(GL_COLOR, 1, clear_value)

    glStencilFunc(GL_ALWAYS, 1, 0xFF);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)

    opaque(:Point,cam,shrd)
    opaque(:Line,cam,shrd)

    glEnable(GL_STENCIL_TEST)

    glDisable(GL_STENCIL_TEST)
end

function behind_opaque!(cam::Camera,shrd::SharedData)::Nothing
    
end

function transparent!(fbo::FrameBuffer,buffer::Buffer{UVec2},cam::Camera,shrd::SharedData)::Nothing
    glDepthMask(GL_FALSE)
    glEnable(GL_BLEND)
    glDisable(GL_CULL_FACE)
    glBlendFunci(0, GL_ONE, GL_ONE)
    glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_COLOR)
    glBlendEquation(GL_FUNC_ADD)

    activate(fbo)
    glClearBufferfv(GL_COLOR, 0, [0.0f0, 0.0f0, 0.0f0, 0.0f0])
    glClearBufferfv(GL_COLOR, 1, [1.0f0, 1.0f0, 1.0f0, 1.0f0])

    bind_ssbo(buffer,0)

    # draws
    
    glEnable(GL_CULL_FACE)
    glDepthMask(GL_TRUE)
    glDisable(GL_BLEND)
end