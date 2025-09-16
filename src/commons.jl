function sp(shaderFileName::String)::String
    path = (@__FILE__)
    path = path[1:(length(path) - length("commons.jl"))]
    path = path * "Shaders/$(shaderFileName)"
    return path
end

Vec3FNan = Vec3F(NaN32,NaN32,NaN32)
Vec4FNan = Vec4F(NaN32,NaN32,NaN32,NaN32)
