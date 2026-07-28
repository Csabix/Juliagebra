
# ? ---------------------------------
# ! Line
# ? ---------------------------------

const _INFINITE_LINE_DISTANCE = 1024

_get_dependent_line(dep::DependentDNA) = dep
_get_dependent_line(dep) = SourceValueHolder(Vec3D(dep))

function Line(first,second,distance=_INFINITE_LINE_DISTANCE,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=5.0f0)

    deps = DependentDNA[
        _get_dependent_line(first),
        _get_dependent_line(second),
    ]

    n = ceil(Int16, log2(distance))

    ParametricCurve(range(-n,n,2*n+1),deps,color_style;color=color,style=style,size=size) do t, a, b
        dir = normalize(b - a)
        d = sign(t) * 2^abs(t)
        return a + dir * d
    end

    return ValueHolder(PLine,deps) do a, b
        return PLine(a, normalize(b - a))
    end
end

function Line(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],distance=_INFINITE_LINE_DISTANCE,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=5.0f0)

    n = ceil(Int16, log2(distance))

    ParametricCurve(range(-n,n,2*n+1),dependents,color_style;color=color,style=style,size=size) do t,intersection
        pline = callback(intersection)
        d = sign(t) * 2^abs(t)
        return pline.p + pline.v * d
    end
end

# ? ---------------------------------
# ! Line to PLine intersection
# ? ---------------------------------

struct PLineOfLine <: PrimitivesOf{PLine}
    line::PLine
end
PrimitivesOf(self::PLine) = PLineOfLine(self)

Base.length(self::PLineOfLine) = 1
Base.iterate(self::PLineOfLine, index::Integer = 1) = index == 1 ? (self.line, (index + 1)) : nothing

export Line
