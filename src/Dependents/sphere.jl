
# ? ---------------------------------
# ! SphereDependent
# ? ---------------------------------

mutable struct SphereDependent <: RenderedDependentDNA
    _dependent::RenderedDependent
    _center::Vec3D
    _radius::Float64
    _color::Vec3F
    _transparent::Bool
    _index::UInt

    # YELLOW Thread
    function SphereDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        color::Vec3F,transparent::Bool
        )

        dependent = RenderedDependent(callback,dependents)
        center  = Vec3DNan
        radius = 0.0

        return new(dependent,center,radius,color,transparent,0)
    end
end



_RenderedDependent_(self::SphereDependent)::RenderedDependent = return self._dependent

# YELLOW Thread
# RED Thread
onNodeEval(self::SphereDependent) = evalCallbackDp(self)

function evalCallbackDpReturn(self::SphereDependent,cr::Tuple{Vec3D,Float64})
    self._center = cr[1]
    self._radius = cr[2]
end

function evalCallbackDpReturn(self::SphereDependent,s::PSphere)
    self._center = s.c
    self._radius = s.r
end

evalCallbackDpReturn(self::SphereDependent,::Nothing) = return nothing

# ? For Intersectable Spheres.

const SPHERE_DETAIL = 15

struct PTrianglesOfSphere <: PrimitivesOf{PTriangle}
    _sphere::SphereDependent
end
PrimitivesOf(self::SphereDependent) = return PTrianglesOfSphere(self)

function spherePos(u,v,r,center)
    alfa = Float64(u-1) / Float64(SPHERE_DETAIL-1)
    beta = Float64(v-1) / Float64(SPHERE_DETAIL-1)

    alfa = alfa * (pi - 0.0) + 0.0
    beta = beta * (2*pi - 0.0) + 0.0

    x = center.x + (r + 0.1) * sin(alfa) * cos(beta)
    y = center.y + (r + 0.1) * sin(alfa) * sin(beta)
    z = center.z + (r + 0.1) * cos(alfa)

    return Vec3F(x,y,z)
end

function Base.length(::PTrianglesOfSphere) 
    return (SPHERE_DETAIL-1)*(SPHERE_DETAIL-1) + (SPHERE_DETAIL-1)*(SPHERE_DETAIL-1)
end

function Base.getindex(self::PTrianglesOfSphere, index::UInt)::PTriangle 
    center = self._sphere._center
    r = self._sphere._radius
    
    index = index - 1    
    a = div(index,(SPHERE_DETAIL-1)*(SPHERE_DETAIL-1))

    if (a == 0)
        u = div(index,SPHERE_DETAIL-1) + 1
        v = mod(index,SPHERE_DETAIL-1) + 1
        return PTriangle(spherePos(u,v,r,center),spherePos(u+1,v,r,center),spherePos(u+1,v+1,r,center))
    elseif (a == 1)
        index = index - (SPHERE_DETAIL-1)*(SPHERE_DETAIL-1)
        u = div(index,SPHERE_DETAIL-1) + 1
        v = mod(index,SPHERE_DETAIL-1) + 1
        return PTriangle(spherePos(u,v,r,center),spherePos(u,v+1,r,center),spherePos(u+1,v+1,r,center))
    else
        error("$(index) is invalid state!")
    end
end

function Base.iterate(self::PTrianglesOfSphere, state = UInt(1))
    if state > length(self)
        return nothing
    else
        return (self[state],state+1)
    end
end

export PTrianglesOfSphere

# ? ---------------------------------
# ! SphereRenderer
# ? ---------------------------------

