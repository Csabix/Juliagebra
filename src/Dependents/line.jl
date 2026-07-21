
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

export Line
