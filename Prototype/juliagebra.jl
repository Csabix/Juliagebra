#All files are imported here to prevent circle includes.

module JuliAgebra

include("helpers/Macros/source/macros.jl")

include("helpers/Gl/source/gl.jl")
using .Gl

include("helpers/Glm/source/glm.jl")
using .Glm

include("helpers/Events/source/events.jl")
using .Events

include("source/shared_data.jl")

include("source/algebra_logic.jl")

include("source/window_manager.jl")

end