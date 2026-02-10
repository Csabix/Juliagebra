# ? ---------------------------------
# ! SpherePlan
# ? ---------------------------------


mutable struct SpherePlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _center::Vec3D
    _radius::Float64
    _color::Vec3F
    _transparent::Bool
end

function SpherePlan(callback::Function,plans::Vector{T},x,y,z,r,col,transparent) where {T<:PlanDNA}
    plan = RenderedPlan(callback,plans)
    center = Vec3D(x,y,z)
    radius = Float64(r)
    
    r = Float32(col[1])
    g = Float32(col[2])
    b = Float32(col[3])

    color = Vec3F(r,g,b)

    return SpherePlan(plan,center,radius,color,transparent)
end

_RenderedPlan_(self::SpherePlan)::RenderedPlan = return self._plan


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
end

function SphereDependent(plan::SpherePlan)
    dependent = RenderedDependent(plan)
    center  = plan._center
    radius = plan._radius
    color = plan._color
    transparent = plan._transparent

    return SphereDependent(dependent,center,radius,color,transparent,0)
end

_RenderedDependent_(self::SphereDependent)::RenderedDependent = return self._dependent

Plan2Dependent(plan::SpherePlan)::SphereDependent = return SphereDependent(plan)

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

    _buffer_opaque::TypedBufferArray
    _buffer_transparent::TypedBufferArray

    _centers_opaque::Vector{Vec3F}
    _radiuses_opaque::Vector{Float32}
    _colors_opaque::Vector{Vec3F}

    _centers_transparent::Vector{Vec3F}
    _radiuses_transparent::Vector{Float32}
    _colors_transparent::Vector{Vec3F}
end

function SphereRenderer(context::OpenGLData)
    renderer = Renderer{SphereDependent}(context)

    shader_id = ShaderProgram(sp("./sphere/sphere_id.vert"),sp("./sphere/sphere_id.geom"),sp("./sphere/sphere_id.frag"),["VP","cam","at","ASPECT_FOV_RESOLUTION"])
    shader_opaque = ShaderProgram(sp("./sphere/sphere.vert"),sp("./sphere/sphere.geom"),sp("./sphere/sphere_opaque.frag"),["VP","cam","at","lightDirCam","lightDirSide","ASPECT_FOV_RESOLUTION"])
    shader_transparent = ShaderProgram(sp("./sphere/sphere.vert"),sp("./sphere/sphere.geom"),sp("./sphere/sphere_transparent.frag"),["VP","cam","at","lightDirCam","lightDirSide","ASPECT_FOV_RESOLUTION"])

    buffer_opaque = TypedBufferArray{Tuple{Vec3F,Float32,Vec3F}}()
    buffer_transparent = TypedBufferArray{Tuple{Vec3F,Float32,Vec3F}}()

    return SphereRenderer(
        renderer,
        shader_id,shader_opaque,shader_transparent,
        buffer_opaque,buffer_transparent,
        Vector{Vec3F}(),Vector{Float32}(),Vector{Vec3F}(),
        Vector{Vec3F}(),Vector{Float32}(),Vector{Vec3F}())
end

_Renderer_(self::SphereRenderer)::Renderer = return self._renderer

setRenderedID!(self::SphereRenderer,_,_) = return nothing

function added!(self::SphereRenderer,sphere::SphereDependent)
    evalCallbackDp(sphere)

    centers  = sphere._transparent ? self._centers_transparent  : self._centers_opaque
    radiuses = sphere._transparent ? self._radiuses_transparent : self._radiuses_opaque
    colors   = sphere._transparent ? self._colors_transparent   : self._colors_opaque
    
    push!(centers, Vec3F(sphere._center))
    push!(radiuses,Float32(sphere._radius))
    push!(colors,  Vec3F(sphere._color))

    sphere._index = length(centers)

    @log "Added Sphere as: $(sphere._center) ~ $(sphere._radius)" INFO
end

