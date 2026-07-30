
# ? ---------------------------------
# ! Line
# ? ---------------------------------

const _INFINITE_LINE_DISTANCE = 1024

_get_dependent_line(dep::DependentDNA) = dep
_get_dependent_line(dep) = SourceValueHolder(Vec3D(dep))

function Line(p0,p1,color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_LINE_DISTANCE,color="g",style="-",size=3.0f0)

    deps = DependentDNA[
        _get_dependent_line(p0),
        _get_dependent_line(p1),
    ]

    n = ceil(Int16, log2(distance))

    ParametricCurve(range(-n,n,2*n+1),deps,color_style;color=color,style=style,size=size) do t,p0,p1
        dir = normalize(p1 - p0)
        d = sign(t) * 2^abs(t)
        return p0 + dir * d
    end

    return ValueHolder(PLine,deps) do p0,p1
        return PLine(p0, normalize(p1 - p0))
    end
end

function Line(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_LINE_DISTANCE,color="g",style="-",size=3.0f0)

    n = ceil(Int16, log2(distance))

    ParametricCurve(range(-n,n,2*n+1),dependents,color_style;color=color,style=style,size=size) do t,param
        pline = callback(param)
        if (pline === nothing) return nothing end
        
        d = sign(t) * 2^abs(t)
        return pline.p + normalize(pline.v) * d
    end
end

function Line(line,color_style::Union{Nothing,String}=nothing;
    distance=_INFINITE_LINE_DISTANCE,color="g",style="-",size=3.0f0)
    
    Line([line],color_style;distance=distance,color=color,style=style,size=size) do l
        return PLine(p(l),v(l)) # TODO: fix
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
