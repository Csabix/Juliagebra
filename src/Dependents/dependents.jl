include("dependent_renderer.jl")
include("rendered_dependent.jl")
include("gui_renderer.jl")
include("gui_dependent.jl")
include("point.jl")
include("curve.jl")
#include("Dependents/surface.jl")
include("toggle.jl")
include("slider.jl")
include("textbox.jl")
#include("Dependents/sphere.jl")
include("lazy_lbvh.jl")
include("intersections.jl")
include("segment.jl")
#include("Dependents/triangle.jl")
#include("Dependents/tetrahedra.jl")
include("segment_sequence.jl")

_deps_collect_add!(vec::Vector{Vec3D},v) = push!(vec,v)
_deps_collect_add!(vec::Vector{Vec3D},v::Vector) = append!(vec,v)
function _deps_collect_add!(vec::Vector{Vec3D},v::IntersectionCalculatorDependent)
    for i in 1:v._foundIntersectionNum
        push!(vec,v[i])
    end
end
function _deps_collect_add!(vec::Vector{Vec3D},segseq::SegmentSequenceDependent)
    for v in segseq._values
        push!(vec,v)
    end
end
function _deps_collect(deps...)
    result = Vector{Vec3D}()
    for dep in deps
        _deps_collect_add!(result,dep)
    end
    return result
end

include("point_set.jl")
include("point_sequence.jl")