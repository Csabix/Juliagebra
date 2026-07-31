
# ? ---------------------------------
# ! Line
# ? ---------------------------------

const LINE_N_LENGTH = ceil(Int16, log(4, 1000))

_get_dependent_line(dep::DependentDNA) = dep
_get_dependent_line(dep) = SourceValueHolder(Vec3D(dep))

function Line(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    deps = DependentDNA[
        _get_dependent_line(p0),
        _get_dependent_line(p1),
    ]

    ParametricCurve(range(-LINE_N_LENGTH,LINE_N_LENGTH,2*LINE_N_LENGTH+1),deps,color_style;color=color,style=style,size=size) do t,p0,p1
        dir = normalize(p1 - p0)
        d = sign(t) * 4^abs(t)
        return p0 + dir * d
    end

    return ValueHolder(PLine,deps) do p0,p1
        return PLine(p0, normalize(p1 - p0))
    end
end

function Line(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    ParametricCurve(range(-LINE_N_LENGTH,LINE_N_LENGTH,2*LINE_N_LENGTH+1),dependents,color_style;color=color,style=style,size=size) do t,param
        pline = callback(param)
        if (pline === nothing) return nothing end
        
        d = sign(t) * 4^abs(t)
        return pline.p + normalize(pline.v) * d
    end

    return ValueHolder(PLine, dependents) do param
        pline = callback(param)
        if (pline === nothing) return PLine(Vec3DNan,Vec3DNan) end
        return pline
    end
end

function Line(line,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    
    return Line([line],color_style;color=color,style=style,size=size) do l
        return PLine(p(l),v(l))
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
