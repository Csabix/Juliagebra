

struct SphereDrawData
    handle::UInt32
    color::UInt32
end

convert_callback_result(::PSphere, result::PSphere)              = result
convert_callback_result(::PSphere, result::Tuple{Vec3D,Float64}) = PSphere(result[1],result[2])
convert_callback_result(::PSphere, ::Nothing)                    = PSphere(Vec3DNan,NaN64)

function render_node(sphere::PSphere, data::SphereDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::SphereDrawData
    sphere_renderer::SphereRenderer = renderers[SphereRenderer]
    if data.handle == 0
        handle = add!(sphere_renderer, Vec3F(sphere.c), Float32(sphere.r), data.color, id)
        return SphereDrawData(handle, data.color)
    else
        update_coord_radius!(sphere_renderer, data.handle, Vec3F(sphere.c), Float32(sphere.r), data.color)
        return data
    end
end

# ? For Intersectable Spheres.
const SPHERE_DETAIL = 15

struct PTrianglesOfSphere <: PrimitivesOf{PTriangle}
    sphere::PSphere
end
PrimitivesOf(self::PSphere) = return PTrianglesOfSphere(self)

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
    center = p0(self.sphere)
    radius = r(self.sphere)
    
    index = index - 1    
    a = div(index,(SPHERE_DETAIL-1)*(SPHERE_DETAIL-1))

    if (a == 0)
        u = div(index,SPHERE_DETAIL-1) + 1
        v = mod(index,SPHERE_DETAIL-1) + 1
        return PTriangle(spherePos(u,v,radius,center),spherePos(u+1,v,radius,center),spherePos(u+1,v+1,radius,center))
    elseif (a == 1)
        index = index - (SPHERE_DETAIL-1)*(SPHERE_DETAIL-1)
        u = div(index,SPHERE_DETAIL-1) + 1
        v = mod(index,SPHERE_DETAIL-1) + 1
        return PTriangle(spherePos(u,v,radius,center),spherePos(u,v+1,radius,center),spherePos(u+1,v+1,radius,center))
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

_get_parent_sphere(parent::NodeHandle) = parent, isa(convert_callback_entry(get_element(parent)),Number)
_get_parent_sphere(parent) = isa(convert_callback_entry(parent),Number) ? (add_node!(Float64(parent)), true) : (add_node!(Vec3D(parent)), false)

# YELLOW Thread
function Sphere(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_data::Union{Nothing,String}=nothing;
                color="b")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return add_node!(callback, PSphere(Vec3DNan,NaN64); draw_data=SphereDrawData(UInt32(0), c), parents=parents)
end

function Sphere(center,radius_or_p1,color_data::Union{Nothing,String}=nothing;
    color="b")::NodeHandle
    call_p = function (center,p1)
        radius = norm(center - p1)
        return (center,radius)
    end
    call_r = function (center,radius)
        return (center,radius)
    end
    (c,_) = _get_parent_sphere(center)
    (p_or_r,scalar) = _get_parent_sphere(radius_or_p1)

    deps = NodeHandle[
        c,
        p_or_r
    ]
    return Sphere(scalar ? call_r : call_p,deps,color_data;color=color)
end

function Sphere(p1,p2,p3,p4,color_data::Union{Nothing,String}=nothing;
    color="b")::NodeHandle
    call = function (p1,p2,p3,p4)
        s::PSphere = four_points_on_PSphere(p1,p2,p3,p4)
        return s
    end
    deps = NodeHandle[
        _get_parent_sphere(p1)[1],
        _get_parent_sphere(p2)[1],
        _get_parent_sphere(p3)[1],
        _get_parent_sphere(p4)[1]
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