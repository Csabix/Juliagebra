
# ? ---------------------------------
# ! Ray
# ? ---------------------------------

_get_dependent_ray(dep::DependentDNA) = dep
_get_dependent_ray(dep) = SourceValueHolder(Vec3D(dep))

function Ray(point,at,color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_LINE_DISTANCE,color="g",style="-",size=3.0f0)

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

    pray = ValueHolder(PRay,deps) do p1,p2
        return PRay(p1, normalize(p2 - p1))
    end
    
    Segment([pray],color_style;color=color,style="->",size=size*3) do ray
        return PSegment(p(ray), p(ray) + v(ray))
    end

    return pray
end

function Ray(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_LINE_DISTANCE,color="g",style="-",size=3.0f0)
        n = ceil(Int16, log2(distance))

    ParametricCurve(range(0,n,n+1),dependents,color_style;color=color,style=style,size=size) do t,param
        pray = callback(param)
        if (pray === nothing) return nothing end

        d = t == 0.0 ? t : 2^t
        return pray.p + pray.v * d
    end
end

function Ray(line,color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_LINE_DISTANCE,color="g",style="-",size=3.0f0)
    
    Ray([line],color_style;distance=distance,color=color,style=style,size=size) do l
        return PRay(p(l),v(l))
    end
end

# ? ---------------------------------
# ! Ray to PRay intersection
# ? ---------------------------------

struct PRayOfRay <: PrimitivesOf{PRay}
    ray::PRay
end
PrimitivesOf(self::PRay) = PRayOfRay(self)

Base.length(self::PRayOfRay) = 1
Base.iterate(self::PRayOfRay, index::Integer = 1) = index == 1 ? (self.ray, (index + 1)) : nothing

export Ray
