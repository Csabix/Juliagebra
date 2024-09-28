# include("events.jl")
# include("gl.jl")
# include("Cameras.jl")

module App

using ModernGL, LinearAlgebra, GeometryBasics, ImGuiGLFWBackend.LibGLFW

using ..Events
using ..GL
using ..Cameras

struct PointVertex
    pos :: Vec3f       # position of point
    rad :: Float32     # size of point
    col :: Vec4{UInt8} # color to apply
    PointVertex(pos,size=5f0,col=Vec4{UInt8}(255)) = new(convert(Vec3f,pos),convert(Float32,size),convert(Vec4{UInt8},col));
end
struct LineVertex
    pos :: Vec3f       # position of point
    len :: Float32     # accumulative length
    dir :: Vec3f       # direction of line from this vertex
    col :: Vec4{UInt8} # color to apply
    LineVertex(pos,dir,len=5f0,col=Vec4{UInt8}(255)) = new(convert(Vec3f,pos),convert(Float32,len),convert(Vec3f,dir),convert(Vec4{UInt8},col));
end
const PointSyncedBuffer = SyncedBuffer{PointVertex}
const LineSyncedBuffer  = SyncedBuffer{LineVertex}

const timeZero :: Float64 = time()
ticks()::Float32 = Float32(timeZero-time())

@kwdef mutable struct AppState
    points :: PointSyncedBuffer = PointSyncedBuffer()
    lines  :: LineSyncedBuffer  = LineSyncedBuffer()
    shaders    :: NamedTuple  = NamedTuple()
    textargets :: NamedTuple  = NamedTuple()
    framebuffer:: Framebuffer = Framebuffer()
    camera     :: Camera      = Camera()
end

export AppState

######################
#    Init & Clean    #
######################

function init!(a::AppState)::Nothing
    glClearColor(0.45, 0.55, 0.60, 1.00)
    glEnable(GL_PROGRAM_POINT_SIZE) # glPointSize(10)
    glLineWidth(10.f0)
    recompile!(a)
    resize!(a,640,480)
    pointdata = vec([PointVertex([x y z],25,[100x+120,100y+120,100z+120,255] .|> trunc .|> UInt8) for x=-1:0.2:1,y=-1:0.2:1,z=-1:0.2:1])
    upload!(a.points,pointdata)
    dirs = [[Vec3f(0)]; diff(vec([pd.pos for pd in pointdata]))]
    lengths  = norm.(dirs)
    linedata = [LineVertex(pd.pos,v,l,pd.col) for (pd,v,l) in zip(pointdata,dirs./lengths,cumsum(lengths))]
    upload!(a.lines, linedata)
    return nothing
end

function clean!(a::AppState)::Nothing
    map(delete,a.shaders)
    map(delete,a.textargets)
    delete(a.framebuffer)
    delete(a.points)
    delete(a.lines)
    return nothing
end

export init!, clean!

######################
#  Resize & Compile  #
######################

function resize!(a::AppState, width, height)::Nothing
    texdata = ( color = (GL_RGBA8             ,GL_COLOR_ATTACHMENT0),
                index = (GL_R32I              ,GL_COLOR_ATTACHMENT1),
                depth = (GL_DEPTH_COMPONENT32F,GL_DEPTH_ATTACHMENT ))
    glViewport(0,0,width,height)
    map(delete, a.textargets)
    use(a.framebuffer) # TODO: probably not needed
    a.textargets = map(texdata) do (internalFormat,target)
        attach(a.framebuffer,Texture2D(internalFormat,width,height),target)
    end
    complete(a.framebuffer)
    return nothing
end

function recompile!(a::AppState) :: Nothing
    sources = ( points = ("shaders/pointVs.glsl","shaders/pointFs.glsl"),
                lines  = ("shaders/lineVs.glsl" ,"shaders/lineFs.glsl"),   
                post   = ("shaders/postVs.glsl" ,"shaders/postFs.glsl")   )
    map(GL.delete, a.shaders)
    a.shaders = map(stages->Shader(stages...),sources)
    return nothing
end

######################
#       Render       #
######################

function render!(a::AppState)::Nothing
    update!(a.camera)
    t = ticks()
    ldir = normalize(a.camera.view * Vec4f(cos(t),1,sin(t),0) )

    use(a.framebuffer)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glClearBufferiv(GL_COLOR,1,GLuint[0 0 0 0])
    glEnable(GL_DEPTH_TEST)

    use(a.shaders.lines)
    setUniform("VP",viewProj(a.camera))
    setUniform("lightDir",ldir[1:3])
    setUniform("resolution",a.camera.resolution)
    use(a.lines)
    glDrawArrays(GL_LINE_STRIP,0,length(a.lines))

    use(a.shaders.points)
    setUniform("VP",viewProj(a.camera))
    setUniform("lightDir",ldir[1:3])
    use(a.points)
    glDrawArrays(GL_POINTS,0,length(a.points))

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glClear(GL_COLOR_BUFFER_BIT)
    glDisable(GL_DEPTH_TEST)
    use(a.shaders.post)
    setTexture("frame",a.textargets.color,0)
    setTexture("idTex",a.textargets.index,1)
    setUniform("index",GLint(0))
    setUniform("time",0f0)
    glDrawArrays(GL_TRIANGLES,0,3)

    return nothing
end

export render!

######################
#       Events       #
######################

# function event!(a::AppState, ev::MouseMotionEvent)
#     event!(a.camera,ev)
# end

function event!(a::AppState, ev::KeyboardDownEvent)
    Cameras.event!(a.camera,ev)
    if ev.glfw_key == GLFW_KEY_F5
        recompile!(a)
    end
end

function event!(a::AppState,  ev::ResizeEvent)
    Cameras.event!(a.camera,ev)
    resize!(a,ev.width,ev.height)
end

event!(a::AppState,ev::Event) = Cameras.event!(a.camera,ev) # general impl calls camera event

export event!

end # module