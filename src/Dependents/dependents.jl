const _POINTS::UInt = 1
const _POINT_SETS::UInt = 2
const _POINT_SEQUENCES::UInt = 3
const _CURVES::UInt = 4
const _SEGMENT_SEQUENCES::UInt = 5
const _SPHERES::UInt = 6

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
include("sphere.jl")
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

function create_dependent_observers(data::OpenGLData)::Vector{RendererDNA}
    return RendererDNA[
        Points(data),
        PointSets(data),
        PointSequences(data),
        Curves(data),
        SegmentSequences(data),
        Spheres(data)
    ]
end

function destroy_dependent_observers(observers::Vector{RendererDNA})::Nothing
    foreach(destroy!,observers)
    return nothing
end

function reset_dependent_observers(data::OpenGLData, observers::Vector{RendererDNA})::Nothing
    destroy_dependent_observers(observers)
    empty!(observers)
    push!(Points(data))
    push!(PointSets(data))
    push!(PointSequences(data))
    push!(Curves(data))
    push!(SegmentSequences(data))
    push!(Spheres(data))
    return nothing
end