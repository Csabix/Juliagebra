
# ? ---------------------------------
# ! Triangle
# ? ---------------------------------

function _triangle_surface_func(u::Float64,v::Float64,a::Vec3D,b::Vec3D,c::Vec3D)
    if (u>=0.5 && v>=0.5)
        u = 0.5
        v = 0.5
    end

    return Vec3D((1-u-v) .* a .+ u .* b .+ v .* c)
end

_get_dependent_triangle(dep::DependentDNA) = dep
_get_dependent_triangle(dep) = SourceValueHolder(Vec3D(dep))

function Triangle(a,b,c,color_data::Union{Nothing,String}=nothing;color=nothing)
    deps = DependentDNA[
        _get_dependent_triangle(a),
        _get_dependent_triangle(b),
        _get_dependent_triangle(c)
    ]
    return ParametricSurface(_triangle_surface_func,range(0,1,3),range(0,1,3),deps,color_data;color=color)
end

export Triangle