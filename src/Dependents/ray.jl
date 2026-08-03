
# ? ---------------------------------
# ! Ray constructors
# ? ---------------------------------

_get_parent_ray(parent::NodeHandle) = parent
_get_parent_ray(parent) = add_node!(Vec3D(parent))

function Ray(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback, Line(PRay(Vec3DNan,Vec3DNan),c,s,size), parents)
end

function Ray(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    parents = NodeHandle[
        _get_parent_ray(p0),
        _get_parent_ray(p1),
    ]

    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(Line(PRay(Vec3DNan,Vec3DNan),c,s,size), parents) do p0,p1
        return (p0,p1)
    end
end

export Ray
