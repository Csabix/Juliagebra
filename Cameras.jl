module Cameras

using ImGuiGLFWBackend.LibGLFW, ModernGL, GeometryBasics, LinearAlgebra

export Camera,viewProj,setView!,setProj!,update!
export keyboardButton,mouseMove,mouseButton,resizeWindow

function lookat(eye::Vec3{T}, at::Vec3{T}, up::Vec3{T}) :: Mat4{T} where T <: Real
    f :: Vec3{T} = -normalize(at-eye) # Why -?
    s :: Vec3{T} = normalize(cross(f,up))
    u :: Vec3{T} = cross(s,f)
    M3 :: Mat3{T} = [s u f]'
    return [M3 -M3*eye; 0 0 0 1]
end
function perspective(fovy::T, aspect::T, zNear::T, zFar::T) :: Mat4{T} where T <: AbstractFloat
    a  ::T = tan(fovy/T(2))
    dz ::T = zFar-zNear
    return Mat4{T}(
        T(1)/(aspect*a), 0,        0,                      0,
        0,               T(1)/(a), 0,                      0,
        0,               0,        -(zFar+zNear)/dz,      -1,
        0,               0,        -(T(2)*zFar*zNear)/dz,  0
    )
end

mutable struct Camera
    eye:: Vec3f;    at :: Vec3f;    up :: Vec3f
    view :: Mat4f;  proj :: Mat4f

    goF :: Float32; goR :: Float32; goU :: Float32
    mPrev :: Vec2f; mDown :: Bool
    atUV :: Vec2f
    
    speed :: Float32; lastTime::Float64
    resolution :: Vec2f

    function Camera(eye::Vec3f=Vec3f(2), at::Vec3f=Vec3f(0), up::Vec3f=Vec3f(0,1,0);
                   fovy::Float32=pi/3f0, aspect::Float32=640f0/480f0, zNear::Float32=0.01f0, zFar::Float32=1000f0, speed=4.f0)
        cam = new(); cam.resolution = Vec2f(640,480)
        cam.speed, cam.lastTime = speed, time()
        cam.goF, cam.goR, cam.goU, cam.mDown = 0f0, 0f0, 0f0, false
        setView!(cam,eye,at,up)
        setProj!(cam,fovy,aspect,zNear,zFar)
        return cam
    end
end

viewProj(cam::Camera)::Mat4f = cam.proj * cam.view


function setView!(cam::Camera, eye::Vec3f, at::Vec3f=Vec3f(0,0,0), up::Vec3f=Vec3f(0,1,0))::Nothing
    cam.eye, cam.at, cam.up = eye, at, up
    w::Vec3f = at-eye
    cam.atUV = Vec2f(atan(w[3],w[1]),acos(w[2]/norm(w)))
    cam.view = lookat(eye,at,up)
    return nothing
end

function setProj!(cam::Camera, fovy::Float32, aspect::Float32, zNear::Float32=0.01f0, zFar::Float32=1000f0)::Nothing
    cam.proj = perspective(fovy,aspect,zNear,zFar)
    return nothing
end

function update!(s::Camera)::Nothing
    currTime = time()
    dTime = Float32(currTime-s.lastTime)
    s.lastTime = currTime
    w = Vec3f(cos(s.atUV[1])*sin(s.atUV[2]),
                             cos(s.atUV[2]),
              sin(s.atUV[1])*sin(s.atUV[2]))
    right  ::Vec3f = -normalize(cross(w,s.up)) # Why -??
    dPos   ::Vec3f = (s.goF*w + s.goR*right + s.goU*s.up)*s.speed*dTime
    s.eye  = s.eye + dPos
    s.at   = s.eye + w
    s.view = lookat(s.eye,s.at,s.up)
    return nothing
end

function keyboardButton(s::Camera, key::Int32,action::Cint, mods::Int32)::Nothing
    dir :: Float32 = action == GLFW_PRESS ? 1f0 : -1f0
    if key == GLFW_KEY_W || key == GLFW_KEY_UP
        s.goF += dir
    elseif key == GLFW_KEY_S || key == GLFW_KEY_DOWN
        s.goF -= dir
    elseif key == GLFW_KEY_D || key == GLFW_KEY_RIGHT
        s.goR += dir
    elseif key == GLFW_KEY_A || key == GLFW_KEY_LEFT
        s.goR -= dir
    elseif key == GLFW_KEY_E
        s.goU += dir
    elseif key == GLFW_KEY_Q
        s.goU -= dir
    elseif key == GLFW_KEY_LEFT_SHIFT || key == GLFW_KEY_RIGHT_SHIFT
        s.speed = s.speed/4f0^dir
    elseif key == GLFW_KEY_LEFT_CONTROL || key == GLFW_KEY_RIGHT_CONTROL
        s.speed = s.speed*4f0^dir
    end
    return nothing
end
function mouseMove(s::Camera, xpos::Cdouble, ypos::Cdouble)::Nothing
    mCurr = Vec2f(xpos,ypos)
    if s.mDown
        dUV :: Vec2f =  (mCurr-s.mPrev).*Vec2f(-0.002f0,0.001f0)*s.speed
        s.atUV = s.atUV + dUV
        s.atUV = [s.atUV[1] clamp(s.atUV[2],0.01f0,3.14f0)]
    end
    s.mPrev = mCurr
    return nothing
end
function mouseButton(s::Camera, key::Int32,action::Cint, mods::Int32)::Nothing
    if key == GLFW_MOUSE_BUTTON_LEFT
        s.mDown = action == GLFW_PRESS
    end
    return nothing
end

function resizeWindow(s::Camera, width::Cint, height::Cint)
    s.resolution = Vec2f(width,height)
    setProj!(s,pi/3f0,Float32(width)/Float32(height))
end

end