function addedAll!(self::SphereRenderer)
    upload!(self._buffer_opaque,1,self._centers_opaque ,GL_DYNAMIC_DRAW)
    upload!(self._buffer_opaque,2,self._radiuses_opaque,GL_DYNAMIC_DRAW)
    upload!(self._buffer_opaque,3,self._colors_opaque  ,GL_STATIC_DRAW)

    upload!(self._buffer_transparent,1,self._centers_transparent ,GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,2,self._radiuses_transparent,GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,3,self._colors_transparent  ,GL_STATIC_DRAW)

    @log "AddedAll Spheres!" INFO
end

function sync!(self::SphereRenderer,sphere::SphereDependent)
    centers  = sphere._transparent ? self._centers_transparent  : self._centers_opaque
    radiuses = sphere._transparent ? self._radiuses_transparent : self._radiuses_opaque
    centers[sphere._index] = sphere._center
    radiuses[sphere._index] = sphere._radius
    @log "Synced Sphere[$(getObserverID(sphere))]!" INFO
end

function syncAll!(self::SphereRenderer)
    @time_cpu_begin Dependent Sphere

    upload!(self._buffer_opaque,1,self._centers_opaque,GL_DYNAMIC_DRAW)
    upload!(self._buffer_opaque,2,self._radiuses_opaque,GL_DYNAMIC_DRAW)

    upload!(self._buffer_transparent,1,self._centers_transparent,GL_DYNAMIC_DRAW)
    upload!(self._buffer_transparent,2,self._radiuses_transparent,GL_DYNAMIC_DRAW)

    @time_cpu_end Dependent Sphere
    @log "Synced all Spheres!" INFO
end

function id_pass!(self::SphereRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)

    activate(self._shader_id)
    setUniform!(self._shader_id,"VP",vp)
    setUniform!(self._shader_id,"cam",cam._eye)
    setUniform!(self._shader_id,"at",cam._at)
    setUniform!(self._shader_id,"ASPECT_FOV_RESOLUTION",
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
    setUniform!(self._shader_opaque,"lightDirCam",-cam_light)
    setUniform!(self._shader_opaque,"lightDirSide",-side_light)
    setUniform!(self._shader_opaque,"VP",vp)
    setUniform!(self._shader_opaque,"cam",cam._eye)
    setUniform!(self._shader_opaque,"at",cam._at)
    setUniform!(self._shader_opaque,"ASPECT_FOV_RESOLUTION",
        Vec4F(Float32(shrd._width)/Float32(shrd._height),deg2rad(cam._fov),Float32(shrd._width),Float32(shrd._height)))
    @time_gpu_begin Dependent Sphere OPAQUE_PASS
    draw(self._buffer_opaque,GL_POINTS)
    @time_gpu_end Dependent Sphere OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent_pass!(self::SphereRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if isempty(self._centers_transparent) return nothing end
    (cam_light, side_light) = get_lights(cam)

    glDisable(GL_CULL_FACE)
    
    activate(self._shader_transparent)
    setUniform!(self._shader_transparent,"lightDirCam",-cam_light)
    setUniform!(self._shader_transparent,"lightDirSide",-side_light)
    setUniform!(self._shader_transparent,"VP",vp)
    setUniform!(self._shader_transparent,"cam",cam._eye)
    setUniform!(self._shader_transparent,"at",cam._at)
    setUniform!(self._shader_transparent,"ASPECT_FOV_RESOLUTION",
        Vec4F(Float32(shrd._width)/Float32(shrd._height),deg2rad(cam._fov),Float32(shrd._width),Float32(shrd._height)))
    @time_gpu_begin Dependent Sphere TRANSPARENT_PASS
    draw(self._buffer_transparent,GL_POINTS)
    @time_gpu_end Dependent Sphere TRANSPARENT_PASS

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

Plan2Observer(builder::OpenGLData, _::SpherePlan) = SingleRendererTactic(builder,_SPEHERE_RENDERER,SphereRenderer)::SphereRenderer