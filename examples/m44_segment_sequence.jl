using Juliagebra
using JuliaGLM

Juliagebra.Window() do 
    styles = [
        SOLID,
        DASHED,
        DOTTED,
        WAVE,
        DASH_DOT,
        ARROW,
        ARROW_REVERSED
    ]

    s = Slider(2,20)

    for i in 1:50
        ss = SegmentSequence([s],i;
        style=styles[mod1(i,length(styles))],width=10.0,color=[(1.0,0.0,0.0),(0.0,1.0,0.0)]) do s
            return [Vec3F(j,i,0) for j in 1:s]
        end
    end
end


