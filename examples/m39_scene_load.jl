using Juliagebra

function z_rot(degrees)
    c, s = cos(degrees), sin(degrees)
    R = [ c  -s   0.0  0.0;
          s   c   0.0  0.0;
         0.0 0.0  1.0  0.0;
         0.0 0.0  0.0  1.0]
    return R
end

function transform(v)
    R = [1.0 0.0  0.0  v[1];
         0.0 1.0  0.0  v[2];
         0.0 0.0  1.0  v[3];
         0.0 0.0  0.0  1.0 ]
    return R
end

App()

directory = @__DIR__

FILE = directory * "\\scenes\\scene_1.fbx"

println(FILE)

scene = load_scene(FILE;scale_factor=1.0f0)

slider = Slider(0,2*pi)
for (index, mesh) in enumerate(scene)
    @show mesh
    if mod(index,2) == 0
        tc = TriangleCluster(scene[index],[slider];color=(1,1,0)) do s
            return z_rot(s + 2*pi*index/length(scene)) * transform((5,0,0)) * z_rot(s)
        end
        PointCloud([tc]) do tc
            return get_positions(tc)
        end
    else
        TriangleCluster(scene[index],[slider];color=(0,1,1),transparent=true) do s
            return z_rot(s + 2*pi*index/length(scene)) * transform((5,0,0)) * z_rot(s)
        end
    end
end

play!()