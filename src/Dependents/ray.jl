
# ? ---------------------------------
# ! Ray
# ? ---------------------------------

_get_dependent_ray(dep::DependentDNA) = dep
_get_dependent_ray(dep) = SourceValueHolder(Vec3D(dep))

function Ray(point,at,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    deps = DependentDNA[
        _get_dependent_ray(point),
        _get_dependent_ray(at),
    ]

    ParametricCurve(range(0,LINE_N_LENGTH,LINE_N_LENGTH+1),deps,color_style;color=color,style=style,size=size) do t,p1,p2
        dir = normalize(p2 - p1)
        d = t == 0.0 ? t : 4^t
        return p1 + dir * d
    end

    pray = ValueHolder(PRay,deps) do p1,p2
        return PRay(p1, p2)
    end
    
    Segment([pray],color_style;color=color,style="->",size=size*3) do ray
        return PSegment(p(ray), p1(ray))
    end

    return pray
end

function Ray(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    ParametricCurve(range(0,LINE_N_LENGTH,LINE_N_LENGTH+1),dependents,color_style;color=color,style=style,size=size) do t,param
        pray = callback(param)
        if (pray === nothing) return nothing end

        d = t == 0.0 ? t : 4^t
        return pray.p0 + normalize(v(pray)) * d
    end

    return ValueHolder(PRay,dependents) do param
        pray = callback(param)
        if (pray === nothing) return PRay(Vec3DNan,Vec3DNan) end
        return pray
    end
end

function Ray(line,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    
    return Ray([line],color_style;color=color,style=style,size=size) do l
        return PRay(p(l),p1(l))
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
