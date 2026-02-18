using Juliagebra
using JuliaGLM

App()

types = [
    CURVE_SOLID,
    CURVE_DASHED,
    CURVE_DOTTED,
    CURVE_WAVE,
    CURVE_DASH_DOT,
    CURVE_ARROW
]

for i in 1:50
    SegmentSequence(i,[PointCloud([Vec3F(j,i,0) for j in 1:50])];
    type=types[mod1(i,length(types))],width=10.0,color=[(1,0,0),(0,1,0)]) do points
        return points
    end
end

play!()