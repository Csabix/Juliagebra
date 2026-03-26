using Juliagebra
using JuliaGLM

Juliagebra.Window() do 
    types = [
        SOLID,
        DASHED,
        DOTTED,
        WAVE,
        DASH_DOT,
        ARROW
    ]

    s = Slider(2,20)

    for i in 1:50
        ss = SegmentSequence([s],i;
        type=types[mod1(i,length(types))],width=10.0,color=[(1,0,0),(0,1,0)]) do s
            return [Vec3F(j,i,0) for j in 1:s]
        end
    end
end


