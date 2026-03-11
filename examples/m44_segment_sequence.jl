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

s = Slider(2,20)

for i in 1:50
    SegmentSequence([s],2;
    type=types[mod1(i,length(types))],width=10.0,color=[(1,0,0),(0,1,0)]) do s
        return [Vec3F(j,i,0) for j in 1:s]
    end
end

play!()