include("parsers.jl")
#include("Gui/gui_renderer.jl")
#include("Gui/gui_dependent.jl")
include("point.jl")
include("curve.jl")
include("surface.jl")
include("Gui/toggle.jl")
include("Gui/slider.jl")
include("Gui/textbox.jl")
include("Gui/stepper.jl")
include("sphere.jl")
include("lazy_lbvh.jl")
include("intersections.jl")
include("segment.jl")
include("triangle.jl")
include("tetrahedra.jl")
include("segment_sequence.jl")
include("triangle_cluster.jl")
include("line.jl")
include("ray.jl")
include("plane.jl")
include("circle.jl")
include("scalar.jl")

_deps_collect_add!(vec::Vector{Vec3D},v) = push!(vec,v)
_deps_collect_add!(vec::Vector{Vec3D},v::Vector) = append!(vec,v)
#function _deps_collect_add!(vec::Vector{Vec3D},v::IntersectionCalculator)
#    for i in 1:v._foundIntersectionNum
#        push!(vec,v[i])
#    end
#end
function _deps_collect_add!(vec::Vector{Vec3D},segseq::SegmentSequence)
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