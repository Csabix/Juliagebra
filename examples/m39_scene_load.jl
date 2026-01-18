using Juliagebra

App()

directory = @__DIR__

FILE = directory * "\\scenes\\scene_1.fbx"

println(FILE)

scene = load_scene(FILE;scale_factor=1.0f0)
for mesh in scene
    #@show mesh
    TriangleCluster(mesh)
end

play!()