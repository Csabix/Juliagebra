
# ? ---------------------------------
# ! Line
# ? ---------------------------------

const _INFINITE_LINE_DISTANCE = 1024

function _get_dependent_line(dep::DependentDNA)
    return dep
end
function _get_dependent_line(dep)
    # ? eg. when Vec3D is the input
    SourceValueHolder(Vec3D(dep))
end

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

# ? ---------------------------------
# ! Line to PLine intersection
# ? ---------------------------------

struct PLineOfLine <: PrimitivesOf{PSegment} # TODO: change to PLine
    line::PLine
end
function PrimitivesOf(self::PLine)
    # println("p of")
    return PLineOfLine(self)
end

Base.length(self::PLineOfLine) = 1

function Base.getindex(self::PLineOfLine, index::Integer)::Union{Nothing, PLine}
    # println("index: ", index)
    if (index == 1)
        # println(self.line)
        return self.line
    else
        return nothing
    end
end

function Base.iterate(self::PLineOfLine, index::Integer = 1)
    # println("iterate: ", index)
    if (index == 1)
        return (self[index], (index + 1))
    else
        return nothing
    end
end

export Line
