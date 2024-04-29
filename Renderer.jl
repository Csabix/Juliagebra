module Renderer

using ImGuiOpenGLBackend.ModernGL, ImGuiGLFWBackend.LibGLFW, GeometryBasics, LinearAlgebra
# include("glutils.jl")
# using .GlUtils
include("gl.jl")
using .GL
include("Cameras.jl")
using .Cameras

export init, render

struct Vertex
    pos  :: Vec3f     # position of points or whatever
    size :: Float32   # size of point or line with
    col  :: Vec4{UInt8}     # color to apply
    #    acc ::Float32   # length accumulator for striping
    Vertex(pos,size=5f0,col=Vec4{Int8}(1,1,1,1)) = new(convert(Vec3f,pos),convert(Float32,size),convert(Vec4{UInt8},col));
end
const Float = Union{Float32,Float64}
translate(v::Vertex,pos::Vec3f)::Vertex = Vertex(v.pos+pos,v.size,v.col)
translate(v::Vertex,x::Float,y::Float,z::Float)::Vertex = translate(v,Vec3f(x,y,z))

mutable struct SyncedArray{T}
    val :: Vector{T}
    vbo :: Buffer
    vao :: VertexArray
    function SyncedArray{T}() where T
        sa = new{T}(Vector{T}(),Buffer(),VertexArray())
        bind(sa.vao); bind(sa.vbo)
        vertexAttribs(T)
        return sa
    end
end
upload!(sa::SyncedArray{T}) where T = GL.upload!(sa.vbo,sa.val)

@kwdef mutable struct Scene
    points :: SyncedArray{Vertex} = SyncedArray{Vertex}()
    lines  :: SyncedArray{Vertex} = SyncedArray{Vertex}()
end

@kwdef mutable struct Objects
    vertexProgram :: Program = Program()
    postprocProgram :: Program = Program()
    frameBuffer :: Framebuffer = Framebuffer()
    colorTexture :: Texture2D = Texture2D(GL_RGBA8             )
    indexTexture :: Texture2D = Texture2D(GL_R32I              )
    depthTexture :: Texture2D = Texture2D(GL_DEPTH_COMPONENT32F) 
end

@kwdef mutable struct State
    dragIndex :: GLint = 0 # none
    selectIndex :: GLint = 0
    mPrev :: Vec2f = Vec2f(0)
end


global scene  :: Scene
global objects :: Objects
global camera :: Camera
global state :: State


timeZero :: Float64 = time()
ticks()::Float32 = Float32(timeZero-time())

getCamera()::Camera = camera

function resize(width, height)
    global objects
    glViewport(0,0,width,height)
    for (tex,target) in [
            (objects.colorTexture, GL_COLOR_ATTACHMENT0)
            (objects.indexTexture, GL_COLOR_ATTACHMENT1)
            (objects.depthTexture, GL_DEPTH_ATTACHMENT)]
        delete(tex)
        tex = Texture2D(tex.internalFormat,width,height)
        attach(objects.frameBuffer,tex,target)
    end
    attach(objects.frameBuffer, objects.depthTexture, GL_DEPTH_ATTACHMENT)
    complete(objects.frameBuffer)
end

function recompile()
    global objects
    delete(objects.vertexProgram)
    objects.vertexProgram = Program("shaders/pointVs.glsl","shaders/pointFs.glsl")
    delete(objects.postprocProgram)
    objects.postprocProgram = Program("shaders/postVs.glsl","shaders/postFs.glsl")
end

function init()
    glClearColor(0.45, 0.55, 0.60, 1.00)
    glEnable(GL_PROGRAM_POINT_SIZE) # glPointSize(10)

    global scene = Scene()
    global camera = Camera()
    global objects = Objects()
    global state = State()

    recompile()
    resize(640,480)

    scene.points.val = vec([Vertex([x y z],10,[100x+120,100y+120,100z+120,255] .|> trunc .|> UInt8) for x=-1:0.2:1,y=-1:0.2:1,z=-1:0.2:1])
    upload!(scene.points)

end

function render()
    global scene, objects, camera, state
    update!(camera)
    
    # Pass 1: geometry -> framebuffer

    bind(objects.frameBuffer)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glClearBufferiv(GL_COLOR,1,GLuint[0 0 0 0])
    glEnable(GL_DEPTH_TEST)

    t = ticks()
    ldir = Vec4f(cos(t),1,sin(t),0)
    ldir = normalize((camera.view)*ldir)

    bind(objects.vertexProgram)
    setUniform("VP",viewProj(camera))
    setUniform("lightDir",ldir[1:3])
    bind(scene.points.vao)
    glDrawArrays(GL_POINTS, 0, GLsizei(length(scene.points.val)))

    # Pass 2: framebuffer -> backbuffer

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glClear(GL_COLOR_BUFFER_BIT)
    glDisable(GL_DEPTH_TEST)

    bind(objects.postprocProgram)
    setTexture("frame",objects.colorTexture,0)
    setTexture("idTex",objects.indexTexture,1)
    setUniform("index",GLint(state.selectIndex-1))
    setUniform("time",t)
    glDrawArrays(GL_TRIANGLES,0,3)

end

function keyDown(key::Cint,mods::Cint)::Nothing
    if key == GLFW_KEY_F5
        recompile()
        #printstyled("Shader recompilation success! :)\n";color=:green,bold:true)
    else
        vert :: Vertex = scene.points.val[state.selectIndex];
        if key == GLFW_KEY_J
            vert = translate(vert,-0.1,0.0,0.0)
        elseif key == GLFW_KEY_L
            vert = translate(vert,+0.1,0.0,0.0)
        elseif key == GLFW_KEY_I
            vert = translate(vert,0.0,0.0,+0.1)
        elseif key == GLFW_KEY_K
            vert = translate(vert,0.0,0.0,-0.1)
        elseif key == GLFW_KEY_U
            vert = translate(vert,0.0,+0.1,0.0)
        elseif key == GLFW_KEY_O
            vert = translate(vert,0.0,-0.1,0.0)
        end
        scene.points.val[state.selectIndex] = vert;
        upload!(scene.points)
    end
    return nothing
end

function mouseMove(window::Ptr{GLFWwindow}, xpos::Cdouble, ypos::Cdouble)::Nothing
    mCurr = Vec2f(xpos,ypos)
    if state.dragIndex == 0
    end
    Cameras.mouseMove(camera,xpos,ypos)
    state.mPrev = mCurr
    return nothing
end

function mouseButton(window::Ptr{GLFWwindow}, key::Int32,action::Cint, mods::Int32)::Nothing
    if key == GLFW_MOUSE_BUTTON_LEFT
        if action == GLFW_PRESS
            w = GLint(camera.resolution[1]); h = GLint(camera.resolution[2])
            x = GLint(state.mPrev[1]); y = GLint(state.mPrev[2])
            #println("x=$x,y=$y,h=$h,w=$w")
            if 0 <= x< w && 0 <= y < h
                id = Int(getPixel1i(objects.indexTexture,x,GLint(h-y-1))) + 1
                if state.dragIndex == 0
                    state.selectIndex = id
                end
                state.dragIndex = id
            end
        else
            state.dragIndex = 0
        end
    end
    if state.dragIndex == 0
    end
    Cameras.mouseButton(camera,key,action,mods)
    return nothing
end

end