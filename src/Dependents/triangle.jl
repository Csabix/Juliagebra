_triangle_surface_func(a::Vec3D,b::Vec3D,c::Vec3D) = [a,c,b]
_get_parent_triangle(parent::NodeHandle) = parent
_get_parent_triangle(parent) = add_node!(Vec3D(parent))

function Triangle(a,b,c,color_data::Union{Nothing,String}=nothing;color="g")
    parents = NodeHandle[
        _get_parent_triangle(a),
        _get_parent_triangle(b),
        _get_parent_triangle(c)
    ]
    return TriangleCluster(_triangle_surface_func,parents,color_data;color=color)
end

export Triangle