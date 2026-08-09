
# ? ---------------------------------
# ! Segment
# ? ---------------------------------

_get_dependent_segment(dep::DependentDNA) = dep
_get_dependent_segment(dep) = SourceValueHolder(Vec3D(dep))

function Segment(first,second,color_style::Union{Nothing,String}=nothing;
                 color=nothing,style=nothing,size=nothing)
    deps = DependentDNA[
        _get_dependent_segment(first),
        _get_dependent_segment(second)
    ]
    return ParametricCurve(range(0,1,length=2),deps,color_style;color=color,style=style,size=size) do t, a, b
        return b .* t .+ (1-t) .* a
    end
end

export Segment