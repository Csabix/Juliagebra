const _POINTS::UInt = 1
const _POINT_SETS::UInt = 2
const _POINT_SEQUENCES::UInt = 3
const _CURVES::UInt = 4
const _SEGMENT_SEQUENCES::UInt = 5
const _SPHERES::UInt = 6
const _SURFACES::UInt = 7
const _TRIANGLE_CLUSTERS::UInt = 8

include("parsers.jl")
include("dependent_renderer.jl")
include("rendered_dependent.jl")
include("parametric_dependent.jl")
include("Gui/gui_renderer.jl")
include("Gui/gui_dependent.jl")
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
        Spheres(data),
        ParametricSurfaceRenderer(data),
        TriangleClusters(data)
    ]
end

function destroy_dependent_observers(observers::Vector{RendererDNA})::Nothing
    foreach(destroy!,observers)
    return nothing
end

function reset_dependent_observers(data::OpenGLData, observers::Vector{RendererDNA})::Nothing
    destroy_dependent_observers(observers)
    empty!(observers)
    push!(observers,Points(data))
    push!(observers,PointSets(data))
    push!(observers,PointSequences(data))
    push!(observers,Curves(data))
    push!(observers,SegmentSequences(data))
    push!(observers,Spheres(data))
    push!(observers,ParametricSurfaceRenderer(data))
    push!(observers,TriangleClusters(data))
    return nothing
end