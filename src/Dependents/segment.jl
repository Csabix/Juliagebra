
# ? ---------------------------------
# ! Segment
# ? ---------------------------------

_get_parent_segment(parent::NodeHandle) = parent
_get_parent_segment(parent) = add_node!(Vec3D(parent))

function Segment(first,second,color_style::Union{Nothing,String}=nothing;
                 color="c",style="-",size=5.0f0)
    deps = NodeHandle[
        _get_parent_segment(first),
        _get_parent_segment(second)
    ]
    return ParametricCurve(range(0,1,length=2),deps,color_style;color=color,style=style,size=size) do t, a, b
        return b .* t .+ (1-t) .* a
    end
end

export Segment