# ? ---------------------------------
# ! SpherePlan
# ? ---------------------------------


mutable struct SpherePlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _center::Vec3D
    _radius::Float64
    _color::Vec3F
end

function SpherePlan(callback::Function,plans::Vector{T},x,y,z,r,col) where {T<:PlanDNA}
    plan = RenderedPlan(callback,plans)
    center = Vec3D(x,y,z)
    radius = Float64(r)
    
    r = Float32(col[1])
    g = Float32(col[2])
    b = Float32(col[3])

    color = Vec3F(r,g,b)

    return SpherePlan(plan,center,radius,color)
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
end

function SphereDependent(plan::SpherePlan)
    dependent = RenderedDependent(plan)
    center  = plan._center
    radius = plan._radius
    color = plan._color

    return SphereDependent(dependent,center,radius,color)
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
    _shader::ShaderProgram

    _buffer::TypedBufferArray

    _centers::Vector{Vec3F}
    _radiuses::Vector{Float32}
    
    _colors::Vector{Vec3F}
end

function SphereRenderer(context::OpenGLData)
    renderer = Renderer{SphereDependent}(context)

    shader = ShaderProgram(sp("sphere.vert"),sp("sphere.geom"),sp("sphere.frag"),["VP","cam","lightDirCam","lightDirSide"])

    buffer = TypedBufferArray{Tuple{Vec3F,Float32,Vec3F}}()

    centers = Vector{Vec3F}()
    radiuses = Vector{Float32}()

    colors = Vector{Vec3F}()

    return SphereRenderer(
        renderer,
        shader,
        buffer,
        centers,
        radiuses,
        colors)
end

_Renderer_(self::SphereRenderer)::Renderer = return self._renderer

setRenderedID!(self::SphereRenderer,_,_) = return nothing

function added!(self::SphereRenderer,sphere::SphereDependent)
    
    evalCallbackDp(sphere)
    
    push!(self._centers,Vec3F(sphere._center))
    push!(self._radiuses,Float32(sphere._radius))

    push!(self._colors,Vec3F(sphere._color))

    @log "Added Sphere as: $(sphere._center) ~ $(sphere._radius)" INFO
end

function addedAll!(self::SphereRenderer)
    upload!(self._buffer,1,self._centers,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._radiuses,GL_DYNAMIC_DRAW)
    
    upload!(self._buffer,3,self._colors,GL_STATIC_DRAW)

    @log "AddedAll Spheres!" INFO
end

function sync!(self::SphereRenderer,sphere::SphereDependent)
    self._centers[getObserverID(sphere)] = sphere._center
    self._radiuses[getObserverID(sphere)] = sphere._radius    
    @log "Synced Sphere[$(getObserverID(sphere))]!" INFO
end

function syncAll!(self::SphereRenderer)
    @time_cpu_begin Dependent Sphere
    upload!(self._buffer,1,self._centers,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._radiuses,GL_DYNAMIC_DRAW)
    @time_cpu_end Dependent Sphere
    @log "Synced all Spheres!" INFO
end

function draw!(self::SphereRenderer,vp,selectedID,pickedID,cam,shrd)
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader)
    setUniform!(self._shader,"lightDirCam",-cam_light)
    setUniform!(self._shader,"lightDirSide",-side_light)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"cam",cam._eye)
    @time_gpu_begin Dependent Sphere
    draw(self._buffer,GL_POINTS)
    @time_gpu_end Dependent Sphere

    glEnable(GL_CULL_FACE)
end

function destroy!(self::SphereRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

Plan2Observer(builder::OpenGLData, _::SpherePlan) = SingleRendererTactic(builder,SphereRenderer)