mutable struct SphereRenderer <: RendererDNA{SphereDependent}   
    _renderer::Renderer{SphereDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _shader_transparent::ShaderProgram

    _buffer_opaque::BufferArray
    _buffer_transparent::BufferArray

    _centers_opaque::Vector{Vec3F}
    _radiuses_opaque::Vector{Float32}
    _colors_opaque::Vector{Vec3F}

    _centers_transparent::Vector{Vec3F}
    _radiuses_transparent::Vector{Float32}
    _colors_transparent::Vector{Vec3F}
    
    # GREEN Thread
    function SphereRenderer(context::OpenGLData)
        renderer = Renderer{SphereDependent}(context)

        shader_id = ShaderProgram(["sphere/sphere_id.vert","sphere/sphere_id.geom","sphere/sphere_id.frag"],["VP","cam","at","ASPECT_FOV_RESOLUTION"])
        shader_opaque = ShaderProgram(["sphere/sphere.vert","sphere/sphere.geom","sphere/sphere_opaque.frag"],["VP","cam","at","lightDirCam","lightDirSide","ASPECT_FOV_RESOLUTION"])
        shader_transparent = ShaderProgram(["sphere/sphere.vert","sphere/sphere.geom","sphere/sphere_transparent.frag"],["VP","cam","at","lightDirCam","lightDirSide","ASPECT_FOV_RESOLUTION"])

        buffer_opaque = BufferArray{Tuple{Vec3F,Float32,Vec3F}}(MappedBuffer,MappedBuffer,Buffer)
        buffer_transparent = BufferArray{Tuple{Vec3F,Float32,Vec3F}}(MappedBuffer,MappedBuffer,Buffer)

        new(renderer,
            shader_id,shader_opaque,shader_transparent,
            buffer_opaque,buffer_transparent,
            Vector{Vec3F}(),Vector{Float32}(),Vector{Vec3F}(),
            Vector{Vec3F}(),Vector{Float32}(),Vector{Vec3F}())
    end
end

_Renderer_(self::SphereRenderer)::Renderer = return self._renderer

# GREEN Thread
function added!(self::SphereRenderer,sphere::SphereDependent)
    centers  = sphere._transparent ? self._centers_transparent  : self._centers_opaque
    radiuses = sphere._transparent ? self._radiuses_transparent : self._radiuses_opaque
    colors   = sphere._transparent ? self._colors_transparent   : self._colors_opaque
    
    push!(centers, Vec3F(sphere._center))
    push!(radiuses,Float32(sphere._radius))
    push!(colors,  Vec3F(sphere._color))

    sphere._index = length(centers)
end

# GREEN Thread
function addedAll!(self::SphereRenderer)
    upload!(self._buffer_opaque,1,self._centers_opaque ,0)
    upload!(self._buffer_opaque,2,self._radiuses_opaque,0)
    upload!(self._buffer_opaque,3,self._colors_opaque  ,0)

    upload!(self._buffer_transparent,1,self._centers_transparent ,0)
    upload!(self._buffer_transparent,2,self._radiuses_transparent,0)
    upload!(self._buffer_transparent,3,self._colors_transparent  ,0)
end

# GREEN Thread
function sync!(self::SphereRenderer,sphere::SphereDependent)
    centers  = sphere._transparent ? self._centers_transparent  : self._centers_opaque
    radiuses = sphere._transparent ? self._radiuses_transparent : self._radiuses_opaque
    centers[sphere._index] = sphere._center
    radiuses[sphere._index] = sphere._radius
end

# GREEN Thread
function syncAll!(self::SphereRenderer)
    @time_cpu_begin Dependent Sphere
    wait(self._buffer_opaque[1])
    copyto!(self._buffer_opaque[1],self._centers_opaque)
    wait(self._buffer_opaque[2])
    copyto!(self._buffer_opaque[2],self._radiuses_opaque)

    wait(self._buffer_transparent[1])
    copyto!(self._buffer_transparent[1],self._centers_transparent)
    wait(self._buffer_transparent[1])
    copyto!(self._buffer_transparent[2],self._radiuses_transparent)

    @time_cpu_end Dependent Sphere
end

function id_pass!(self::SphereRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)

    activate(self._shader_id)
    uniform(self._shader_id,"VP",vp)
    uniform(self._shader_id,"cam",cam._eye)
    uniform(self._shader_id,"at",cam._at)
    uniform(self._shader_id,"ASPECT_FOV_RESOLUTION",
        Vec4F(Float32(shrd._width)/Float32(shrd._height),deg2rad(cam._fov),Float32(shrd._width),Float32(shrd._height)))
    @time_gpu_begin Dependent Sphere ID_PASS
    if !isempty(self._centers_opaque) draw(self._buffer_opaque,GL_POINTS) end
    #if !isempty(self._centers_transparent) draw(self._buffer_transparent,GL_POINTS) end
    @time_gpu_end Dependent Sphere ID_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function opaque_pass!(self::SphereRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if isempty(self._centers_opaque) return nothing end
    (cam_light, side_light) = get_lights(cam)

    glDisable(GL_CULL_FACE)
    
    activate(self._shader_opaque)
    uniform(self._shader_opaque,"lightDirCam",-cam_light)
    uniform(self._shader_opaque,"lightDirSide",-side_light)
    uniform(self._shader_opaque,"VP",vp)
    uniform(self._shader_opaque,"cam",cam._eye)
    uniform(self._shader_opaque,"at",cam._at)
    uniform(self._shader_opaque,"ASPECT_FOV_RESOLUTION",
        Vec4F(Float32(shrd._width)/Float32(shrd._height),deg2rad(cam._fov),Float32(shrd._width),Float32(shrd._height)))
    @time_gpu_begin Dependent Sphere OPAQUE_PASS
    draw(self._buffer_opaque,GL_POINTS)
    @time_gpu_end Dependent Sphere OPAQUE_PASS
    lock(self._buffer_opaque[1])
    lock(self._buffer_opaque[2])

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent_pass!(self::SphereRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if isempty(self._centers_transparent) return nothing end
    (cam_light, side_light) = get_lights(cam)

    glDisable(GL_CULL_FACE)
    
    activate(self._shader_transparent)
    uniform(self._shader_transparent,"lightDirCam",-cam_light)
    uniform(self._shader_transparent,"lightDirSide",-side_light)
    uniform(self._shader_transparent,"VP",vp)
    uniform(self._shader_transparent,"cam",cam._eye)
    uniform(self._shader_transparent,"at",cam._at)
    uniform(self._shader_transparent,"ASPECT_FOV_RESOLUTION",
        Vec4F(Float32(shrd._width)/Float32(shrd._height),deg2rad(cam._fov),Float32(shrd._width),Float32(shrd._height)))
    @time_gpu_begin Dependent Sphere TRANSPARENT_PASS
    draw(self._buffer_transparent,GL_POINTS)
    @time_gpu_end Dependent Sphere TRANSPARENT_PASS
    lock(self._buffer_transparent[1])
    lock(self._buffer_transparent[2])

    glEnable(GL_CULL_FACE)
    return nothing
end

function destroy!(self::SphereRenderer)
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._shader_transparent)
    destroy!(self._buffer_opaque)
    destroy!(self._buffer_transparent)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::SphereDependent)::SphereRenderer = getOpenGL(app)._renderers[1]

# ? ---------------------------------
# ! Sphere
# ? ---------------------------------

# YELLOW Thread
function Sphere(center::PointDependent,p1::PointDependent; color = (0.980,0.467,0.306), transparent = false)::SphereDependent
    deps = Vector{DependentDNA}([center,p1])
    call = function (center,p1)
        radius = norm(center - p1) 
        return (center,radius)
    end

    return Build!(SphereDependent(call,deps,Vec3F(color),transparent)) 
end

# YELLOW Thread
function Sphere(center::PointDependent,radius::ValueHolderDNA{Float64}; color = (0.031,0.337,0.412), transparent = false)
    deps = Vector{DependentDNA}([center,radius])
    call = function (center,radius)
        return (center,radius)
    end

    return Build!(SphereDependent(call,deps,Vec3F(color),transparent)) 
end

# YELLOW Thread
function Sphere(p1::PointDependent,p2::PointDependent,p3::PointDependent,p4::PointDependent; color = (0.697,0.230,0.958), transparent = false)
    deps = [p1,p2,p3,p4]
    call = function (p1,p2,p3,p4)
        s::PSphere = FourPointOnPSphere(p1,p2,p3,p4)
        return s
    end

   return Build!(SphereDependent(call,deps,Vec3F(color),transparent)) 
end

export Sphere
