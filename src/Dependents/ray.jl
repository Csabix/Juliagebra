
# ? ---------------------------------
# ! Ray
# ? ---------------------------------

_get_dependent_ray(dep::DependentDNA) = dep
_get_dependent_ray(dep) = SourceValueHolder(Vec3D(dep))

function Ray(point,at,distance=_INFINITE_LINE_DISTANCE,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    deps = DependentDNA[
        _get_dependent_ray(point),
        _get_dependent_ray(at),
    ]

    n = ceil(Int16, log2(distance))

    ParametricCurve(range(0,n,n+1),deps,color_style;color=color,style=style,size=size) do t,p1,p2
        dir = normalize(p2 - p1)
        d = t == 0.0 ? t : 2^t
        return p1 + dir * d
    end

    return ValueHolder(PRay,deps) do p1,p2
        return PRay(p1, normalize(p2 - p1))
    end
end


export Ray
