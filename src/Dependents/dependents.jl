include("dependent_renderer.jl")
include("rendered_dependent.jl")
include("gui_renderer.jl")
include("gui_dependent.jl")
include("point.jl")
#include("Dependents/curve.jl")
#include("Dependents/surface.jl")
include("toggle.jl")
include("slider.jl")
include("textbox.jl")
#include("Dependents/sphere.jl")
include("lazy_lbvh.jl")
include("intersections.jl")
#include("Dependents/segment.jl")
#include("Dependents/triangle.jl")
#include("Dependents/tetrahedra.jl")
#include("Dependents/segment_sequence.jl") # after curve include!

_deps_collect_add!(vec::Vector{Vec3D},v) = push!(vec,v)
_deps_collect_add!(vec::Vector{Vec3D},v::Vector) = append!(vec,v)
function _deps_collect_add!(vec::Vector{Vec3D},intersectons::IntersectionCalculatorDependent)
    i = 1
    while true
        v = intersectons[i]
        if isnothing(v) return end
        push!(vec,v)
        i += 1
    end
end
function _deps_collect(deps...)
    result = Vector{Vec3D}()
    for dep in deps
        _deps_collect_add!(result,dep)
    end
    return result
end

include("point_cloud_static.jl")
include("point_cloud_dynamic.jl")