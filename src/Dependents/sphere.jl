# ? ---------------------------------
# ! SpherePlan
# ? ---------------------------------


mutable struct SpherePlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _center::Vec3D
    _radius::Float64
end

function SpherePlan(callback::Function,plans::Vector{T},x,y,z,r) where {T<:PlanDNA}
    plan = RenderedPlan(callback,plans)
    center = Vec3D(x,y,z)
    radius = Float64(r)
    

    return SpherePlan(plan,center,radius)
end

_RenderedPlan_(self::SpherePlan)::RenderedPlan = return self._plan

# ? ---------------------------------
# ! SphereDependent
# ? ---------------------------------

mutable struct SphereDependent <: RenderedDependentDNA
    _dependent::RenderedDependent
    _center::Vec3D
    _radius::Float64
end

function SphereDependent(plan::SpherePlan)
    dependent = RenderedDependent(plan)
    center  = plan._center
    radius = plan._radius

    return SphereDependent(dependent,center,radius)
end

_RenderedDependent_(self::SphereDependent)::RenderedDependent = return self._dependent

Plan2Dependent(plan::SpherePlan)::SphereDependent = return SphereDependent(plan)

onGraphEval(self::SphereDependent) = return nothing

# ? ---------------------------------
# ! SphereRenderer
# ? ---------------------------------

mutable struct SphereRenderer <: RendererDNA{SphereDependent}   
    _renderer::Renderer{SphereDependent}
    _shader::ShaderProgram

    _buffer::TypedBufferArray

    _centers::Vector{Vec3F}
    _radiuses::Vector{Float32}
end

function SphereRenderer(context::OpenGLData)
    renderer = Renderer{SphereDependent}(context)

    shader = ShaderProgram(sp("sphere.vert"),sp("sphere.geom"),sp("sphere.frag"),["VP","cam"])

    buffer = TypedBufferArray{Tuple{Vec3F,Float32}}()

    centers = Vector{Vec3F}()
    radiuses = Vector{Float32}()

    return SphereRenderer(
        renderer,
        shader,
        buffer,
        centers,
        radiuses)
end

_Renderer_(self::SphereRenderer)::Renderer = return self._renderer

setRenderedID!(self::SphereRenderer,_,_) = return nothing

function added!(self::SphereRenderer,sphere::SphereDependent)
    push!(self._centers,Vec3F(sphere._center))
    push!(self._radiuses,Float32(sphere._radius))
    @log "Added Sphere as: $(sphere._center) ~ $(sphere._radius)" INFO
end

function addedAll!(self::SphereRenderer)
    upload!(self._buffer,1,self._centers,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._radiuses,GL_DYNAMIC_DRAW)
    @log "AddedAll Spheres!" INFO
end

function sync!(self::SphereRenderer,sphere::SphereDependent)
    
end

function syncAll!(self::SphereRenderer)

end

function draw!(self::SphereRenderer,vp,selectedID,pickedID,cam,shrd)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"cam",cam._eye)
    draw(self._buffer,GL_POINTS)

    glEnable(GL_CULL_FACE)
end

function destroy!(self::SphereRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

Plan2Observer(builder::OpenGLData, _::SpherePlan) = SingleRendererTactic(builder,SphereRenderer)

