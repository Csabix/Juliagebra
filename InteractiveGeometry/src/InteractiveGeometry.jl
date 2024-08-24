module InteractiveGeometry

using Glm

include("Geometry.jl")
include("Drawing.jl")
include("prettyprint.jl")

const MPoint = Movable{Point};
const DPoint = Dependent{Point};

# mpoint(v::AbstractArray; options...) = Movable{Point}(Point(v;options...))
# dpoint(callback, inputs...; options...) = Dependent{Point}(Point(;options...), callback, [inputs...])

end # module InteractiveGeometry
