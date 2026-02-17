using Juliagebra
using JuliaGLM

App()

for i in 1:50
    SegmentSequence(i,[PointCloud([Vec3F(j,i,0) for j in 1:50])]) do points
        return points
    end
end

play!()