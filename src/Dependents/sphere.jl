
# ? ---------------------------------
# ! SphereDependent
# ? ---------------------------------

mutable struct SphereDependent <: RenderedDependentDNA
    _dependent::RenderedDependent
    _center::Vec3D
    _radius::Float64
    _color::UInt8

    # YELLOW Thread
    function SphereDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        color::UInt8)
        dependent = RenderedDependent(callback,dependents)
        center = Vec3DNan
        radius = 0.0
        return new(dependent,center,radius,color)
    end
end



_RenderedDependent_(self::SphereDependent)::RenderedDependent = return self._dependent

# YELLOW Thread
# RED Thread
onNodeEval(self::SphereDependent) = evalCallbackDp(self)

Base.eltype(dependent::SphereDependent)::DataType = Tuple{Vec3D, Float64}

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
# ! Spheres
# ? ---------------------------------

mutable struct Spheres <: RendererDNA{SphereDependent}   
    _renderer::Renderer{SphereDependent}
    _renderers::PrimitiveRenderers
    _indexes::Vector{UInt32}

    # GREEN Thread
    function Spheres(context::OpenGLData)
        renderer = Renderer{SphereDependent}(context)
        indexes = Vector{UInt32}()
        new(renderer, context._renderers, indexes)
    end
end

_Renderer_(self::Spheres)::Renderer = return self._renderer

# GREEN Thread
function added!(self::Spheres,sphere::SphereDependent)
    aID = UInt32(getGraphID(sphere) + ID_LOWER_BOUND)
    push!(self._indexes, add!(self._renderers.sphere,Vec3F(sphere._center),Float32(sphere._radius),sphere._color,aID))
end

# GREEN Thread
function sync!(self::Spheres,sphere::SphereDependent)
    index = self._indexes[getObserverID(sphere)]
    update_coord_radius!(self._renderers.sphere,index,Vec3F(sphere._center),Float32(sphere._radius),sphere._color[4])
end

function destroy!(self::Spheres) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::SphereDependent)::Spheres = getDependentObservers(app)[_SPHERES]

# ? ---------------------------------
# ! Sphere
# ? ---------------------------------

_get_dependent_sphere(dep::DependentDNA) = dep, eltype(dep) <: Number
_get_dependent_sphere(dep) = isa(dep,Number) ? (SourceValueHolder(Float64(dep)), true) : (SourceValueHolder(Vec3D(dep)), false)

# YELLOW Thread
function Sphere(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_data::Union{Nothing,String}=nothing;
                color="b")::SphereDependent
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return build!(SphereDependent(callback,dependents,c))
end

function Sphere(center,radius_or_p1,color_data::Union{Nothing,String}=nothing;
    color="b")::SphereDependent
    call_p = function (center,p1)
        radius = norm(center - p1)
        return (center,radius)
    end
    call_r = function (center,radius)
        return (center,radius)
    end
    (c,_) = _get_dependent_sphere(center)
    (p_or_r,scalar) = _get_dependent_sphere(radius_or_p1)

    deps = DependentDNA[
        c,
        p_or_r
    ]
    return Sphere(scalar ? call_r : call_p,deps,color_data;color=color)
end

function Sphere(p1,p2,p3,p4,color_data::Union{Nothing,String}=nothing;
    color="b")::SphereDependent
    call = function (p1,p2,p3,p4)
        s::PSphere = FourPointOnPSphere(p1,p2,p3,p4)
        return s
    end
    deps = DependentDNA[
        get_dependent_sphere(p1)[1],
        get_dependent_sphere(p2)[1],
        get_dependent_sphere(p3)[1],
        get_dependent_sphere(p4)[1]
    ]
    return Sphere(call,deps,color_data;color=color)
end

macro Sphere(callback::Expr,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_data,),(:color,), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Sphere,
                                positional_args,kw_args)
end

export Sphere
export @Sphere