using Juliagebra

App()

directory = @__DIR__

FILE = directory * "\\scenes\\scene_1.fbx"

println(FILE)

scene = load_scene(FILE;scale_factor=1.0f0)

for (index, mesh) in enumerate(scene)
    @show mesh
    if mod(index,2) == 0
        TriangleCluster(scene[index];color=(1,1,0))
    else
        TriangleCluster(scene[index];color=(0,1,1),transparent=true)
    end
end

play!()