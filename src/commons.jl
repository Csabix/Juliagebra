const Vec3FNan::Vec3T{Float32} = Vec3F(NaN32,NaN32,NaN32)
const Vec4FNan::Vec4T{Float32} = Vec4F(NaN32,NaN32,NaN32,NaN32)

const Vec3DNan::Vec3T{Float64} = Vec3D(NaN64,NaN64,NaN64)
const Vec4DNan::Vec4T{Float64} = Vec4D(NaN64,NaN64,NaN64,NaN64)

JuliaGLM.Vec3F(x,y) = JuliaGLM.Vec3F(x,y,zero(Float32))
JuliaGLM.Vec3D(x,y) = JuliaGLM.Vec3F(x,y,zero(Float64))