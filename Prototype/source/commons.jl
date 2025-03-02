function sp(shaderFileName::String)::String
    path = (@__FILE__)
    path = path[1:(length(path) - length("commons.jl"))]
    path = path * "Shaders/$(shaderFileName)"
    return path
end